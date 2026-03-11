from fastapi import FastAPI, UploadFile, File, Form, HTTPException
import uvicorn
import cv2
import mediapipe as mp
import numpy as np
import tempfile
import shutil
import math
import os
from typing import Dict, Any, List, Tuple

app = FastAPI()
mp_pose = mp.solutions.pose


# =========================================================
# basic helpers
# =========================================================
def _angle_deg(v1: np.ndarray, v2: np.ndarray) -> float:
    denom = (np.linalg.norm(v1) * np.linalg.norm(v2)) + 1e-9
    cosv = float(np.dot(v1, v2) / denom)
    cosv = max(-1.0, min(1.0, cosv))
    return float(math.degrees(math.acos(cosv)))


def _clamp01(x: float) -> float:
    return max(0.0, min(1.0, x))


def _clamp(x: float, lo: float, hi: float) -> float:
    return max(lo, min(hi, x))


def _score_0_100(x: float) -> int:
    return int(round(_clamp(x, 0.0, 100.0)))


def _safe_stats(arr: List[float]) -> Dict[str, float]:
    if not arr:
        return {"min": 0.0, "max": 0.0, "mean": 0.0}
    a = np.array(arr, dtype=np.float32)
    return {
        "min": float(a.min()),
        "max": float(a.max()),
        "mean": float(a.mean()),
    }


def _ratio_score(imit: float, refv: float) -> float:
    if refv <= 1e-6:
        return 0.0
    return 100.0 * _clamp01(imit / refv)


def _inverse_ratio_score(imit: float, refv: float) -> float:
    """
    smaller is better
    """
    if imit <= 1e-6 and refv <= 1e-6:
        return 100.0
    if imit <= 1e-6:
        return 100.0
    if refv <= 1e-6:
        return max(0.0, 100.0 - imit * 100.0)
    return 100.0 * _clamp01(refv / imit)


def _series_duration(series: List[float]) -> int:
    if len(series) < 3:
        return 0
    arr = np.array(series, dtype=np.float32)
    mn = float(arr.min())
    mx = float(arr.max())
    if (mx - mn) < 1e-6:
        return len(arr)
    thr = mn + 0.25 * (mx - mn)
    idx = np.where(arr >= thr)[0]
    if len(idx) == 0:
        return 0
    return int(idx[-1] - idx[0] + 1)


def _timing_score_from_series(ref_series: List[float], imi_series: List[float], fallback_quality: float) -> float:
    rd = _series_duration(ref_series)
    idu = _series_duration(imi_series)
    if rd <= 0 or idu <= 0:
        return 60.0 + 40.0 * fallback_quality
    ratio = idu / max(1.0, float(rd))
    score = 100.0 - 60.0 * abs(math.log(max(ratio, 1e-6)))
    return _clamp(score, 0.0, 100.0)


def _smoothness_score_from_series(series: List[float], fallback_quality: float) -> float:
    if len(series) < 6:
        return 60.0 + 40.0 * fallback_quality
    arr = np.array(series, dtype=np.float32)
    d1 = np.diff(arr)
    d2 = np.diff(d1)
    jerk = float(np.mean(np.abs(d2))) if len(d2) > 0 else 0.0
    score = 100.0 - min(50.0, jerk * 300.0)
    score = 0.7 * score + 0.3 * (60.0 + 40.0 * fallback_quality)
    return _clamp(score, 0.0, 100.0)


def _quality_score(ref: Dict[str, Any], imi: Dict[str, Any]) -> float:
    q_vis = min(ref["meanVisibility"], imi["meanVisibility"])
    q_frames = min(ref["framesUsed"], imi["framesUsed"])
    return _clamp01(q_vis / 0.7) * _clamp01(q_frames / 40.0)


def _compensation_score(ref: Dict[str, Any], imi: Dict[str, Any], trunk_weight: float = 0.6, shrug_weight: float = 0.4) -> Tuple[float, float, float]:
    ref_trunk = ref["trunkLean"]["max"]
    imi_trunk = imi["trunkLean"]["max"]
    ref_shrug = ref["shrugRatio"]["mean"]
    imi_shrug = imi["shrugRatio"]["mean"]

    trunk_delta = max(0.0, imi_trunk - ref_trunk)
    shrug_delta = max(0.0, imi_shrug - ref_shrug)

    trunk_pen = min(60.0, trunk_delta * 4.0)
    shrug_pen = min(60.0, shrug_delta * 400.0)
    comp = max(0.0, 100.0 - (trunk_weight * trunk_pen + shrug_weight * shrug_pen))
    return comp, trunk_delta, shrug_delta


def _side_name(side: str) -> str:
    return "left" if side.upper() == "L" else "right"


def _opp_side_name(side: str) -> str:
    return "right" if side.upper() == "L" else "left"


def _affected_unaffected_side_names(affected_side: str) -> Tuple[str, str]:
    affected = _side_name(affected_side)
    unaffected = _opp_side_name(affected_side)
    return affected, unaffected


def _no_motion_response(
    *,
    affectedSide: str,
    reason: str,
    algo: str,
    ref: Dict[str, Any],
    imi: Dict[str, Any],
    features: Dict[str, Any],
    overall: int = 5,
    compensation: int = 20,
) -> Tuple[Dict[str, int], Dict[str, Any], Dict[str, Any]]:
    scores = {
        "overall": overall,
        "symmetry": 0,
        "timing": 0,
        "smoothness": 0,
        "compensation": compensation,
        "rom": 0,
    }

    feature_payload = {
        "affectedSide": affectedSide,
        "motionDetected": False,
        **features,
    }

    quality_json = {
        "analysisStatus": "done",
        "needsRetake": True,
        "reason": reason,
        "meanVisibility_ref": ref["meanVisibility"],
        "meanVisibility_imi": imi["meanVisibility"],
        "framesUsed_ref": ref["framesUsed"],
        "framesUsed_imi": imi["framesUsed"],
        "algo": algo,
    }
    return scores, feature_payload, quality_json


def _wrong_side_response(
    *,
    affectedSide: str,
    algo: str,
    ref: Dict[str, Any],
    imi: Dict[str, Any],
    features: Dict[str, Any],
) -> Tuple[Dict[str, int], Dict[str, Any], Dict[str, Any]]:
    return _no_motion_response(
        affectedSide=affectedSide,
        reason="wrong_side_performed",
        algo=algo,
        ref=ref,
        imi=imi,
        features={
            "wrongSidePerformed": True,
            **features,
        },
        overall=3,
        compensation=15,
    )


def _wrong_reference_side_response(
    *,
    affectedSide: str,
    algo: str,
    ref: Dict[str, Any],
    imi: Dict[str, Any],
    features: Dict[str, Any],
) -> Tuple[Dict[str, int], Dict[str, Any], Dict[str, Any]]:
    return _no_motion_response(
        affectedSide=affectedSide,
        reason="wrong_reference_side_performed",
        algo=algo,
        ref=ref,
        imi=imi,
        features={
            "wrongReferenceSidePerformed": True,
            **features,
        },
        overall=3,
        compensation=15,
    )


def _wrong_side_by_smaller_is_better(
    *,
    aff_value: float,
    unaff_value: float,
    aff_max_threshold: float,
    dominance_ratio: float = 0.85,
) -> bool:
    return aff_value > aff_max_threshold and unaff_value < aff_value * dominance_ratio


# =========================================================
# exercise registry
# =========================================================
EXERCISES = {
    0: {
        "name": "팔 앞으로 들기",
        "code": "shoulder_flexion",
        "label": "팔 앞으로 들기",
        "algo": "shoulder_flexion_v5",
    },
    1: {
        "name": "팔 옆으로 들기",
        "code": "shoulder_abduction",
        "label": "팔 옆으로 들기",
        "algo": "shoulder_abduction_v5",
    },
    2: {
        "name": "머리 만지기",
        "code": "hand_to_head",
        "label": "머리 만지기",
        "algo": "hand_to_head_v5",
    },
    3: {
        "name": "허리 뒤로 손 가져가기",
        "code": "hand_to_back",
        "label": "허리 뒤로 손 가져가기",
        "algo": "hand_to_back_v5",
    },
    4: {
        "name": "앞 물건 잡기",
        "code": "reach_forward",
        "label": "앞 물건 잡기",
        "algo": "reach_forward_v5",
    },
    5: {
        "name": "옆 물건 잡기",
        "code": "reach_side",
        "label": "옆 물건 잡기",
        "algo": "reach_side_v5",
    },
    6: {
        "name": "팔 굽히기",
        "code": "elbow_flexion",
        "label": "팔 굽히기",
        "algo": "elbow_flexion_v5",
    },
    7: {
        "name": "팔 펴기",
        "code": "elbow_extension",
        "label": "팔 펴기",
        "algo": "elbow_extension_v5",
    },
}


# =========================================================
# feature extraction
# =========================================================
def extract_pose_features(
    video_path: str,
    stride: int = 6,
    max_frames: int = 600,
) -> Dict[str, Any]:
    cap = cv2.VideoCapture(video_path)
    pose = mp_pose.Pose(
        static_image_mode=False,
        model_complexity=1,
        enable_segmentation=False,
        min_detection_confidence=0.5,
        min_tracking_confidence=0.5,
    )

    NOSE = 0
    L_SH, R_SH = 11, 12
    L_EL, R_EL = 13, 14
    L_WR, R_WR = 15, 16
    L_HIP, R_HIP = 23, 24

    vis_list: List[float] = []
    trunk_angles: List[float] = []
    shrug_ratios: List[float] = []

    left_shoulder_elev: List[float] = []
    right_shoulder_elev: List[float] = []

    left_elbow_flex: List[float] = []
    right_elbow_flex: List[float] = []

    left_wrist_to_head: List[float] = []
    right_wrist_to_head: List[float] = []

    left_wrist_to_hip: List[float] = []
    right_wrist_to_hip: List[float] = []

    left_reach_side: List[float] = []
    right_reach_side: List[float] = []

    left_reach_up: List[float] = []
    right_reach_up: List[float] = []

    left_reach_forward: List[float] = []
    right_reach_forward: List[float] = []

    left_back_reach: List[float] = []
    right_back_reach: List[float] = []

    frame_idx = 0
    used = 0

    while True:
        ret, frame = cap.read()
        if not ret:
            break

        frame_idx += 1
        if frame_idx % stride != 0:
            continue

        used += 1
        if used > max_frames:
            break

        rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        res = pose.process(rgb)
        if not res.pose_landmarks:
            continue

        lm = res.pose_landmarks.landmark

        vis = float(np.mean([
            lm[NOSE].visibility,
            lm[L_SH].visibility, lm[R_SH].visibility,
            lm[L_EL].visibility, lm[R_EL].visibility,
            lm[L_WR].visibility, lm[R_WR].visibility,
            lm[L_HIP].visibility, lm[R_HIP].visibility,
        ]))
        vis_list.append(vis)

        def p2(i: int) -> np.ndarray:
            return np.array([lm[i].x, lm[i].y], dtype=np.float32)

        def p3(i: int) -> np.ndarray:
            return np.array([lm[i].x, lm[i].y, lm[i].z], dtype=np.float32)

        nose2 = p2(NOSE)

        lsh2, rsh2 = p2(L_SH), p2(R_SH)
        lel2, rel2 = p2(L_EL), p2(R_EL)
        lwr2, rwr2 = p2(L_WR), p2(R_WR)
        lhip2, rhip2 = p2(L_HIP), p2(R_HIP)

        lsh3, rsh3 = p3(L_SH), p3(R_SH)
        lwr3, rwr3 = p3(L_WR), p3(R_WR)

        sh_mid2 = 0.5 * (lsh2 + rsh2)
        hip_mid2 = 0.5 * (lhip2 + rhip2)

        torso_len = float(np.linalg.norm(sh_mid2 - hip_mid2) + 1e-9)

        torso_vec = sh_mid2 - hip_mid2
        vertical = np.array([0.0, -1.0], dtype=np.float32)
        if np.linalg.norm(torso_vec) > 1e-6:
            trunk_angles.append(_angle_deg(torso_vec, vertical))

        shoulder_height = float((lsh2[1] + rsh2[1]) / 2.0)
        hip_height = float((lhip2[1] + rhip2[1]) / 2.0)
        shrug = float((hip_height - shoulder_height) / torso_len)
        shrug_ratios.append(shrug)

        l_upper = lel2 - lsh2
        l_trunk = lhip2 - lsh2
        r_upper = rel2 - rsh2
        r_trunk = rhip2 - rsh2

        if np.linalg.norm(l_upper) > 1e-6 and np.linalg.norm(l_trunk) > 1e-6:
            left_shoulder_elev.append(_angle_deg(l_upper, l_trunk))
        if np.linalg.norm(r_upper) > 1e-6 and np.linalg.norm(r_trunk) > 1e-6:
            right_shoulder_elev.append(_angle_deg(r_upper, r_trunk))

        lv1 = lsh2 - lel2
        lv2 = lwr2 - lel2
        rv1 = rsh2 - rel2
        rv2 = rwr2 - rel2

        if np.linalg.norm(lv1) > 1e-6 and np.linalg.norm(lv2) > 1e-6:
            left_elbow_flex.append(_angle_deg(lv1, lv2))
        if np.linalg.norm(rv1) > 1e-6 and np.linalg.norm(rv2) > 1e-6:
            right_elbow_flex.append(_angle_deg(rv1, rv2))

        left_wrist_to_head.append(float(np.linalg.norm(lwr2 - nose2) / torso_len))
        right_wrist_to_head.append(float(np.linalg.norm(rwr2 - nose2) / torso_len))

        left_wrist_to_hip.append(float(np.linalg.norm(lwr2 - lhip2) / torso_len))
        right_wrist_to_hip.append(float(np.linalg.norm(rwr2 - rhip2) / torso_len))

        left_reach_side.append(float(abs(lwr2[0] - lsh2[0]) / torso_len))
        right_reach_side.append(float(abs(rwr2[0] - rsh2[0]) / torso_len))

        left_reach_up.append(float(max(0.0, (lsh2[1] - lwr2[1]) / torso_len)))
        right_reach_up.append(float(max(0.0, (rsh2[1] - rwr2[1]) / torso_len)))

        left_reach_forward.append(float(max(0.0, (lsh3[2] - lwr3[2]) / torso_len)))
        right_reach_forward.append(float(max(0.0, (rsh3[2] - rwr3[2]) / torso_len)))

        left_back_reach.append(float(max(0.0, (lwr3[2] - lsh3[2]) / torso_len)))
        right_back_reach.append(float(max(0.0, (rwr3[2] - rsh3[2]) / torso_len)))

    cap.release()
    pose.close()

    return {
        "framesUsed": used,
        "meanVisibility": float(np.mean(vis_list)) if vis_list else 0.0,
        "trunkLean": _safe_stats(trunk_angles),
        "shrugRatio": _safe_stats(shrug_ratios),
        "leftShoulderElev": _safe_stats(left_shoulder_elev),
        "rightShoulderElev": _safe_stats(right_shoulder_elev),
        "leftElbowFlex": _safe_stats(left_elbow_flex),
        "rightElbowFlex": _safe_stats(right_elbow_flex),
        "leftWristToHead": _safe_stats(left_wrist_to_head),
        "rightWristToHead": _safe_stats(right_wrist_to_head),
        "leftWristToHip": _safe_stats(left_wrist_to_hip),
        "rightWristToHip": _safe_stats(right_wrist_to_hip),
        "leftReachSide": _safe_stats(left_reach_side),
        "rightReachSide": _safe_stats(right_reach_side),
        "leftReachUp": _safe_stats(left_reach_up),
        "rightReachUp": _safe_stats(right_reach_up),
        "leftReachForward": _safe_stats(left_reach_forward),
        "rightReachForward": _safe_stats(right_reach_forward),
        "leftBackReach": _safe_stats(left_back_reach),
        "rightBackReach": _safe_stats(right_back_reach),
        "_series": {
            "leftShoulderElev": left_shoulder_elev,
            "rightShoulderElev": right_shoulder_elev,
            "leftElbowFlex": left_elbow_flex,
            "rightElbowFlex": right_elbow_flex,
            "leftWristToHeadInv": [max(0.0, 2.0 - x) for x in left_wrist_to_head],
            "rightWristToHeadInv": [max(0.0, 2.0 - x) for x in right_wrist_to_head],
            "leftWristToHipInv": [max(0.0, 2.0 - x) for x in left_wrist_to_hip],
            "rightWristToHipInv": [max(0.0, 2.0 - x) for x in right_wrist_to_hip],
            "leftReachSide": left_reach_side,
            "rightReachSide": right_reach_side,
            "leftReachForward": left_reach_forward,
            "rightReachForward": right_reach_forward,
            "leftBackReach": left_back_reach,
            "rightBackReach": right_back_reach,
        },
    }


# =========================================================
# scoring functions
# =========================================================
def score_shoulder_flexion(
    ref: Dict[str, Any],
    imi: Dict[str, Any],
    affectedSide: str,
) -> Tuple[Dict[str, int], Dict[str, Any], Dict[str, Any]]:
    aff, unaff = _affected_unaffected_side_names(affectedSide)
    quality = _quality_score(ref, imi)

    ref_peak = ref[f"{unaff}ShoulderElev"]["max"]
    ref_aff_peak = ref[f"{aff}ShoulderElev"]["max"]
    imi_peak = imi[f"{aff}ShoulderElev"]["max"]
    imi_unaff_peak = imi[f"{unaff}ShoulderElev"]["max"]

    ref_motion_threshold = 25.0
    no_motion_threshold = 25.0
    required_gap_deg = 10.0

    # reference는 건측이 환측보다 분명히 더 커야 통과
    if (ref_peak < ref_motion_threshold) or (ref_peak <= ref_aff_peak + required_gap_deg):
        return _wrong_reference_side_response(
            affectedSide=affectedSide,
            algo="shoulder_flexion_v5",
            ref=ref,
            imi=imi,
            features={
                "ref_unaffShoulderElevMax": ref_peak,
                "ref_affShoulderElevMax": ref_aff_peak,
                "referenceMotionThresholdDeg": ref_motion_threshold,
                "referenceRequiredGapDeg": required_gap_deg,
            },
        )

    if imi_peak < no_motion_threshold:
        return _no_motion_response(
            affectedSide=affectedSide,
            reason="no_meaningful_shoulder_flexion_detected",
            algo="shoulder_flexion_v5",
            ref=ref,
            imi=imi,
            features={
                "ref_unaffShoulderElevMax": ref_peak,
                "imi_affShoulderElevMax": imi_peak,
                "imi_unaffShoulderElevMax": imi_unaff_peak,
                "motionThresholdDeg": no_motion_threshold,
            },
        )

    # imitation은 환측이 건측보다 분명히 더 커야 통과
    if imi_peak <= imi_unaff_peak + required_gap_deg:
        return _wrong_side_response(
            affectedSide=affectedSide,
            algo="shoulder_flexion_v5",
            ref=ref,
            imi=imi,
            features={
                "ref_unaffShoulderElevMax": ref_peak,
                "imi_affShoulderElevMax": imi_peak,
                "imi_unaffShoulderElevMax": imi_unaff_peak,
                "motionThresholdDeg": no_motion_threshold,
                "imitationRequiredGapDeg": required_gap_deg,
            },
        )

    rom = _ratio_score(imi_peak, ref_peak)
    symmetry = max(0.0, 100.0 - (abs(imi_peak - ref_peak) * 2.0))
    comp, trunk_delta, shrug_delta = _compensation_score(ref, imi, trunk_weight=0.6, shrug_weight=0.4)

    ref_series = ref["_series"][f"{unaff}ShoulderElev"]
    imi_series = imi["_series"][f"{aff}ShoulderElev"]
    timing = _timing_score_from_series(ref_series, imi_series, quality)
    smoothness = _smoothness_score_from_series(imi_series, quality)

    overall = (
        0.40 * rom +
        0.20 * symmetry +
        0.25 * comp +
        0.05 * timing +
        0.10 * smoothness
    )

    scores = {
        "overall": _score_0_100(overall),
        "symmetry": _score_0_100(symmetry),
        "timing": _score_0_100(timing),
        "smoothness": _score_0_100(smoothness),
        "compensation": _score_0_100(comp),
        "rom": _score_0_100(rom),
    }

    features = {
        "affectedSide": affectedSide,
        "motionDetected": True,
        "rom_aff": float(rom),
        "ref_unaffShoulderElevMax": ref_peak,
        "ref_affShoulderElevMax": ref_aff_peak,
        "imi_affShoulderElevMax": imi_peak,
        "imi_unaffShoulderElevMax": imi_unaff_peak,
        "reference_imitationDiffDeg": abs(imi_peak - ref_peak),
        "ref_trunkLeanMaxDeg": ref["trunkLean"]["max"],
        "imi_trunkLeanMaxDeg": imi["trunkLean"]["max"],
        "ref_shrugRatioMean": ref["shrugRatio"]["mean"],
        "imi_shrugRatioMean": imi["shrugRatio"]["mean"],
        "trunkDeltaDeg": trunk_delta,
        "shrugDelta": shrug_delta,
        "motionThresholdDeg": no_motion_threshold,
    }

    quality_json = {
        "analysisStatus": "done",
        "needsRetake": (quality < 0.35),
        "reason": None if quality >= 0.35 else "low_visibility_or_too_few_frames",
        "meanVisibility_ref": ref["meanVisibility"],
        "meanVisibility_imi": imi["meanVisibility"],
        "framesUsed_ref": ref["framesUsed"],
        "framesUsed_imi": imi["framesUsed"],
        "algo": "shoulder_flexion_v5",
    }

    return scores, features, quality_json


def score_shoulder_abduction(
    ref: Dict[str, Any],
    imi: Dict[str, Any],
    affectedSide: str,
) -> Tuple[Dict[str, int], Dict[str, Any], Dict[str, Any]]:
    aff, unaff = _affected_unaffected_side_names(affectedSide)
    quality = _quality_score(ref, imi)

    ref_peak = ref[f"{unaff}ShoulderElev"]["max"]
    ref_aff_peak = ref[f"{aff}ShoulderElev"]["max"]
    imi_peak = imi[f"{aff}ShoulderElev"]["max"]
    imi_unaff_peak = imi[f"{unaff}ShoulderElev"]["max"]

    ref_motion_threshold = 25.0
    no_motion_threshold = 25.0
    required_gap_deg = 10.0

    if (ref_peak < ref_motion_threshold) or (ref_peak <= ref_aff_peak + required_gap_deg):
        return _wrong_reference_side_response(
            affectedSide=affectedSide,
            algo="shoulder_abduction_v5",
            ref=ref,
            imi=imi,
            features={
                "ref_unaffShoulderElevMax": ref_peak,
                "ref_affShoulderElevMax": ref_aff_peak,
                "referenceMotionThresholdDeg": ref_motion_threshold,
                "referenceRequiredGapDeg": required_gap_deg,
            },
        )

    if imi_peak < no_motion_threshold:
        return _no_motion_response(
            affectedSide=affectedSide,
            reason="no_meaningful_shoulder_abduction_detected",
            algo="shoulder_abduction_v5",
            ref=ref,
            imi=imi,
            features={
                "ref_unaffShoulderElevMax": ref_peak,
                "imi_affShoulderElevMax": imi_peak,
                "imi_unaffShoulderElevMax": imi_unaff_peak,
                "motionThresholdDeg": no_motion_threshold,
            },
        )

    if imi_peak <= imi_unaff_peak + required_gap_deg:
        return _wrong_side_response(
            affectedSide=affectedSide,
            algo="shoulder_abduction_v5",
            ref=ref,
            imi=imi,
            features={
                "ref_unaffShoulderElevMax": ref_peak,
                "imi_affShoulderElevMax": imi_peak,
                "imi_unaffShoulderElevMax": imi_unaff_peak,
                "motionThresholdDeg": no_motion_threshold,
                "imitationRequiredGapDeg": required_gap_deg,
            },
        )

    rom = _ratio_score(imi_peak, ref_peak)
    symmetry = max(0.0, 100.0 - (abs(imi_peak - ref_peak) * 2.0))
    comp, trunk_delta, shrug_delta = _compensation_score(ref, imi, trunk_weight=0.55, shrug_weight=0.45)

    ref_series = ref["_series"][f"{unaff}ShoulderElev"]
    imi_series = imi["_series"][f"{aff}ShoulderElev"]
    timing = _timing_score_from_series(ref_series, imi_series, quality)
    smoothness = _smoothness_score_from_series(imi_series, quality)

    overall = (
        0.40 * rom +
        0.20 * symmetry +
        0.25 * comp +
        0.05 * timing +
        0.10 * smoothness
    )

    scores = {
        "overall": _score_0_100(overall),
        "symmetry": _score_0_100(symmetry),
        "timing": _score_0_100(timing),
        "smoothness": _score_0_100(smoothness),
        "compensation": _score_0_100(comp),
        "rom": _score_0_100(rom),
    }

    features = {
        "affectedSide": affectedSide,
        "motionDetected": True,
        "rom_aff": float(rom),
        "ref_unaffShoulderElevMax": ref_peak,
        "ref_affShoulderElevMax": ref_aff_peak,
        "imi_affShoulderElevMax": imi_peak,
        "imi_unaffShoulderElevMax": imi_unaff_peak,
        "reference_imitationDiffDeg": abs(imi_peak - ref_peak),
        "ref_trunkLeanMaxDeg": ref["trunkLean"]["max"],
        "imi_trunkLeanMaxDeg": imi["trunkLean"]["max"],
        "ref_shrugRatioMean": ref["shrugRatio"]["mean"],
        "imi_shrugRatioMean": imi["shrugRatio"]["mean"],
        "trunkDeltaDeg": trunk_delta,
        "shrugDelta": shrug_delta,
        "motionThresholdDeg": no_motion_threshold,
        "note": "abduction_v5_hard_gate",
    }

    quality_json = {
        "analysisStatus": "done",
        "needsRetake": (quality < 0.35),
        "reason": None if quality >= 0.35 else "low_visibility_or_too_few_frames",
        "meanVisibility_ref": ref["meanVisibility"],
        "meanVisibility_imi": imi["meanVisibility"],
        "framesUsed_ref": ref["framesUsed"],
        "framesUsed_imi": imi["framesUsed"],
        "algo": "shoulder_abduction_v5",
    }

    return scores, features, quality_json


def score_hand_to_head(
    ref: Dict[str, Any],
    imi: Dict[str, Any],
    affectedSide: str,
) -> Tuple[Dict[str, int], Dict[str, Any], Dict[str, Any]]:
    aff, unaff = _affected_unaffected_side_names(affectedSide)
    quality = _quality_score(ref, imi)

    ref_dist = ref[f"{unaff}WristToHead"]["min"]
    ref_aff_dist = ref[f"{aff}WristToHead"]["min"]
    imi_dist = imi[f"{aff}WristToHead"]["min"]
    imi_unaff_dist = imi[f"{unaff}WristToHead"]["min"]

    ref_elb = ref[f"{unaff}ElbowFlex"]["min"]
    imi_elb = imi[f"{aff}ElbowFlex"]["min"]

    ref_motion_threshold = 0.65
    no_motion_threshold = 0.65

    if _wrong_side_by_smaller_is_better(
        aff_value=ref_aff_dist,
        unaff_value=ref_dist,
        aff_max_threshold=ref_motion_threshold,
        dominance_ratio=0.85,
    ):
        return _wrong_reference_side_response(
            affectedSide=affectedSide,
            algo="hand_to_head_v5",
            ref=ref,
            imi=imi,
            features={
                "ref_unaffWristToHeadMin": ref_dist,
                "ref_affWristToHeadMin": ref_aff_dist,
                "referenceDistanceThreshold": ref_motion_threshold,
            },
        )

    if _wrong_side_by_smaller_is_better(
        aff_value=imi_dist,
        unaff_value=imi_unaff_dist,
        aff_max_threshold=no_motion_threshold,
        dominance_ratio=0.85,
    ):
        return _wrong_side_response(
            affectedSide=affectedSide,
            algo="hand_to_head_v5",
            ref=ref,
            imi=imi,
            features={
                "ref_unaffWristToHeadMin": ref_dist,
                "imi_affWristToHeadMin": imi_dist,
                "imi_unaffWristToHeadMin": imi_unaff_dist,
                "distanceThreshold": no_motion_threshold,
            },
        )

    if imi_dist > no_motion_threshold:
        return _no_motion_response(
            affectedSide=affectedSide,
            reason="no_meaningful_hand_to_head_detected",
            algo="hand_to_head_v5",
            ref=ref,
            imi=imi,
            features={
                "ref_unaffWristToHeadMin": ref_dist,
                "imi_affWristToHeadMin": imi_dist,
                "imi_unaffWristToHeadMin": imi_unaff_dist,
                "distanceThreshold": no_motion_threshold,
            },
        )

    close_score = _inverse_ratio_score(imi_dist, ref_dist)
    elbow_score = _inverse_ratio_score(imi_elb, ref_elb)
    rom = 0.65 * close_score + 0.35 * elbow_score

    symmetry = max(0.0, 100.0 - 60.0 * abs(imi_dist - ref_dist))
    comp, trunk_delta, shrug_delta = _compensation_score(ref, imi, trunk_weight=0.65, shrug_weight=0.35)

    ref_series = ref["_series"][f"{unaff}WristToHeadInv"]
    imi_series = imi["_series"][f"{aff}WristToHeadInv"]
    timing = _timing_score_from_series(ref_series, imi_series, quality)
    smoothness = _smoothness_score_from_series(imi_series, quality)

    overall = (
        0.50 * rom +
        0.15 * symmetry +
        0.20 * comp +
        0.05 * timing +
        0.10 * smoothness
    )

    scores = {
        "overall": _score_0_100(overall),
        "symmetry": _score_0_100(symmetry),
        "timing": _score_0_100(timing),
        "smoothness": _score_0_100(smoothness),
        "compensation": _score_0_100(comp),
        "rom": _score_0_100(rom),
    }

    features = {
        "affectedSide": affectedSide,
        "motionDetected": True,
        "ref_unaffWristToHeadMin": ref_dist,
        "ref_affWristToHeadMin": ref_aff_dist,
        "imi_affWristToHeadMin": imi_dist,
        "imi_unaffWristToHeadMin": imi_unaff_dist,
        "ref_unaffElbowFlexMinDeg": ref_elb,
        "imi_affElbowFlexMinDeg": imi_elb,
        "reference_imitationDiff": abs(imi_dist - ref_dist),
        "trunkDeltaDeg": trunk_delta,
        "shrugDelta": shrug_delta,
        "distanceThreshold": no_motion_threshold,
    }

    quality_json = {
        "analysisStatus": "done",
        "needsRetake": (quality < 0.35),
        "reason": None if quality >= 0.35 else "low_visibility_or_too_few_frames",
        "meanVisibility_ref": ref["meanVisibility"],
        "meanVisibility_imi": imi["meanVisibility"],
        "framesUsed_ref": ref["framesUsed"],
        "framesUsed_imi": imi["framesUsed"],
        "algo": "hand_to_head_v5",
    }

    return scores, features, quality_json


def score_hand_to_back(
    ref: Dict[str, Any],
    imi: Dict[str, Any],
    affectedSide: str,
) -> Tuple[Dict[str, int], Dict[str, Any], Dict[str, Any]]:
    aff, unaff = _affected_unaffected_side_names(affectedSide)
    quality = _quality_score(ref, imi)

    ref_hip = ref[f"{unaff}WristToHip"]["min"]
    ref_aff_hip = ref[f"{aff}WristToHip"]["min"]
    imi_hip = imi[f"{aff}WristToHip"]["min"]
    imi_unaff_hip = imi[f"{unaff}WristToHip"]["min"]

    ref_back = ref[f"{unaff}BackReach"]["max"]
    ref_aff_back = ref[f"{aff}BackReach"]["max"]
    imi_back = imi[f"{aff}BackReach"]["max"]
    imi_unaff_back = imi[f"{unaff}BackReach"]["max"]

    if ref_hip > 0.55 and ref_aff_back > max(0.03, ref_back * 1.2):
        return _wrong_reference_side_response(
            affectedSide=affectedSide,
            algo="hand_to_back_v5",
            ref=ref,
            imi=imi,
            features={
                "ref_unaffWristToHipMin": ref_hip,
                "ref_affWristToHipMin": ref_aff_hip,
                "ref_unaffBackReachMax": ref_back,
                "ref_affBackReachMax": ref_aff_back,
            },
        )

    if imi_hip > 0.55 and imi_back < 0.03:
        if imi_unaff_hip < imi_hip * 0.85 or imi_unaff_back > max(0.03, imi_back * 1.2):
            return _wrong_side_response(
                affectedSide=affectedSide,
                algo="hand_to_back_v5",
                ref=ref,
                imi=imi,
                features={
                    "ref_unaffWristToHipMin": ref_hip,
                    "imi_affWristToHipMin": imi_hip,
                    "imi_unaffWristToHipMin": imi_unaff_hip,
                    "ref_unaffBackReachMax": ref_back,
                    "imi_affBackReachMax": imi_back,
                    "imi_unaffBackReachMax": imi_unaff_back,
                },
            )

        return _no_motion_response(
            affectedSide=affectedSide,
            reason="no_meaningful_hand_to_back_detected",
            algo="hand_to_back_v5",
            ref=ref,
            imi=imi,
            features={
                "ref_unaffWristToHipMin": ref_hip,
                "imi_affWristToHipMin": imi_hip,
                "imi_unaffWristToHipMin": imi_unaff_hip,
                "ref_unaffBackReachMax": ref_back,
                "imi_affBackReachMax": imi_back,
                "imi_unaffBackReachMax": imi_unaff_back,
                "hipDistanceThreshold": 0.55,
                "backReachThreshold": 0.03,
            },
        )

    hip_score = _inverse_ratio_score(imi_hip, ref_hip)
    back_score = _ratio_score(imi_back, ref_back)
    rom = 0.60 * hip_score + 0.40 * back_score

    symmetry = max(0.0, 100.0 - 50.0 * abs(imi_hip - ref_hip))
    comp, trunk_delta, shrug_delta = _compensation_score(ref, imi, trunk_weight=0.70, shrug_weight=0.30)

    ref_series = ref["_series"][f"{unaff}WristToHipInv"]
    imi_series = imi["_series"][f"{aff}WristToHipInv"]
    timing = _timing_score_from_series(ref_series, imi_series, quality)
    smoothness = _smoothness_score_from_series(imi_series, quality)

    overall = (
        0.50 * rom +
        0.15 * symmetry +
        0.20 * comp +
        0.05 * timing +
        0.10 * smoothness
    )

    scores = {
        "overall": _score_0_100(overall),
        "symmetry": _score_0_100(symmetry),
        "timing": _score_0_100(timing),
        "smoothness": _score_0_100(smoothness),
        "compensation": _score_0_100(comp),
        "rom": _score_0_100(rom),
    }

    features = {
        "affectedSide": affectedSide,
        "motionDetected": True,
        "ref_unaffWristToHipMin": ref_hip,
        "ref_affWristToHipMin": ref_aff_hip,
        "imi_affWristToHipMin": imi_hip,
        "imi_unaffWristToHipMin": imi_unaff_hip,
        "ref_unaffBackReachMax": ref_back,
        "ref_affBackReachMax": ref_aff_back,
        "imi_affBackReachMax": imi_back,
        "imi_unaffBackReachMax": imi_unaff_back,
        "trunkDeltaDeg": trunk_delta,
        "shrugDelta": shrug_delta,
        "note": "hand_to_back_v5_reference_unaffected_vs_imitation_affected",
    }

    quality_json = {
        "analysisStatus": "done",
        "needsRetake": (quality < 0.35),
        "reason": None if quality >= 0.35 else "low_visibility_or_too_few_frames",
        "meanVisibility_ref": ref["meanVisibility"],
        "meanVisibility_imi": imi["meanVisibility"],
        "framesUsed_ref": ref["framesUsed"],
        "framesUsed_imi": imi["framesUsed"],
        "algo": "hand_to_back_v5",
    }

    return scores, features, quality_json


def score_reach_forward(
    ref: Dict[str, Any],
    imi: Dict[str, Any],
    affectedSide: str,
) -> Tuple[Dict[str, int], Dict[str, Any], Dict[str, Any]]:
    aff, unaff = _affected_unaffected_side_names(affectedSide)
    quality = _quality_score(ref, imi)

    ref_fwd = ref[f"{unaff}ReachForward"]["max"]
    ref_aff_fwd = ref[f"{aff}ReachForward"]["max"]
    imi_fwd = imi[f"{aff}ReachForward"]["max"]
    imi_unaff_fwd = imi[f"{unaff}ReachForward"]["max"]

    ref_len = ref[f"{unaff}ShoulderElev"]["max"]
    imi_len = imi[f"{aff}ShoulderElev"]["max"]

    if ref_aff_fwd > max(0.03, ref_fwd * 1.2):
        return _wrong_reference_side_response(
            affectedSide=affectedSide,
            algo="reach_forward_v5",
            ref=ref,
            imi=imi,
            features={
                "ref_unaffReachForwardMax": ref_fwd,
                "ref_affReachForwardMax": ref_aff_fwd,
                "forwardReachThreshold": 0.03,
            },
        )

    if imi_unaff_fwd > max(0.03, imi_fwd * 1.2):
        return _wrong_side_response(
            affectedSide=affectedSide,
            algo="reach_forward_v5",
            ref=ref,
            imi=imi,
            features={
                "ref_unaffReachForwardMax": ref_fwd,
                "imi_affReachForwardMax": imi_fwd,
                "imi_unaffReachForwardMax": imi_unaff_fwd,
                "forwardReachThreshold": 0.03,
            },
        )

    if imi_fwd < 0.03 and imi_len < 20.0:
        return _no_motion_response(
            affectedSide=affectedSide,
            reason="no_meaningful_forward_reach_detected",
            algo="reach_forward_v5",
            ref=ref,
            imi=imi,
            features={
                "ref_unaffReachForwardMax": ref_fwd,
                "imi_affReachForwardMax": imi_fwd,
                "imi_unaffReachForwardMax": imi_unaff_fwd,
                "ref_unaffShoulderElevMax": ref_len,
                "imi_affShoulderElevMax": imi_len,
                "forwardReachThreshold": 0.03,
                "shoulderAssistThresholdDeg": 20.0,
            },
        )

    fwd_score = _ratio_score(imi_fwd, ref_fwd)
    elev_score = _ratio_score(imi_len, ref_len)
    rom = 0.70 * fwd_score + 0.30 * elev_score

    symmetry = max(0.0, 100.0 - 120.0 * abs(imi_fwd - ref_fwd))
    comp, trunk_delta, shrug_delta = _compensation_score(ref, imi, trunk_weight=0.75, shrug_weight=0.25)

    ref_series = ref["_series"][f"{unaff}ReachForward"]
    imi_series = imi["_series"][f"{aff}ReachForward"]
    timing = _timing_score_from_series(ref_series, imi_series, quality)
    smoothness = _smoothness_score_from_series(imi_series, quality)

    overall = (
        0.45 * rom +
        0.15 * symmetry +
        0.25 * comp +
        0.05 * timing +
        0.10 * smoothness
    )

    scores = {
        "overall": _score_0_100(overall),
        "symmetry": _score_0_100(symmetry),
        "timing": _score_0_100(timing),
        "smoothness": _score_0_100(smoothness),
        "compensation": _score_0_100(comp),
        "rom": _score_0_100(rom),
    }

    features = {
        "affectedSide": affectedSide,
        "motionDetected": True,
        "ref_unaffReachForwardMax": ref_fwd,
        "ref_affReachForwardMax": ref_aff_fwd,
        "imi_affReachForwardMax": imi_fwd,
        "imi_unaffReachForwardMax": imi_unaff_fwd,
        "reference_imitationDiff": abs(imi_fwd - ref_fwd),
        "trunkDeltaDeg": trunk_delta,
        "shrugDelta": shrug_delta,
        "note": "reach_forward_v5_reference_unaffected_vs_imitation_affected",
    }

    quality_json = {
        "analysisStatus": "done",
        "needsRetake": (quality < 0.35),
        "reason": None if quality >= 0.35 else "low_visibility_or_too_few_frames",
        "meanVisibility_ref": ref["meanVisibility"],
        "meanVisibility_imi": imi["meanVisibility"],
        "framesUsed_ref": ref["framesUsed"],
        "framesUsed_imi": imi["framesUsed"],
        "algo": "reach_forward_v5",
    }

    return scores, features, quality_json


def score_reach_side(
    ref: Dict[str, Any],
    imi: Dict[str, Any],
    affectedSide: str,
) -> Tuple[Dict[str, int], Dict[str, Any], Dict[str, Any]]:
    aff, unaff = _affected_unaffected_side_names(affectedSide)
    quality = _quality_score(ref, imi)

    ref_side = ref[f"{unaff}ReachSide"]["max"]
    ref_aff_side = ref[f"{aff}ReachSide"]["max"]
    imi_side = imi[f"{aff}ReachSide"]["max"]
    imi_unaff_side = imi[f"{unaff}ReachSide"]["max"]

    ref_up = ref[f"{unaff}ReachUp"]["max"]
    imi_up = imi[f"{aff}ReachUp"]["max"]

    no_motion_threshold = 0.15

    if ref_aff_side > max(no_motion_threshold, ref_side * 1.2):
        return _wrong_reference_side_response(
            affectedSide=affectedSide,
            algo="reach_side_v5",
            ref=ref,
            imi=imi,
            features={
                "ref_unaffReachSideMax": ref_side,
                "ref_affReachSideMax": ref_aff_side,
                "motionThreshold": no_motion_threshold,
            },
        )

    if imi_unaff_side > max(no_motion_threshold, imi_side * 1.2):
        return _wrong_side_response(
            affectedSide=affectedSide,
            algo="reach_side_v5",
            ref=ref,
            imi=imi,
            features={
                "ref_unaffReachSideMax": ref_side,
                "imi_affReachSideMax": imi_side,
                "imi_unaffReachSideMax": imi_unaff_side,
                "ref_unaffReachUpMax": ref_up,
                "imi_affReachUpMax": imi_up,
                "motionThreshold": no_motion_threshold,
            },
        )

    if imi_side < no_motion_threshold:
        return _no_motion_response(
            affectedSide=affectedSide,
            reason="no_meaningful_lateral_reach_detected",
            algo="reach_side_v5",
            ref=ref,
            imi=imi,
            features={
                "ref_unaffReachSideMax": ref_side,
                "imi_affReachSideMax": imi_side,
                "imi_unaffReachSideMax": imi_unaff_side,
                "ref_unaffReachUpMax": ref_up,
                "imi_affReachUpMax": imi_up,
                "motionThreshold": no_motion_threshold,
            },
        )

    side_score = _ratio_score(imi_side, ref_side)
    up_score = _ratio_score(imi_up, ref_up)
    rom = 0.70 * side_score + 0.30 * up_score

    symmetry = max(0.0, 100.0 - 90.0 * abs(imi_side - ref_side))
    comp, trunk_delta, shrug_delta = _compensation_score(ref, imi, trunk_weight=0.60, shrug_weight=0.40)

    ref_series = ref["_series"][f"{unaff}ReachSide"]
    imi_series = imi["_series"][f"{aff}ReachSide"]
    timing = _timing_score_from_series(ref_series, imi_series, quality)
    smoothness = _smoothness_score_from_series(imi_series, quality)

    overall = (
        0.45 * rom +
        0.15 * symmetry +
        0.25 * comp +
        0.05 * timing +
        0.10 * smoothness
    )

    scores = {
        "overall": _score_0_100(overall),
        "symmetry": _score_0_100(symmetry),
        "timing": _score_0_100(timing),
        "smoothness": _score_0_100(smoothness),
        "compensation": _score_0_100(comp),
        "rom": _score_0_100(rom),
    }

    features = {
        "affectedSide": affectedSide,
        "motionDetected": True,
        "ref_unaffReachSideMax": ref_side,
        "ref_affReachSideMax": ref_aff_side,
        "imi_affReachSideMax": imi_side,
        "imi_unaffReachSideMax": imi_unaff_side,
        "ref_unaffReachUpMax": ref_up,
        "imi_affReachUpMax": imi_up,
        "reference_imitationDiff": abs(imi_side - ref_side),
        "motionThreshold": no_motion_threshold,
        "trunkDeltaDeg": trunk_delta,
        "shrugDelta": shrug_delta,
    }

    quality_json = {
        "analysisStatus": "done",
        "needsRetake": (quality < 0.35),
        "reason": None if quality >= 0.35 else "low_visibility_or_too_few_frames",
        "meanVisibility_ref": ref["meanVisibility"],
        "meanVisibility_imi": imi["meanVisibility"],
        "framesUsed_ref": ref["framesUsed"],
        "framesUsed_imi": imi["framesUsed"],
        "algo": "reach_side_v5",
    }

    return scores, features, quality_json


def score_elbow_flexion(
    ref: Dict[str, Any],
    imi: Dict[str, Any],
    affectedSide: str,
) -> Tuple[Dict[str, int], Dict[str, Any], Dict[str, Any]]:
    aff, unaff = _affected_unaffected_side_names(affectedSide)
    quality = _quality_score(ref, imi)

    ref_min = ref[f"{unaff}ElbowFlex"]["min"]
    ref_aff_min = ref[f"{aff}ElbowFlex"]["min"]
    imi_min = imi[f"{aff}ElbowFlex"]["min"]
    imi_unaff_min = imi[f"{unaff}ElbowFlex"]["min"]

    no_motion_threshold = 150.0

    if _wrong_side_by_smaller_is_better(
        aff_value=ref_aff_min,
        unaff_value=ref_min,
        aff_max_threshold=no_motion_threshold,
        dominance_ratio=0.85,
    ):
        return _wrong_reference_side_response(
            affectedSide=affectedSide,
            algo="elbow_flexion_v5",
            ref=ref,
            imi=imi,
            features={
                "ref_unaffElbowFlexMinDeg": ref_min,
                "ref_affElbowFlexMinDeg": ref_aff_min,
                "motionThresholdDeg": no_motion_threshold,
            },
        )

    if _wrong_side_by_smaller_is_better(
        aff_value=imi_min,
        unaff_value=imi_unaff_min,
        aff_max_threshold=no_motion_threshold,
        dominance_ratio=0.85,
    ):
        return _wrong_side_response(
            affectedSide=affectedSide,
            algo="elbow_flexion_v5",
            ref=ref,
            imi=imi,
            features={
                "ref_unaffElbowFlexMinDeg": ref_min,
                "imi_affElbowFlexMinDeg": imi_min,
                "imi_unaffElbowFlexMinDeg": imi_unaff_min,
                "motionThresholdDeg": no_motion_threshold,
            },
        )

    if imi_min > no_motion_threshold:
        return _no_motion_response(
            affectedSide=affectedSide,
            reason="no_meaningful_elbow_flexion_detected",
            algo="elbow_flexion_v5",
            ref=ref,
            imi=imi,
            features={
                "ref_unaffElbowFlexMinDeg": ref_min,
                "imi_affElbowFlexMinDeg": imi_min,
                "imi_unaffElbowFlexMinDeg": imi_unaff_min,
                "motionThresholdDeg": no_motion_threshold,
            },
        )

    rom = _inverse_ratio_score(imi_min, ref_min)
    symmetry = max(0.0, 100.0 - 1.2 * abs(imi_min - ref_min))
    comp, trunk_delta, shrug_delta = _compensation_score(ref, imi, trunk_weight=0.75, shrug_weight=0.25)

    ref_series = [max(0.0, 180.0 - x) for x in ref["_series"][f"{unaff}ElbowFlex"]]
    imi_series = [max(0.0, 180.0 - x) for x in imi["_series"][f"{aff}ElbowFlex"]]
    timing = _timing_score_from_series(ref_series, imi_series, quality)
    smoothness = _smoothness_score_from_series(imi_series, quality)

    overall = (
        0.50 * rom +
        0.15 * symmetry +
        0.20 * comp +
        0.05 * timing +
        0.10 * smoothness
    )

    scores = {
        "overall": _score_0_100(overall),
        "symmetry": _score_0_100(symmetry),
        "timing": _score_0_100(timing),
        "smoothness": _score_0_100(smoothness),
        "compensation": _score_0_100(comp),
        "rom": _score_0_100(rom),
    }

    features = {
        "affectedSide": affectedSide,
        "motionDetected": True,
        "ref_unaffElbowFlexMinDeg": ref_min,
        "ref_affElbowFlexMinDeg": ref_aff_min,
        "imi_affElbowFlexMinDeg": imi_min,
        "imi_unaffElbowFlexMinDeg": imi_unaff_min,
        "reference_imitationDiffDeg": abs(imi_min - ref_min),
        "trunkDeltaDeg": trunk_delta,
        "shrugDelta": shrug_delta,
        "motionThresholdDeg": no_motion_threshold,
    }

    quality_json = {
        "analysisStatus": "done",
        "needsRetake": (quality < 0.35),
        "reason": None if quality >= 0.35 else "low_visibility_or_too_few_frames",
        "meanVisibility_ref": ref["meanVisibility"],
        "meanVisibility_imi": imi["meanVisibility"],
        "framesUsed_ref": ref["framesUsed"],
        "framesUsed_imi": imi["framesUsed"],
        "algo": "elbow_flexion_v5",
    }

    return scores, features, quality_json


def score_elbow_extension(
    ref: Dict[str, Any],
    imi: Dict[str, Any],
    affectedSide: str,
) -> Tuple[Dict[str, int], Dict[str, Any], Dict[str, Any]]:
    aff, unaff = _affected_unaffected_side_names(affectedSide)
    quality = _quality_score(ref, imi)

    ref_max = ref[f"{unaff}ElbowFlex"]["max"]
    ref_aff_max = ref[f"{aff}ElbowFlex"]["max"]
    imi_max = imi[f"{aff}ElbowFlex"]["max"]
    imi_unaff_max = imi[f"{unaff}ElbowFlex"]["max"]

    no_motion_threshold = 140.0

    if ref_aff_max > max(no_motion_threshold, ref_max * 1.1):
        return _wrong_reference_side_response(
            affectedSide=affectedSide,
            algo="elbow_extension_v5",
            ref=ref,
            imi=imi,
            features={
                "ref_unaffElbowExtMaxDeg": ref_max,
                "ref_affElbowExtMaxDeg": ref_aff_max,
                "motionThresholdDeg": no_motion_threshold,
            },
        )

    if imi_unaff_max > max(no_motion_threshold, imi_max * 1.1):
        return _wrong_side_response(
            affectedSide=affectedSide,
            algo="elbow_extension_v5",
            ref=ref,
            imi=imi,
            features={
                "ref_unaffElbowExtMaxDeg": ref_max,
                "imi_affElbowExtMaxDeg": imi_max,
                "imi_unaffElbowExtMaxDeg": imi_unaff_max,
                "motionThresholdDeg": no_motion_threshold,
            },
        )

    if imi_max < no_motion_threshold:
        return _no_motion_response(
            affectedSide=affectedSide,
            reason="no_meaningful_elbow_extension_detected",
            algo="elbow_extension_v5",
            ref=ref,
            imi=imi,
            features={
                "ref_unaffElbowExtMaxDeg": ref_max,
                "imi_affElbowExtMaxDeg": imi_max,
                "imi_unaffElbowExtMaxDeg": imi_unaff_max,
                "motionThresholdDeg": no_motion_threshold,
            },
        )

    rom = _ratio_score(imi_max, ref_max)
    symmetry = max(0.0, 100.0 - 1.0 * abs(imi_max - ref_max))
    comp, trunk_delta, shrug_delta = _compensation_score(ref, imi, trunk_weight=0.75, shrug_weight=0.25)

    ref_series = ref["_series"][f"{unaff}ElbowFlex"]
    imi_series = imi["_series"][f"{aff}ElbowFlex"]
    timing = _timing_score_from_series(ref_series, imi_series, quality)
    smoothness = _smoothness_score_from_series(imi_series, quality)

    overall = (
        0.50 * rom +
        0.15 * symmetry +
        0.20 * comp +
        0.05 * timing +
        0.10 * smoothness
    )

    scores = {
        "overall": _score_0_100(overall),
        "symmetry": _score_0_100(symmetry),
        "timing": _score_0_100(timing),
        "smoothness": _score_0_100(smoothness),
        "compensation": _score_0_100(comp),
        "rom": _score_0_100(rom),
    }

    features = {
        "affectedSide": affectedSide,
        "motionDetected": True,
        "ref_unaffElbowExtMaxDeg": ref_max,
        "ref_affElbowExtMaxDeg": ref_aff_max,
        "imi_affElbowExtMaxDeg": imi_max,
        "imi_unaffElbowExtMaxDeg": imi_unaff_max,
        "reference_imitationDiffDeg": abs(imi_max - ref_max),
        "trunkDeltaDeg": trunk_delta,
        "shrugDelta": shrug_delta,
        "motionThresholdDeg": no_motion_threshold,
    }

    quality_json = {
        "analysisStatus": "done",
        "needsRetake": (quality < 0.35),
        "reason": None if quality >= 0.35 else "low_visibility_or_too_few_frames",
        "meanVisibility_ref": ref["meanVisibility"],
        "meanVisibility_imi": imi["meanVisibility"],
        "framesUsed_ref": ref["framesUsed"],
        "framesUsed_imi": imi["framesUsed"],
        "algo": "elbow_extension_v5",
    }

    return scores, features, quality_json


# =========================================================
# response helper
# =========================================================
def _build_response(
    exerciseId: int,
    affectedSide: str,
    scores: Dict[str, int],
    features: Dict[str, Any],
    quality: Dict[str, Any],
) -> Dict[str, Any]:
    ex = EXERCISES[exerciseId]
    return {
        "exerciseId": exerciseId,
        "exerciseName": ex["name"],
        "exerciseLabel": ex["label"],
        "exerciseCode": ex["code"],
        "affectedSide": affectedSide,
        **scores,
        "features": features,
        "quality": quality,
    }


# =========================================================
# api
# =========================================================
@app.post("/analyze")
async def analyze(
    reference: UploadFile = File(...),
    imitation: UploadFile = File(...),
    exerciseId: int = Form(0),
    affectedSide: str = Form("L"),
):
    if exerciseId not in EXERCISES:
        raise HTTPException(status_code=400, detail=f"Unknown exerciseId: {exerciseId}")

    ref_path = None
    imi_path = None

    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix=".mp4") as ref_file:
            shutil.copyfileobj(reference.file, ref_file)
            ref_path = ref_file.name

        with tempfile.NamedTemporaryFile(delete=False, suffix=".mp4") as imi_file:
            shutil.copyfileobj(imitation.file, imi_file)
            imi_path = imi_file.name

        ref_feat = extract_pose_features(ref_path, stride=6, max_frames=600)
        imi_feat = extract_pose_features(imi_path, stride=6, max_frames=600)

        print("=== analyze start ===")
        print("exerciseId =", exerciseId)
        print("affectedSide =", affectedSide)
        print("ref leftShoulderElev max =", ref_feat["leftShoulderElev"]["max"])
        print("ref rightShoulderElev max =", ref_feat["rightShoulderElev"]["max"])
        print("imi leftShoulderElev max =", imi_feat["leftShoulderElev"]["max"])
        print("imi rightShoulderElev max =", imi_feat["rightShoulderElev"]["max"])
        print("=====================")

        if exerciseId == 0:
            scores, features, quality = score_shoulder_flexion(ref_feat, imi_feat, affectedSide)
        elif exerciseId == 1:
            scores, features, quality = score_shoulder_abduction(ref_feat, imi_feat, affectedSide)
        elif exerciseId == 2:
            scores, features, quality = score_hand_to_head(ref_feat, imi_feat, affectedSide)
        elif exerciseId == 3:
            scores, features, quality = score_hand_to_back(ref_feat, imi_feat, affectedSide)
        elif exerciseId == 4:
            scores, features, quality = score_reach_forward(ref_feat, imi_feat, affectedSide)
        elif exerciseId == 5:
            scores, features, quality = score_reach_side(ref_feat, imi_feat, affectedSide)
        elif exerciseId == 6:
            scores, features, quality = score_elbow_flexion(ref_feat, imi_feat, affectedSide)
        elif exerciseId == 7:
            scores, features, quality = score_elbow_extension(ref_feat, imi_feat, affectedSide)
        else:
            raise HTTPException(status_code=400, detail=f"Unhandled exerciseId: {exerciseId}")

        quality["algo"] = EXERCISES[exerciseId]["algo"]
        return _build_response(exerciseId, affectedSide, scores, features, quality)

    finally:
        try:
            if ref_path and os.path.exists(ref_path):
                os.remove(ref_path)
        except Exception:
            pass

        try:
            if imi_path and os.path.exists(imi_path):
                os.remove(imi_path)
        except Exception:
            pass


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=5000)