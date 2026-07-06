from fastapi import FastAPI, UploadFile, File, Form, HTTPException
import uvicorn
import cv2
import mediapipe as mp
import numpy as np
import tempfile
import shutil
import math
import os
import time
from typing import Dict, Any, List, Tuple

app = FastAPI()
mp_pose = mp.solutions.pose
mp_hands = mp.solutions.hands


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


def _resize_frame_max_width(frame: np.ndarray, max_width: int = 640) -> np.ndarray:
    """Resize large phone frames before MediaPipe to speed up analysis."""
    if frame is None or max_width <= 0:
        return frame

    h, w = frame.shape[:2]
    if w <= max_width:
        return frame

    scale = max_width / float(w)
    new_w = int(w * scale)
    new_h = int(h * scale)
    return cv2.resize(frame, (new_w, new_h), interpolation=cv2.INTER_AREA)


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
        "needsRetake": False,
        "reason": reason,
        "scoreAsPerformed": True,
        "retakePolicy": "disabled_score_all_performance",
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
        "name": "앞으로 손 뻗기",
        "code": "reach_forward",
        "label": "앞으로 손 뻗기",
        "algo": "reach_forward_v5",
    },
    5: {
        "name": "옆으로 손 뻗기",
        "code": "reach_side",
        "label": "옆으로 손 뻗기",
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
    max_frames: int = 300,
    target_fps: float = 5.0,
    max_width: int = 640,
) -> Dict[str, Any]:
    cap = cv2.VideoCapture(video_path)

    source_fps = float(cap.get(cv2.CAP_PROP_FPS) or 0.0)
    if source_fps > 0 and target_fps > 0:
        effective_stride = max(int(round(source_fps / target_fps)), 1)
    else:
        effective_stride = max(int(stride or 1), 1)

    pose = mp_pose.Pose(
        static_image_mode=False,
        model_complexity=0,
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
        if frame_idx % effective_stride != 0:
            continue

        used += 1
        if used > max_frames:
            break

        frame = _resize_frame_max_width(frame, max_width=640)
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
            "trunkLean": trunk_angles,
            "shrugRatio": shrug_ratios,
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
        "needsRetake": False,
        "lowAnalysisQuality": (quality < 0.35),
        "reason": None if quality >= 0.35 else "low_visibility_or_too_few_frames",
        "scoreAsPerformed": True,
        "retakePolicy": "disabled_score_all_performance",
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
        "needsRetake": False,
        "lowAnalysisQuality": (quality < 0.35),
        "reason": None if quality >= 0.35 else "low_visibility_or_too_few_frames",
        "scoreAsPerformed": True,
        "retakePolicy": "disabled_score_all_performance",
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
        "needsRetake": False,
        "lowAnalysisQuality": (quality < 0.35),
        "reason": None if quality >= 0.35 else "low_visibility_or_too_few_frames",
        "scoreAsPerformed": True,
        "retakePolicy": "disabled_score_all_performance",
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
        "needsRetake": False,
        "lowAnalysisQuality": (quality < 0.35),
        "reason": None if quality >= 0.35 else "low_visibility_or_too_few_frames",
        "scoreAsPerformed": True,
        "retakePolicy": "disabled_score_all_performance",
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
        "needsRetake": False,
        "lowAnalysisQuality": (quality < 0.35),
        "reason": None if quality >= 0.35 else "low_visibility_or_too_few_frames",
        "scoreAsPerformed": True,
        "retakePolicy": "disabled_score_all_performance",
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
        "needsRetake": False,
        "lowAnalysisQuality": (quality < 0.35),
        "reason": None if quality >= 0.35 else "low_visibility_or_too_few_frames",
        "scoreAsPerformed": True,
        "retakePolicy": "disabled_score_all_performance",
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
        "needsRetake": False,
        "lowAnalysisQuality": (quality < 0.35),
        "reason": None if quality >= 0.35 else "low_visibility_or_too_few_frames",
        "scoreAsPerformed": True,
        "retakePolicy": "disabled_score_all_performance",
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
        "needsRetake": False,
        "lowAnalysisQuality": (quality < 0.35),
        "reason": None if quality >= 0.35 else "low_visibility_or_too_few_frames",
        "scoreAsPerformed": True,
        "retakePolicy": "disabled_score_all_performance",
        "meanVisibility_ref": ref["meanVisibility"],
        "meanVisibility_imi": imi["meanVisibility"],
        "framesUsed_ref": ref["framesUsed"],
        "framesUsed_imi": imi["framesUsed"],
        "algo": "elbow_extension_v5",
    }

    return scores, features, quality_json



# =========================================================
# task-oriented repetition counting helpers
# =========================================================
def _count_repetitions_from_series(
    series: List[float],
    *,
    min_amplitude: float = 0.08,
    min_frames_between_counts: int = 3,
) -> int:
    """
    READY -> REACHED -> READY state machine.
    Dynamic thresholds are used so the first server version is tolerant of
    patient-specific range differences and camera placement.
    """
    if not series or len(series) < 6:
        return 0

    arr = np.array(series, dtype=np.float32)
    arr = arr[np.isfinite(arr)]
    if len(arr) < 6:
        return 0

    # light smoothing to reduce one-frame jitter
    if len(arr) >= 5:
        kernel = np.ones(3, dtype=np.float32) / 3.0
        arr = np.convolve(arr, kernel, mode="same")

    mn = float(np.percentile(arr, 10))
    mx = float(np.percentile(arr, 90))
    amp = mx - mn

    if amp < min_amplitude:
        return 0

    low_thr = mn + 0.35 * amp
    high_thr = mn + 0.70 * amp

    state = "ready"
    count = 0
    last_count_idx = -9999

    for i, v in enumerate(arr):
        value = float(v)

        if state == "ready":
            if value >= high_thr:
                state = "reached"

        elif state == "reached":
            if value <= low_thr:
                if i - last_count_idx >= min_frames_between_counts:
                    count += 1
                    last_count_idx = i
                state = "ready"

    return int(count)


def _task_series_for_exercise(
    imi: Dict[str, Any],
    exerciseId: int,
    affectedSide: str,
) -> Tuple[List[float], str, float]:
    aff, _ = _affected_unaffected_side_names(affectedSide)
    series = imi.get("_series", {})

    if exerciseId in (0, 1):
        # Shoulder flexion / abduction: shoulder elevation angle increases.
        return series.get(f"{aff}ShoulderElev", []), f"{aff}ShoulderElev", 12.0

    if exerciseId == 2:
        # Hand to head: smaller wrist-head distance is better, so use inverted distance.
        return series.get(f"{aff}WristToHeadInv", []), f"{aff}WristToHeadInv", 0.08

    if exerciseId == 3:
        # Hand to back: 2D/3D proxy is imperfect; wrist-to-hip inverted distance is the most stable proxy.
        return series.get(f"{aff}WristToHipInv", []), f"{aff}WristToHipInv", 0.08

    if exerciseId == 4:
        # Forward reach: z-axis reach can be weak on phone video.
        # Use reach-forward if detectable; otherwise fall back to shoulder elevation.
        fwd = series.get(f"{aff}ReachForward", [])
        if fwd:
            arr = np.array(fwd, dtype=np.float32)
            if len(arr) >= 6 and float(np.nanpercentile(arr, 90) - np.nanpercentile(arr, 10)) >= 0.03:
                return fwd, f"{aff}ReachForward", 0.03
        return series.get(f"{aff}ShoulderElev", []), f"{aff}ShoulderElev_fallback", 12.0

    if exerciseId == 5:
        return series.get(f"{aff}ReachSide", []), f"{aff}ReachSide", 0.08

    if exerciseId == 6:
        # Elbow flexion: elbow angle decreases; convert to flexion amount.
        elbow = series.get(f"{aff}ElbowFlex", [])
        return [max(0.0, 180.0 - float(x)) for x in elbow], f"{aff}ElbowFlexInv", 12.0

    if exerciseId == 7:
        # Elbow extension: elbow angle increases.
        return series.get(f"{aff}ElbowFlex", []), f"{aff}ElbowExtensionProxy", 12.0

    return [], "unknown", 0.08



def _detect_repetition_intervals_from_series(
    series: List[float],
    *,
    min_amplitude: float = 0.08,
    min_frames_between_counts: int = 3,
) -> List[Tuple[int, int]]:
    """
    Detect completed repetitions as READY -> REACHED -> READY intervals.
    This returns intervals so the quality scores can be calculated from the
    same successful repetitions instead of mixing max/mean/global values.
    """
    if not series or len(series) < 6:
        return []

    arr = np.array(series, dtype=np.float32)
    arr = arr[np.isfinite(arr)]
    if len(arr) < 6:
        return []

    if len(arr) >= 5:
        kernel = np.ones(3, dtype=np.float32) / 3.0
        arr = np.convolve(arr, kernel, mode="same")

    mn = float(np.percentile(arr, 10))
    mx = float(np.percentile(arr, 90))
    amp = mx - mn
    if amp < min_amplitude:
        return []

    low_thr = mn + 0.35 * amp
    high_thr = mn + 0.70 * amp

    state = "ready"
    start_idx = 0
    intervals: List[Tuple[int, int]] = []
    last_count_idx = -9999

    for i, v in enumerate(arr):
        value = float(v)
        if state == "ready":
            if value <= low_thr:
                start_idx = i
            if value >= high_thr:
                state = "reached"
        elif state == "reached":
            if value <= low_thr:
                if i - last_count_idx >= min_frames_between_counts:
                    intervals.append((max(0, start_idx), i))
                    last_count_idx = i
                state = "ready"
                start_idx = i

    return intervals


def _series_slice(series: List[float], start: int, end: int) -> List[float]:
    if not series:
        return []
    start = max(0, min(start, len(series) - 1))
    end = max(start + 1, min(end + 1, len(series)))
    return [float(x) for x in series[start:end] if np.isfinite(x)]


def _rep_primary_series_for_exercise(
    feat: Dict[str, Any],
    exerciseId: int,
    side_name: str,
) -> Tuple[List[float], str, float, str]:
    series = feat.get("_series", {})

    if exerciseId in (0, 1):
        return series.get(f"{side_name}ShoulderElev", []), f"{side_name}ShoulderElev", 12.0, "larger"
    if exerciseId == 2:
        return series.get(f"{side_name}WristToHeadInv", []), f"{side_name}WristToHeadInv", 0.08, "larger"
    if exerciseId == 3:
        return series.get(f"{side_name}WristToHipInv", []), f"{side_name}WristToHipInv", 0.08, "larger"
    if exerciseId == 4:
        fwd = series.get(f"{side_name}ReachForward", [])
        if fwd:
            arr = np.array(fwd, dtype=np.float32)
            if len(arr) >= 6 and float(np.nanpercentile(arr, 90) - np.nanpercentile(arr, 10)) >= 0.03:
                return fwd, f"{side_name}ReachForward", 0.03, "larger"
        return series.get(f"{side_name}ShoulderElev", []), f"{side_name}ShoulderElev_fallback", 12.0, "larger"
    if exerciseId == 5:
        return series.get(f"{side_name}ReachSide", []), f"{side_name}ReachSide", 0.08, "larger"
    if exerciseId == 6:
        elbow = series.get(f"{side_name}ElbowFlex", [])
        return [max(0.0, 180.0 - float(x)) for x in elbow], f"{side_name}ElbowFlexInv", 12.0, "larger"
    if exerciseId == 7:
        return series.get(f"{side_name}ElbowFlex", []), f"{side_name}ElbowExtensionProxy", 12.0, "larger"
    return [], "unknown", 0.08, "larger"


def _aggregate_scores_from_success_reps(
    *,
    exerciseId: int,
    affectedSide: str,
    ref: Dict[str, Any],
    imi: Dict[str, Any],
    base_scores: Dict[str, int],
    quality: Dict[str, Any],
) -> Tuple[Dict[str, int], Dict[str, Any]]:
    """
    Research score schema v3.
    All movement-quality items use the same representative rule:
    successful repetition mean.

    - Repetitions are detected from the task-specific affected-side series.
    - Each detected completed repetition is treated as a successful repetition.
    - ROM, symmetry, timing, smoothness, and compensation are calculated per
      successful repetition and then averaged.
    - Failed/missing repetitions are reflected through taskSuccessCount/taskScore,
      not by mixing max ROM with global smoothness.
    """
    if quality.get("needsRetake") is True:
        return base_scores, {
            "repScoreSchemaVersion": 3,
            "repAggregation": "skipped_needs_retake",
            "repDetectedCount": 0,
            "repSuccessCount": 0,
        }

    aff, unaff = _affected_unaffected_side_names(affectedSide)
    ref_series, ref_key, min_amp, _ = _rep_primary_series_for_exercise(ref, exerciseId, unaff)
    imi_series, imi_key, min_amp, _ = _rep_primary_series_for_exercise(imi, exerciseId, aff)

    intervals = _detect_repetition_intervals_from_series(
        imi_series,
        min_amplitude=min_amp,
        min_frames_between_counts=3,
    )

    if not intervals:
        return base_scores, {
            "repScoreSchemaVersion": 3,
            "repAggregation": "fallback_global_score_no_repetition_interval",
            "repDetectedCount": 0,
            "repSuccessCount": 0,
            "repSeriesKey": imi_key,
        }

    ref_arr = [float(x) for x in ref_series if np.isfinite(x)]
    if not ref_arr:
        return base_scores, {
            "repScoreSchemaVersion": 3,
            "repAggregation": "fallback_no_reference_series",
            "repDetectedCount": len(intervals),
            "repSuccessCount": len(intervals),
            "repSeriesKey": imi_key,
        }

    ref_peak = max(ref_arr)
    ref_duration = max(1, _series_duration(ref_arr))
    quality_factor = _quality_score(ref, imi)

    trunk_series = imi.get("_series", {}).get("trunkLean", [])
    shrug_series = imi.get("_series", {}).get("shrugRatio", [])
    ref_trunk = ref.get("trunkLean", {}).get("max", 0.0)
    ref_shrug = ref.get("shrugRatio", {}).get("mean", 0.0)

    rom_values: List[float] = []
    symmetry_values: List[float] = []
    timing_values: List[float] = []
    smooth_values: List[float] = []
    comp_values: List[float] = []

    for start, end in intervals:
        seg = _series_slice(imi_series, start, end)
        if len(seg) < 2:
            continue

        rep_peak = max(seg)
        rom = _ratio_score(rep_peak, ref_peak)
        symmetry = max(0.0, 100.0 - 100.0 * abs(rep_peak - ref_peak) / (abs(ref_peak) + 1e-6))
        duration_ratio = len(seg) / float(ref_duration)
        timing = 100.0 - 60.0 * abs(math.log(max(duration_ratio, 1e-6)))
        timing = _clamp(timing, 0.0, 100.0)
        smoothness = _smoothness_score_from_series(seg, quality_factor)

        trunk_seg = _series_slice(trunk_series, start, end)
        shrug_seg = _series_slice(shrug_series, start, end)
        rep_trunk = max(trunk_seg) if trunk_seg else imi.get("trunkLean", {}).get("max", 0.0)
        rep_shrug = float(np.mean(shrug_seg)) if shrug_seg else imi.get("shrugRatio", {}).get("mean", 0.0)
        trunk_delta = max(0.0, rep_trunk - ref_trunk)
        shrug_delta = max(0.0, rep_shrug - ref_shrug)
        comp = max(0.0, 100.0 - (0.65 * min(60.0, trunk_delta * 4.0) + 0.35 * min(60.0, shrug_delta * 400.0)))

        rom_values.append(rom)
        symmetry_values.append(symmetry)
        timing_values.append(timing)
        smooth_values.append(smoothness)
        comp_values.append(comp)

    if not rom_values:
        return base_scores, {
            "repScoreSchemaVersion": 3,
            "repAggregation": "fallback_empty_rep_quality",
            "repDetectedCount": len(intervals),
            "repSuccessCount": 0,
            "repSeriesKey": imi_key,
        }

    rom_mean = float(np.mean(rom_values))
    symmetry_mean = float(np.mean(symmetry_values))
    timing_mean = float(np.mean(timing_values))
    smooth_mean = float(np.mean(smooth_values))
    comp_mean = float(np.mean(comp_values))

    if exerciseId in (0, 1):
        overall = 0.40 * rom_mean + 0.20 * symmetry_mean + 0.25 * comp_mean + 0.05 * timing_mean + 0.10 * smooth_mean
    elif exerciseId in (4, 5):
        overall = 0.45 * rom_mean + 0.15 * symmetry_mean + 0.25 * comp_mean + 0.05 * timing_mean + 0.10 * smooth_mean
    else:
        overall = 0.50 * rom_mean + 0.15 * symmetry_mean + 0.20 * comp_mean + 0.05 * timing_mean + 0.10 * smooth_mean

    scores = {
        "overall": _score_0_100(overall),
        "symmetry": _score_0_100(symmetry_mean),
        "timing": _score_0_100(timing_mean),
        "smoothness": _score_0_100(smooth_mean),
        "compensation": _score_0_100(comp_mean),
        "rom": _score_0_100(rom_mean),
    }

    rep_payload = {
        "repScoreSchemaVersion": 3,
        "repAggregation": "mean_successful_repetitions",
        "repDetectedCount": int(len(intervals)),
        "repSuccessCount": int(len(rom_values)),
        "repFailedCountByTargetOnly": None,
        "repSeriesKey": imi_key,
        "refSeriesKey": ref_key,
        "romMeanSuccess": round(rom_mean, 2),
        "romMedianSuccess": round(float(np.median(rom_values)), 2),
        "romBestSuccess": round(float(np.max(rom_values)), 2),
        "symmetryMeanSuccess": round(symmetry_mean, 2),
        "timingMeanSuccess": round(timing_mean, 2),
        "smoothnessMeanSuccess": round(smooth_mean, 2),
        "compensationMeanSuccess": round(comp_mean, 2),
    }
    return scores, rep_payload

def _calculate_task_payload(
    *,
    exerciseId: int,
    affectedSide: str,
    imi: Dict[str, Any],
    scores: Dict[str, int],
    quality: Dict[str, Any],
    taskTargetCount: int,
    taskStandardVersion: str,
    scoreSchemaVersion: int,
    appVersion: str,
    rep_quality: Dict[str, Any] = None,
) -> Dict[str, Any]:
    target = max(1, int(taskTargetCount or 5))

    # If the base quality logic says retake, do not reward task success.
    if quality.get("needsRetake") is True:
        success_count = 0
        series_key = "skipped_needs_retake"
        series_frames = 0
    else:
        task_series, series_key, min_amp = _task_series_for_exercise(
            imi,
            exerciseId,
            affectedSide,
        )
        series_frames = len(task_series)
        if rep_quality and rep_quality.get("repAggregation") == "mean_successful_repetitions":
            success_count = int(rep_quality.get("repSuccessCount", 0))
            series_key = str(rep_quality.get("repSeriesKey", series_key))
        else:
            success_count = _count_repetitions_from_series(
                task_series,
                min_amplitude=min_amp,
                min_frames_between_counts=3,
            )

    success_rate = float(success_count) / float(target)
    task_score = min(success_rate * 100.0, 100.0)
    final_score = float(scores.get("overall", 0)) * 0.7 + task_score * 0.3

    return {
        "taskTargetCount": target,
        "taskSuccessCount": int(success_count),
        "taskSuccessRate": round(success_rate, 4),
        "taskScore": round(task_score, 2),
        "finalTaskOrientedScore": round(final_score, 2),
        "taskStandardVersion": taskStandardVersion,
        "taskScoreSchemaVersion": int(scoreSchemaVersion),
        "appVersion": appVersion,
        "taskCountAlgo": "task_count_state_machine_v1",
        "taskAggregationPolicy": "score_all_performance_no_auto_retake",
        "taskSeriesKey": series_key,
        "taskSeriesFrames": int(series_frames),
        **(rep_quality or {}),
    }


# =========================================================
# response helper
# =========================================================
def _build_response(
    exerciseId: int,
    affectedSide: str,
    scores: Dict[str, int],
    features: Dict[str, Any],
    quality: Dict[str, Any],
    task_payload: Dict[str, Any] = None,
) -> Dict[str, Any]:
    ex = EXERCISES[exerciseId]
    task_payload = task_payload or {}

    # keep task details both at top level for Flutter parsing
    # and inside features for later CSV / debugging.
    if task_payload:
        features = {
            **features,
            "task": task_payload,
        }

    return {
        "exerciseId": exerciseId,
        "exerciseName": ex["name"],
        "exerciseLabel": ex["label"],
        "exerciseCode": ex["code"],
        "affectedSide": affectedSide,
        **scores,
        **task_payload,
        "features": features,
        "quality": quality,
        "retakePolicy": "disabled_score_all_performance",
    }

# =========================================================
# screening helpers / extraction / scoring
# =========================================================
def _screening_quality(mean_visibility: float, frames_used: int) -> float:
    return _clamp01(mean_visibility / 0.7) * _clamp01(frames_used / 30.0)


def _screening_quality_json(
    *,
    algo: str,
    mean_visibility: float,
    frames_used: int,
    proxy_only: bool = False,
) -> Dict[str, Any]:
    quality = _screening_quality(mean_visibility, frames_used)
    needs_retake = (mean_visibility < 0.35) or (frames_used < 12)

    return {
        "analysisStatus": "done",
        "needsRetake": needs_retake,
        "reason": None if not needs_retake else "low_visibility_or_too_few_frames",
        "meanVisibility": mean_visibility,
        "framesUsed": frames_used,
        "proxyOnly": proxy_only,
        "algo": algo,
    }


def _screening_compensation_score(trunk_lean_max: float, shrug_ratio_mean: float) -> float:
    trunk_pen = max(0.0, trunk_lean_max - 10.0) * 3.0
    shrug_pen = max(0.0, shrug_ratio_mean - 0.32) * 150.0
    return _clamp(100.0 - trunk_pen - shrug_pen, 0.0, 100.0)


def _vector_angle_series(video_path: str, affectedSide: str, stride: int = 4, max_frames: int = 180) -> List[float]:
    """
    forearm proxy:
    affected side의 elbow->wrist 벡터의 영상 평면 각도 변화를 이용해 회내/회외를 매우 거칠게 추정
    (pose 기반 proxy이므로 정확도는 낮음)
    """
    cap = cv2.VideoCapture(video_path)
    source_fps = float(cap.get(cv2.CAP_PROP_FPS) or 0.0)
    effective_stride = max(int(round(source_fps / 5.0)), 1) if source_fps > 0 else max(int(stride or 1), 1)

    pose = mp_pose.Pose(
        static_image_mode=False,
        model_complexity=0,
        enable_segmentation=False,
        min_detection_confidence=0.5,
        min_tracking_confidence=0.5,
    )

    aff, _ = _affected_unaffected_side_names(affectedSide)

    if aff == "left":
        EL, WR = 13, 15
    else:
        EL, WR = 14, 16

    series: List[float] = []
    frame_idx = 0
    used = 0

    while True:
        ret, frame = cap.read()
        if not ret:
            break
        frame_idx += 1
        if frame_idx % effective_stride != 0:
            continue
        used += 1
        if used > max_frames:
            break

        frame = _resize_frame_max_width(frame, max_width=640)
        rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        res = pose.process(rgb)
        if not res.pose_landmarks:
            continue

        lm = res.pose_landmarks.landmark
        ex, ey = lm[EL].x, lm[EL].y
        wx, wy = lm[WR].x, lm[WR].y
        vx, vy = wx - ex, wy - ey

        if abs(vx) < 1e-6 and abs(vy) < 1e-6:
            continue

        ang = math.degrees(math.atan2(vy, vx))
        series.append(float(ang))

    cap.release()
    pose.close()

    if len(series) < 2:
        return series

    arr = np.unwrap(np.radians(np.array(series, dtype=np.float32)))
    return [float(x) for x in np.degrees(arr)]


def _hand_open_series(video_path: str, stride: int = 4, max_frames: int = 180) -> List[float]:
    """
    hand screening용:
    손가락 tip ~ MCP / wrist 거리 기반 open-close proxy
    """
    cap = cv2.VideoCapture(video_path)
    source_fps = float(cap.get(cv2.CAP_PROP_FPS) or 0.0)
    effective_stride = max(int(round(source_fps / 5.0)), 1) if source_fps > 0 else max(int(stride or 1), 1)

    hands = mp_hands.Hands(
        static_image_mode=False,
        max_num_hands=2,
        model_complexity=0,
        min_detection_confidence=0.5,
        min_tracking_confidence=0.5,
    )

    frame_idx = 0
    used = 0
    series: List[float] = []

    tip_ids = [8, 12, 16, 20]
    mcp_ids = [5, 9, 13, 17]
    wrist_id = 0

    while True:
        ret, frame = cap.read()
        if not ret:
            break
        frame_idx += 1
        if frame_idx % effective_stride != 0:
            continue
        used += 1
        if used > max_frames:
            break

        frame = _resize_frame_max_width(frame, max_width=640)
        rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        res = hands.process(rgb)
        if not res.multi_hand_landmarks:
            continue

        best_open = None
        for hand_lm in res.multi_hand_landmarks:
            lm = hand_lm.landmark

            wrist = np.array([lm[wrist_id].x, lm[wrist_id].y], dtype=np.float32)
            index_mcp = np.array([lm[5].x, lm[5].y], dtype=np.float32)
            pinky_mcp = np.array([lm[17].x, lm[17].y], dtype=np.float32)
            hand_scale = float(np.linalg.norm(index_mcp - pinky_mcp) + 1e-6)

            vals = []
            for tip_id, mcp_id in zip(tip_ids, mcp_ids):
                tip = np.array([lm[tip_id].x, lm[tip_id].y], dtype=np.float32)
                mcp = np.array([lm[mcp_id].x, lm[mcp_id].y], dtype=np.float32)
                vals.append(float(np.linalg.norm(tip - wrist) / hand_scale))
                vals.append(float(np.linalg.norm(tip - mcp) / hand_scale))

            openness = float(np.mean(vals))
            if best_open is None or openness > best_open:
                best_open = openness

        if best_open is not None:
            series.append(best_open)

    cap.release()
    hands.close()
    return series


def extract_screening_features(
    video_path: str,
    affectedSide: str,
    functionKey: str,
    stride: int = 4,
    max_frames: int = 240,
) -> Dict[str, Any]:
    """
    screening용 단일 영상 feature extraction
    """
    pose_feat = extract_pose_features(video_path, stride=stride, max_frames=max_frames)
    aff, _ = _affected_unaffected_side_names(affectedSide)

    features = {
        "framesUsed": pose_feat["framesUsed"],
        "meanVisibility": pose_feat["meanVisibility"],
        "trunkLean": pose_feat["trunkLean"],
        "shrugRatio": pose_feat["shrugRatio"],
    }

    if functionKey == "flexion":
        features["motion"] = pose_feat[f"{aff}ShoulderElev"]
        features["targetPeakDeg"] = 90.0

    elif functionKey == "abduction":
        features["motion"] = pose_feat[f"{aff}ShoulderElev"]
        features["targetPeakDeg"] = 70.0

    elif functionKey == "hand_to_head":
        features["wristToHead"] = pose_feat[f"{aff}WristToHead"]
        features["elbowStats"] = pose_feat[f"{aff}ElbowFlex"]
        features["targetDistance"] = 0.45
        features["targetElbowMinDeg"] = 75.0

    elif functionKey == "hand_to_back":
        features["wristToHip"] = pose_feat[f"{aff}WristToHip"]
        features["backReach"] = pose_feat[f"{aff}BackReach"]
        features["targetHipDistance"] = 0.55
        features["targetBackReach"] = 0.05

    elif functionKey == "reach_forward":
        features["reachForward"] = pose_feat[f"{aff}ReachForward"]
        features["shoulderElev"] = pose_feat[f"{aff}ShoulderElev"]
        features["targetReach"] = 0.12
        features["targetElevDeg"] = 25.0

    elif functionKey == "reach_side":
        features["reachSide"] = pose_feat[f"{aff}ReachSide"]
        features["reachUp"] = pose_feat[f"{aff}ReachUp"]
        features["targetReach"] = 0.18
        features["targetUp"] = 0.10

    elif functionKey == "elbow_flexion":
        elbow_stats = pose_feat[f"{aff}ElbowFlex"]
        features["elbowStats"] = elbow_stats
        features["targetMinDeg"] = 70.0

    elif functionKey == "elbow_extension":
        elbow_stats = pose_feat[f"{aff}ElbowFlex"]
        features["elbowStats"] = elbow_stats
        features["targetMaxDeg"] = 160.0

    else:
        raise HTTPException(status_code=400, detail=f"Unknown functionKey: {functionKey}")

    return features


def score_screening_flexion(feat: Dict[str, Any]) -> Tuple[int, Dict[str, Any], Dict[str, Any]]:
    peak = float(feat["motion"]["max"])
    rom = _ratio_score(peak, float(feat["targetPeakDeg"]))
    comp = _screening_compensation_score(
        trunk_lean_max=float(feat["trunkLean"]["max"]),
        shrug_ratio_mean=float(feat["shrugRatio"]["mean"]),
    )
    overall = 0.75 * rom + 0.25 * comp

    features = {
        "functionKey": "flexion",
        "peakDeg": peak,
        "targetPeakDeg": feat["targetPeakDeg"],
        "trunkLeanMaxDeg": feat["trunkLean"]["max"],
        "shrugRatioMean": feat["shrugRatio"]["mean"],
        "romScore": _score_0_100(rom),
        "compensationScore": _score_0_100(comp),
    }

    quality = _screening_quality_json(
        algo="screening_flexion_v1",
        mean_visibility=float(feat["meanVisibility"]),
        frames_used=int(feat["framesUsed"]),
    )
    return _score_0_100(overall), features, quality


def score_screening_abduction(feat: Dict[str, Any]) -> Tuple[int, Dict[str, Any], Dict[str, Any]]:
    peak = float(feat["motion"]["max"])
    rom = _ratio_score(peak, float(feat["targetPeakDeg"]))
    comp = _screening_compensation_score(
        trunk_lean_max=float(feat["trunkLean"]["max"]),
        shrug_ratio_mean=float(feat["shrugRatio"]["mean"]),
    )
    overall = 0.75 * rom + 0.25 * comp

    features = {
        "functionKey": "abduction",
        "peakDeg": peak,
        "targetPeakDeg": feat["targetPeakDeg"],
        "trunkLeanMaxDeg": feat["trunkLean"]["max"],
        "shrugRatioMean": feat["shrugRatio"]["mean"],
        "romScore": _score_0_100(rom),
        "compensationScore": _score_0_100(comp),
    }

    quality = _screening_quality_json(
        algo="screening_abduction_v1",
        mean_visibility=float(feat["meanVisibility"]),
        frames_used=int(feat["framesUsed"]),
    )
    return _score_0_100(overall), features, quality


def score_screening_hand_to_head(feat: Dict[str, Any]) -> Tuple[int, Dict[str, Any], Dict[str, Any]]:
    wrist_min = float(feat["wristToHead"]["min"])
    elbow_min = float(feat["elbowStats"]["min"])

    dist_score = _inverse_ratio_score(wrist_min, float(feat["targetDistance"]))
    elbow_score = _inverse_ratio_score(elbow_min, float(feat["targetElbowMinDeg"]))
    comp = _screening_compensation_score(
        trunk_lean_max=float(feat["trunkLean"]["max"]),
        shrug_ratio_mean=float(feat["shrugRatio"]["mean"]),
    )

    overall = 0.55 * dist_score + 0.25 * elbow_score + 0.20 * comp

    features = {
        "functionKey": "hand_to_head",
        "wristToHeadMin": wrist_min,
        "targetDistance": feat["targetDistance"],
        "elbowMinDeg": elbow_min,
        "targetElbowMinDeg": feat["targetElbowMinDeg"],
        "trunkLeanMaxDeg": feat["trunkLean"]["max"],
        "shrugRatioMean": feat["shrugRatio"]["mean"],
        "distanceScore": _score_0_100(dist_score),
        "elbowScore": _score_0_100(elbow_score),
        "compensationScore": _score_0_100(comp),
    }

    quality = _screening_quality_json(
        algo="screening_hand_to_head_v1",
        mean_visibility=float(feat["meanVisibility"]),
        frames_used=int(feat["framesUsed"]),
    )
    return _score_0_100(overall), features, quality


def score_screening_hand_to_back(feat: Dict[str, Any]) -> Tuple[int, Dict[str, Any], Dict[str, Any]]:
    hip_min = float(feat["wristToHip"]["min"])
    back_max = float(feat["backReach"]["max"])

    hip_score = _inverse_ratio_score(hip_min, float(feat["targetHipDistance"]))
    back_score = _ratio_score(back_max, float(feat["targetBackReach"]))
    comp = _screening_compensation_score(
        trunk_lean_max=float(feat["trunkLean"]["max"]),
        shrug_ratio_mean=float(feat["shrugRatio"]["mean"]),
    )

    overall = 0.45 * hip_score + 0.35 * back_score + 0.20 * comp

    features = {
        "functionKey": "hand_to_back",
        "wristToHipMin": hip_min,
        "targetHipDistance": feat["targetHipDistance"],
        "backReachMax": back_max,
        "targetBackReach": feat["targetBackReach"],
        "trunkLeanMaxDeg": feat["trunkLean"]["max"],
        "shrugRatioMean": feat["shrugRatio"]["mean"],
        "hipScore": _score_0_100(hip_score),
        "backScore": _score_0_100(back_score),
        "compensationScore": _score_0_100(comp),
    }

    quality = _screening_quality_json(
        algo="screening_hand_to_back_v1",
        mean_visibility=float(feat["meanVisibility"]),
        frames_used=int(feat["framesUsed"]),
    )
    return _score_0_100(overall), features, quality


def score_screening_reach_forward(feat: Dict[str, Any]) -> Tuple[int, Dict[str, Any], Dict[str, Any]]:
    reach = float(feat["reachForward"]["max"])
    elev = float(feat["shoulderElev"]["max"])

    reach_score = _ratio_score(reach, float(feat["targetReach"]))
    elev_score = _ratio_score(elev, float(feat["targetElevDeg"]))
    comp = _screening_compensation_score(
        trunk_lean_max=float(feat["trunkLean"]["max"]),
        shrug_ratio_mean=float(feat["shrugRatio"]["mean"]),
    )

    overall = 0.55 * reach_score + 0.20 * elev_score + 0.25 * comp

    features = {
        "functionKey": "reach_forward",
        "reachForwardMax": reach,
        "targetReach": feat["targetReach"],
        "shoulderElevMaxDeg": elev,
        "targetElevDeg": feat["targetElevDeg"],
        "trunkLeanMaxDeg": feat["trunkLean"]["max"],
        "shrugRatioMean": feat["shrugRatio"]["mean"],
        "reachScore": _score_0_100(reach_score),
        "elevationScore": _score_0_100(elev_score),
        "compensationScore": _score_0_100(comp),
    }

    quality = _screening_quality_json(
        algo="screening_reach_forward_v1",
        mean_visibility=float(feat["meanVisibility"]),
        frames_used=int(feat["framesUsed"]),
    )
    return _score_0_100(overall), features, quality


def score_screening_reach_side(feat: Dict[str, Any]) -> Tuple[int, Dict[str, Any], Dict[str, Any]]:
    reach = float(feat["reachSide"]["max"])
    up = float(feat["reachUp"]["max"])

    reach_score = _ratio_score(reach, float(feat["targetReach"]))
    up_score = _ratio_score(up, float(feat["targetUp"]))
    comp = _screening_compensation_score(
        trunk_lean_max=float(feat["trunkLean"]["max"]),
        shrug_ratio_mean=float(feat["shrugRatio"]["mean"]),
    )

    overall = 0.55 * reach_score + 0.20 * up_score + 0.25 * comp

    features = {
        "functionKey": "reach_side",
        "reachSideMax": reach,
        "targetReach": feat["targetReach"],
        "reachUpMax": up,
        "targetUp": feat["targetUp"],
        "trunkLeanMaxDeg": feat["trunkLean"]["max"],
        "shrugRatioMean": feat["shrugRatio"]["mean"],
        "reachScore": _score_0_100(reach_score),
        "upScore": _score_0_100(up_score),
        "compensationScore": _score_0_100(comp),
    }

    quality = _screening_quality_json(
        algo="screening_reach_side_v1",
        mean_visibility=float(feat["meanVisibility"]),
        frames_used=int(feat["framesUsed"]),
    )
    return _score_0_100(overall), features, quality


def score_screening_elbow_flexion(feat: Dict[str, Any]) -> Tuple[int, Dict[str, Any], Dict[str, Any]]:
    elbow_min = float(feat["elbowStats"]["min"])
    rom = _inverse_ratio_score(elbow_min, float(feat["targetMinDeg"]))
    comp = _screening_compensation_score(
        trunk_lean_max=float(feat["trunkLean"]["max"]),
        shrug_ratio_mean=float(feat["shrugRatio"]["mean"]),
    )

    overall = 0.80 * rom + 0.20 * comp

    features = {
        "functionKey": "elbow_flexion",
        "elbowMinDeg": elbow_min,
        "targetMinDeg": feat["targetMinDeg"],
        "trunkLeanMaxDeg": feat["trunkLean"]["max"],
        "shrugRatioMean": feat["shrugRatio"]["mean"],
        "romScore": _score_0_100(rom),
        "compensationScore": _score_0_100(comp),
    }

    quality = _screening_quality_json(
        algo="screening_elbow_flexion_v1",
        mean_visibility=float(feat["meanVisibility"]),
        frames_used=int(feat["framesUsed"]),
    )
    return _score_0_100(overall), features, quality


def score_screening_elbow_extension(feat: Dict[str, Any]) -> Tuple[int, Dict[str, Any], Dict[str, Any]]:
    elbow_max = float(feat["elbowStats"]["max"])
    rom = _ratio_score(elbow_max, float(feat["targetMaxDeg"]))
    comp = _screening_compensation_score(
        trunk_lean_max=float(feat["trunkLean"]["max"]),
        shrug_ratio_mean=float(feat["shrugRatio"]["mean"]),
    )

    overall = 0.80 * rom + 0.20 * comp

    features = {
        "functionKey": "elbow_extension",
        "elbowMaxDeg": elbow_max,
        "targetMaxDeg": feat["targetMaxDeg"],
        "trunkLeanMaxDeg": feat["trunkLean"]["max"],
        "shrugRatioMean": feat["shrugRatio"]["mean"],
        "romScore": _score_0_100(rom),
        "compensationScore": _score_0_100(comp),
    }

    quality = _screening_quality_json(
        algo="screening_elbow_extension_v1",
        mean_visibility=float(feat["meanVisibility"]),
        frames_used=int(feat["framesUsed"]),
    )
    return _score_0_100(overall), features, quality


def score_screening_motion(
    feat: Dict[str, Any],
    functionKey: str,
) -> Tuple[int, Dict[str, Any], Dict[str, Any]]:
    if functionKey == "flexion":
        return score_screening_flexion(feat)
    elif functionKey == "abduction":
        return score_screening_abduction(feat)
    elif functionKey == "hand_to_head":
        return score_screening_hand_to_head(feat)
    elif functionKey == "hand_to_back":
        return score_screening_hand_to_back(feat)
    elif functionKey == "reach_forward":
        return score_screening_reach_forward(feat)
    elif functionKey == "reach_side":
        return score_screening_reach_side(feat)
    elif functionKey == "elbow_flexion":
        return score_screening_elbow_flexion(feat)
    elif functionKey == "elbow_extension":
        return score_screening_elbow_extension(feat)
    else:
        raise HTTPException(status_code=400, detail=f"Unknown functionKey: {functionKey}")

# =========================================================
# api
# =========================================================
@app.post("/screening_analyze")
async def screening_analyze(
    video: UploadFile = File(...),
    exerciseId: int = Form(0),
    affectedSide: str = Form("L"),
    functionKey: str = Form("flexion"),
):
    tmp_path = None

    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix=".mp4") as tmp_file:
            shutil.copyfileobj(video.file, tmp_file)
            tmp_path = tmp_file.name

        feat = extract_screening_features(
            tmp_path,
            affectedSide=affectedSide,
            functionKey=functionKey,
            stride=4,
            max_frames=240,
        )

        overall, features, quality = score_screening_motion(feat, functionKey)

        return {
            "exerciseId": exerciseId,
            "affectedSide": affectedSide,
            "functionKey": functionKey,
            "overall": overall,
            "features": features,
            "quality": quality,
        }

    finally:
        try:
            if tmp_path and os.path.exists(tmp_path):
                os.remove(tmp_path)
        except Exception:
            pass


@app.post("/analyze")
async def analyze(
    reference: UploadFile = File(...),
    imitation: UploadFile = File(...),
    exerciseId: int = Form(0),
    affectedSide: str = Form("L"),
    taskTargetCount: int = Form(5),
    taskStandardVersion: str = Form("task-standard-v1"),
    scoreSchemaVersion: int = Form(3),
    appVersion: str = Form(""),
):
    if exerciseId not in EXERCISES:
        raise HTTPException(status_code=400, detail=f"Unknown exerciseId: {exerciseId}")

    ref_path = None
    imi_path = None

    try:
        analyze_t0 = time.perf_counter()

        with tempfile.NamedTemporaryFile(delete=False, suffix=".mp4") as ref_file:
            shutil.copyfileobj(reference.file, ref_file)
            ref_path = ref_file.name

        with tempfile.NamedTemporaryFile(delete=False, suffix=".mp4") as imi_file:
            shutil.copyfileobj(imitation.file, imi_file)
            imi_path = imi_file.name

        upload_saved_t = time.perf_counter()

        # Fast analysis setting:
        # - sample about 5 frames/sec instead of processing every frame
        # - resize large phone video frames to max width 640px
        # - MediaPipe Pose model_complexity=0 inside extract_pose_features()
        ref_feat = extract_pose_features(ref_path, stride=6, max_frames=120, target_fps=5.0, max_width=640)
        ref_done_t = time.perf_counter()

        imi_feat = extract_pose_features(imi_path, stride=6, max_frames=320, target_fps=5.0, max_width=640)
        imi_done_t = time.perf_counter()

        print("=== analyze start ===")
        print("exerciseId =", exerciseId)
        print("affectedSide =", affectedSide)
        print("ref leftShoulderElev max =", ref_feat["leftShoulderElev"]["max"])
        print("ref rightShoulderElev max =", ref_feat["rightShoulderElev"]["max"])
        print("imi leftShoulderElev max =", imi_feat["leftShoulderElev"]["max"])
        print("imi rightShoulderElev max =", imi_feat["rightShoulderElev"]["max"])
        print("framesUsed_ref =", ref_feat["framesUsed"])
        print("framesUsed_imi =", imi_feat["framesUsed"])
        print("time_save_upload_sec =", round(upload_saved_t - analyze_t0, 3))
        print("time_ref_extract_sec =", round(ref_done_t - upload_saved_t, 3))
        print("time_imi_extract_sec =", round(imi_done_t - ref_done_t, 3))
        print("=====================")

        score_t0 = time.perf_counter()

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

        scores, rep_quality = _aggregate_scores_from_success_reps(
            exerciseId=exerciseId,
            affectedSide=affectedSide,
            ref=ref_feat,
            imi=imi_feat,
            base_scores=scores,
            quality=quality,
        )
        features = {
            **features,
            "repQuality": rep_quality,
            "scoreDefinition": "quality_items_are_mean_of_successful_repetitions; failed_or_missing_reps_are_reflected_in_taskScore",
        }

        task_payload = _calculate_task_payload(
            exerciseId=exerciseId,
            affectedSide=affectedSide,
            imi=imi_feat,
            scores=scores,
            quality=quality,
            taskTargetCount=taskTargetCount,
            taskStandardVersion=taskStandardVersion,
            scoreSchemaVersion=scoreSchemaVersion,
            appVersion=appVersion,
            rep_quality=rep_quality,
        )

        analyze_done_t = time.perf_counter()

        print("taskTargetCount =", task_payload["taskTargetCount"])
        print("taskSuccessCount =", task_payload["taskSuccessCount"])
        print("taskScore =", task_payload["taskScore"])
        print("finalTaskOrientedScore =", task_payload["finalTaskOrientedScore"])
        print("time_scoring_sec =", round(analyze_done_t - score_t0, 3))
        print("time_total_analyze_sec =", round(analyze_done_t - analyze_t0, 3))

        return _build_response(
            exerciseId,
            affectedSide,
            scores,
            features,
            quality,
            task_payload=task_payload,
        )

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

