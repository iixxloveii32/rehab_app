from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.responses import JSONResponse
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


# =========================================================
# exercise registry
# =========================================================
EXERCISES = {
    0: {
        "name": "팔 앞으로 들기",
        "code": "shoulder_flexion",
        "label": "팔 앞으로 들기",
        "algo": "shoulder_flexion_v1",
    },
    1: {
        "name": "팔 옆으로 들기",
        "code": "shoulder_abduction",
        "label": "팔 옆으로 들기",
        "algo": "shoulder_abduction_v1",
    },
    2: {
        "name": "머리 만지기",
        "code": "hand_to_head",
        "label": "머리 만지기",
        "algo": "hand_to_head_v1",
    },
    3: {
        "name": "허리 뒤로 손 가져가기",
        "code": "hand_to_back",
        "label": "허리 뒤로 손 가져가기",
        "algo": "hand_to_back_v1",
    },
    4: {
        "name": "앞 물건 잡기",
        "code": "reach_forward",
        "label": "앞 물건 잡기",
        "algo": "reach_forward_v1",
    },
    5: {
        "name": "옆 물건 잡기",
        "code": "reach_side",
        "label": "옆 물건 잡기",
        "algo": "reach_side_v1",
    },
    6: {
        "name": "팔 굽히기",
        "code": "elbow_flexion",
        "label": "팔 굽히기",
        "algo": "elbow_flexion_v1",
    },
    7: {
        "name": "팔 펴기",
        "code": "elbow_extension",
        "label": "팔 펴기",
        "algo": "elbow_extension_v1",
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
        lel3, rel3 = p3(L_EL), p3(R_EL)
        lwr3, rwr3 = p3(L_WR), p3(R_WR)
        lhip3, rhip3 = p3(L_HIP), p3(R_HIP)

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
    side = _side_name(affectedSide)
    opp = _opp_side_name(affectedSide)
    quality = _quality_score(ref, imi)

    ref_peak = ref[f"{side}ShoulderElev"]["max"]
    imi_peak = imi[f"{side}ShoulderElev"]["max"]
    opp_peak = imi[f"{opp}ShoulderElev"]["max"]

    no_motion_threshold = 25.0
    if imi_peak < no_motion_threshold:
        return _no_motion_response(
            affectedSide=affectedSide,
            reason="no_meaningful_shoulder_flexion_detected",
            algo="shoulder_flexion_v1",
            ref=ref,
            imi=imi,
            features={
                "ref_affShoulderElevMax": ref_peak,
                "imi_affShoulderElevMax": imi_peak,
                "motionThresholdDeg": no_motion_threshold,
            },
        )

    rom = _ratio_score(imi_peak, ref_peak)
    symmetry = max(0.0, 100.0 - (abs(imi_peak - opp_peak) * 2.5))
    comp, trunk_delta, shrug_delta = _compensation_score(ref, imi, trunk_weight=0.6, shrug_weight=0.4)

    ref_series = ref["_series"][f"{side}ShoulderElev"]
    imi_series = imi["_series"][f"{side}ShoulderElev"]
    timing = _timing_score_from_series(ref_series, imi_series, quality)
    smoothness = _smoothness_score_from_series(imi_series, quality)

    overall = (
        0.40 * rom +
        0.25 * comp +
        0.20 * symmetry +
        0.10 * smoothness +
        0.05 * timing
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
        "ref_affShoulderElevMax": ref_peak,
        "imi_affShoulderElevMax": imi_peak,
        "imi_oppShoulderElevMax": opp_peak,
        "imi_symmetryDiffDeg": abs(imi_peak - opp_peak),
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
        "algo": "shoulder_flexion_v1",
    }

    return scores, features, quality_json


def score_shoulder_abduction(
    ref: Dict[str, Any],
    imi: Dict[str, Any],
    affectedSide: str,
) -> Tuple[Dict[str, int], Dict[str, Any], Dict[str, Any]]:
    side = _side_name(affectedSide)
    opp = _opp_side_name(affectedSide)
    quality = _quality_score(ref, imi)

    ref_peak = ref[f"{side}ShoulderElev"]["max"]
    imi_peak = imi[f"{side}ShoulderElev"]["max"]
    opp_peak = imi[f"{opp}ShoulderElev"]["max"]

    no_motion_threshold = 25.0
    if imi_peak < no_motion_threshold:
        return _no_motion_response(
            affectedSide=affectedSide,
            reason="no_meaningful_shoulder_abduction_detected",
            algo="shoulder_abduction_v1",
            ref=ref,
            imi=imi,
            features={
                "ref_affShoulderElevMax": ref_peak,
                "imi_affShoulderElevMax": imi_peak,
                "motionThresholdDeg": no_motion_threshold,
            },
        )

    rom = _ratio_score(imi_peak, ref_peak)
    symmetry = max(0.0, 100.0 - (abs(imi_peak - opp_peak) * 2.5))
    comp, trunk_delta, shrug_delta = _compensation_score(ref, imi, trunk_weight=0.55, shrug_weight=0.45)

    ref_series = ref["_series"][f"{side}ShoulderElev"]
    imi_series = imi["_series"][f"{side}ShoulderElev"]
    timing = _timing_score_from_series(ref_series, imi_series, quality)
    smoothness = _smoothness_score_from_series(imi_series, quality)

    overall = (
        0.35 * rom +
        0.30 * comp +
        0.20 * symmetry +
        0.10 * smoothness +
        0.05 * timing
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
        "ref_affShoulderElevMax": ref_peak,
        "imi_affShoulderElevMax": imi_peak,
        "imi_oppShoulderElevMax": opp_peak,
        "imi_symmetryDiffDeg": abs(imi_peak - opp_peak),
        "ref_trunkLeanMaxDeg": ref["trunkLean"]["max"],
        "imi_trunkLeanMaxDeg": imi["trunkLean"]["max"],
        "ref_shrugRatioMean": ref["shrugRatio"]["mean"],
        "imi_shrugRatioMean": imi["shrugRatio"]["mean"],
        "trunkDeltaDeg": trunk_delta,
        "shrugDelta": shrug_delta,
        "motionThresholdDeg": no_motion_threshold,
        "note": "abduction_v1_uses_pose_heuristics",
    }

    quality_json = {
        "analysisStatus": "done",
        "needsRetake": (quality < 0.35),
        "reason": None if quality >= 0.35 else "low_visibility_or_too_few_frames",
        "meanVisibility_ref": ref["meanVisibility"],
        "meanVisibility_imi": imi["meanVisibility"],
        "framesUsed_ref": ref["framesUsed"],
        "framesUsed_imi": imi["framesUsed"],
        "algo": "shoulder_abduction_v1",
    }

    return scores, features, quality_json


def score_hand_to_head(
    ref: Dict[str, Any],
    imi: Dict[str, Any],
    affectedSide: str,
) -> Tuple[Dict[str, int], Dict[str, Any], Dict[str, Any]]:
    side = _side_name(affectedSide)
    quality = _quality_score(ref, imi)

    ref_dist = ref[f"{side}WristToHead"]["min"]
    imi_dist = imi[f"{side}WristToHead"]["min"]

    ref_elb = ref[f"{side}ElbowFlex"]["min"]
    imi_elb = imi[f"{side}ElbowFlex"]["min"]

    no_motion_threshold = 0.65
    if imi_dist > no_motion_threshold:
        return _no_motion_response(
            affectedSide=affectedSide,
            reason="no_meaningful_hand_to_head_detected",
            algo="hand_to_head_v1",
            ref=ref,
            imi=imi,
            features={
                "ref_affWristToHeadMin": ref_dist,
                "imi_affWristToHeadMin": imi_dist,
                "distanceThreshold": no_motion_threshold,
            },
        )

    close_score = _inverse_ratio_score(imi_dist, ref_dist)
    elbow_score = _inverse_ratio_score(imi_elb, ref_elb)
    rom = 0.65 * close_score + 0.35 * elbow_score

    opp = _opp_side_name(affectedSide)
    imi_side = imi[f"{side}WristToHead"]["min"]
    imi_opp = imi[f"{opp}WristToHead"]["min"]
    symmetry = max(0.0, 100.0 - 40.0 * abs(imi_side - imi_opp))

    comp, trunk_delta, shrug_delta = _compensation_score(ref, imi, trunk_weight=0.65, shrug_weight=0.35)

    ref_series = ref["_series"][f"{side}WristToHeadInv"]
    imi_series = imi["_series"][f"{side}WristToHeadInv"]
    timing = _timing_score_from_series(ref_series, imi_series, quality)
    smoothness = _smoothness_score_from_series(imi_series, quality)

    overall = (
        0.30 * rom +
        0.30 * comp +
        0.20 * symmetry +
        0.10 * smoothness +
        0.10 * timing
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
        "ref_affWristToHeadMin": ref_dist,
        "imi_affWristToHeadMin": imi_dist,
        "ref_affElbowFlexMinDeg": ref_elb,
        "imi_affElbowFlexMinDeg": imi_elb,
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
        "algo": "hand_to_head_v1",
    }

    return scores, features, quality_json


def score_hand_to_back(
    ref: Dict[str, Any],
    imi: Dict[str, Any],
    affectedSide: str,
) -> Tuple[Dict[str, int], Dict[str, Any], Dict[str, Any]]:
    side = _side_name(affectedSide)
    quality = _quality_score(ref, imi)

    ref_hip = ref[f"{side}WristToHip"]["min"]
    imi_hip = imi[f"{side}WristToHip"]["min"]

    ref_back = ref[f"{side}BackReach"]["max"]
    imi_back = imi[f"{side}BackReach"]["max"]

    # 가까워짐 + 뒤쪽 z 이동 둘 다 너무 약하면 무동작
    if imi_hip > 0.55 and imi_back < 0.03:
        return _no_motion_response(
            affectedSide=affectedSide,
            reason="no_meaningful_hand_to_back_detected",
            algo="hand_to_back_v1",
            ref=ref,
            imi=imi,
            features={
                "ref_affWristToHipMin": ref_hip,
                "imi_affWristToHipMin": imi_hip,
                "ref_affBackReachMax": ref_back,
                "imi_affBackReachMax": imi_back,
                "hipDistanceThreshold": 0.55,
                "backReachThreshold": 0.03,
            },
        )

    hip_score = _inverse_ratio_score(imi_hip, ref_hip)
    back_score = _ratio_score(imi_back, ref_back)
    rom = 0.60 * hip_score + 0.40 * back_score

    opp = _opp_side_name(affectedSide)
    imi_side = imi[f"{side}WristToHip"]["min"]
    imi_opp = imi[f"{opp}WristToHip"]["min"]
    symmetry = max(0.0, 100.0 - 35.0 * abs(imi_side - imi_opp))

    comp, trunk_delta, shrug_delta = _compensation_score(ref, imi, trunk_weight=0.70, shrug_weight=0.30)

    ref_series = ref["_series"][f"{side}WristToHipInv"]
    imi_series = imi["_series"][f"{side}WristToHipInv"]
    timing = _timing_score_from_series(ref_series, imi_series, quality)
    smoothness = _smoothness_score_from_series(imi_series, quality)

    overall = (
        0.35 * rom +
        0.30 * comp +
        0.20 * symmetry +
        0.10 * smoothness +
        0.05 * timing
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
        "ref_affWristToHipMin": ref_hip,
        "imi_affWristToHipMin": imi_hip,
        "ref_affBackReachMax": ref_back,
        "imi_affBackReachMax": imi_back,
        "trunkDeltaDeg": trunk_delta,
        "shrugDelta": shrug_delta,
        "note": "hand_to_back_is_pose_heuristic_and_should_be_validated",
    }

    quality_json = {
        "analysisStatus": "done",
        "needsRetake": (quality < 0.35),
        "reason": None if quality >= 0.35 else "low_visibility_or_too_few_frames",
        "meanVisibility_ref": ref["meanVisibility"],
        "meanVisibility_imi": imi["meanVisibility"],
        "framesUsed_ref": ref["framesUsed"],
        "framesUsed_imi": imi["framesUsed"],
        "algo": "hand_to_back_v1",
    }

    return scores, features, quality_json


def score_reach_forward(
    ref: Dict[str, Any],
    imi: Dict[str, Any],
    affectedSide: str,
) -> Tuple[Dict[str, int], Dict[str, Any], Dict[str, Any]]:
    side = _side_name(affectedSide)
    quality = _quality_score(ref, imi)

    ref_fwd = ref[f"{side}ReachForward"]["max"]
    imi_fwd = imi[f"{side}ReachForward"]["max"]

    ref_len = ref[f"{side}ShoulderElev"]["max"]
    imi_len = imi[f"{side}ShoulderElev"]["max"]

    if imi_fwd < 0.03 and imi_len < 20.0:
        return _no_motion_response(
            affectedSide=affectedSide,
            reason="no_meaningful_forward_reach_detected",
            algo="reach_forward_v1",
            ref=ref,
            imi=imi,
            features={
                "ref_affReachForwardMax": ref_fwd,
                "imi_affReachForwardMax": imi_fwd,
                "ref_affShoulderElevMax": ref_len,
                "imi_affShoulderElevMax": imi_len,
                "forwardReachThreshold": 0.03,
                "shoulderAssistThresholdDeg": 20.0,
            },
        )

    fwd_score = _ratio_score(imi_fwd, ref_fwd)
    elev_score = _ratio_score(imi_len, ref_len)
    rom = 0.70 * fwd_score + 0.30 * elev_score

    opp = _opp_side_name(affectedSide)
    imi_side = imi[f"{side}ReachForward"]["max"]
    imi_opp = imi[f"{opp}ReachForward"]["max"]
    symmetry = max(0.0, 100.0 - 80.0 * abs(imi_side - imi_opp))

    comp, trunk_delta, shrug_delta = _compensation_score(ref, imi, trunk_weight=0.75, shrug_weight=0.25)

    ref_series = ref["_series"][f"{side}ReachForward"]
    imi_series = imi["_series"][f"{side}ReachForward"]
    timing = _timing_score_from_series(ref_series, imi_series, quality)
    smoothness = _smoothness_score_from_series(imi_series, quality)

    overall = (
        0.35 * rom +
        0.25 * comp +
        0.20 * symmetry +
        0.10 * smoothness +
        0.10 * timing
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
        "ref_affReachForwardMax": ref_fwd,
        "imi_affReachForwardMax": imi_fwd,
        "trunkDeltaDeg": trunk_delta,
        "shrugDelta": shrug_delta,
        "note": "reach_forward_uses_blazepose_z_heuristic",
    }

    quality_json = {
        "analysisStatus": "done",
        "needsRetake": (quality < 0.35),
        "reason": None if quality >= 0.35 else "low_visibility_or_too_few_frames",
        "meanVisibility_ref": ref["meanVisibility"],
        "meanVisibility_imi": imi["meanVisibility"],
        "framesUsed_ref": ref["framesUsed"],
        "framesUsed_imi": imi["framesUsed"],
        "algo": "reach_forward_v1",
    }

    return scores, features, quality_json


def score_reach_side(
    ref: Dict[str, Any],
    imi: Dict[str, Any],
    affectedSide: str,
) -> Tuple[Dict[str, int], Dict[str, Any], Dict[str, Any]]:
    side = _side_name(affectedSide)
    quality = _quality_score(ref, imi)

    ref_side = ref[f"{side}ReachSide"]["max"]
    imi_side = imi[f"{side}ReachSide"]["max"]

    ref_up = ref[f"{side}ReachUp"]["max"]
    imi_up = imi[f"{side}ReachUp"]["max"]

    no_motion_threshold = 0.15
    if imi_side < no_motion_threshold:
        return _no_motion_response(
            affectedSide=affectedSide,
            reason="no_meaningful_lateral_reach_detected",
            algo="reach_side_v1",
            ref=ref,
            imi=imi,
            features={
                "ref_affReachSideMax": ref_side,
                "imi_affReachSideMax": imi_side,
                "ref_affReachUpMax": ref_up,
                "imi_affReachUpMax": imi_up,
                "motionThreshold": no_motion_threshold,
            },
        )

    side_score = _ratio_score(imi_side, ref_side)
    up_score = _ratio_score(imi_up, ref_up)
    rom = 0.70 * side_score + 0.30 * up_score

    opp = _opp_side_name(affectedSide)
    opp_side_val = imi[f"{opp}ReachSide"]["max"]
    symmetry = max(0.0, 100.0 - 60.0 * abs(imi_side - opp_side_val))

    comp, trunk_delta, shrug_delta = _compensation_score(ref, imi, trunk_weight=0.60, shrug_weight=0.40)

    ref_series = ref["_series"][f"{side}ReachSide"]
    imi_series = imi["_series"][f"{side}ReachSide"]
    timing = _timing_score_from_series(ref_series, imi_series, quality)
    smoothness = _smoothness_score_from_series(imi_series, quality)

    overall = (
        0.35 * rom +
        0.30 * comp +
        0.20 * symmetry +
        0.10 * smoothness +
        0.05 * timing
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
        "ref_affReachSideMax": ref_side,
        "imi_affReachSideMax": imi_side,
        "ref_affReachUpMax": ref_up,
        "imi_affReachUpMax": imi_up,
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
        "algo": "reach_side_v1",
    }

    return scores, features, quality_json


def score_elbow_flexion(
    ref: Dict[str, Any],
    imi: Dict[str, Any],
    affectedSide: str,
) -> Tuple[Dict[str, int], Dict[str, Any], Dict[str, Any]]:
    side = _side_name(affectedSide)
    quality = _quality_score(ref, imi)

    ref_min = ref[f"{side}ElbowFlex"]["min"]
    imi_min = imi[f"{side}ElbowFlex"]["min"]

    no_motion_threshold = 150.0  # flexion 안 되면 팔꿈치 각도가 거의 펴진 상태
    if imi_min > no_motion_threshold:
        return _no_motion_response(
            affectedSide=affectedSide,
            reason="no_meaningful_elbow_flexion_detected",
            algo="elbow_flexion_v1",
            ref=ref,
            imi=imi,
            features={
                "ref_affElbowFlexMinDeg": ref_min,
                "imi_affElbowFlexMinDeg": imi_min,
                "motionThresholdDeg": no_motion_threshold,
            },
        )

    rom = _inverse_ratio_score(imi_min, ref_min)

    opp = _opp_side_name(affectedSide)
    opp_min = imi[f"{opp}ElbowFlex"]["min"]
    symmetry = max(0.0, 100.0 - 1.2 * abs(imi_min - opp_min))

    comp, trunk_delta, shrug_delta = _compensation_score(ref, imi, trunk_weight=0.75, shrug_weight=0.25)

    ref_series = [max(0.0, 180.0 - x) for x in ref["_series"][f"{side}ElbowFlex"]]
    imi_series = [max(0.0, 180.0 - x) for x in imi["_series"][f"{side}ElbowFlex"]]
    timing = _timing_score_from_series(ref_series, imi_series, quality)
    smoothness = _smoothness_score_from_series(imi_series, quality)

    overall = (
        0.45 * rom +
        0.20 * comp +
        0.20 * symmetry +
        0.10 * smoothness +
        0.05 * timing
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
        "ref_affElbowFlexMinDeg": ref_min,
        "imi_affElbowFlexMinDeg": imi_min,
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
        "algo": "elbow_flexion_v1",
    }

    return scores, features, quality_json


def score_elbow_extension(
    ref: Dict[str, Any],
    imi: Dict[str, Any],
    affectedSide: str,
) -> Tuple[Dict[str, int], Dict[str, Any], Dict[str, Any]]:
    side = _side_name(affectedSide)
    quality = _quality_score(ref, imi)

    ref_max = ref[f"{side}ElbowFlex"]["max"]
    imi_max = imi[f"{side}ElbowFlex"]["max"]

    no_motion_threshold = 140.0
    if imi_max < no_motion_threshold:
        return _no_motion_response(
            affectedSide=affectedSide,
            reason="no_meaningful_elbow_extension_detected",
            algo="elbow_extension_v1",
            ref=ref,
            imi=imi,
            features={
                "ref_affElbowExtMaxDeg": ref_max,
                "imi_affElbowExtMaxDeg": imi_max,
                "motionThresholdDeg": no_motion_threshold,
            },
        )

    rom = _ratio_score(imi_max, ref_max)

    opp = _opp_side_name(affectedSide)
    opp_max = imi[f"{opp}ElbowFlex"]["max"]
    symmetry = max(0.0, 100.0 - 1.0 * abs(imi_max - opp_max))

    comp, trunk_delta, shrug_delta = _compensation_score(ref, imi, trunk_weight=0.75, shrug_weight=0.25)

    ref_series = ref["_series"][f"{side}ElbowFlex"]
    imi_series = imi["_series"][f"{side}ElbowFlex"]
    timing = _timing_score_from_series(ref_series, imi_series, quality)
    smoothness = _smoothness_score_from_series(imi_series, quality)

    overall = (
        0.45 * rom +
        0.20 * comp +
        0.20 * symmetry +
        0.10 * smoothness +
        0.05 * timing
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
        "ref_affElbowExtMaxDeg": ref_max,
        "imi_affElbowExtMaxDeg": imi_max,
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
        "algo": "elbow_extension_v1",
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