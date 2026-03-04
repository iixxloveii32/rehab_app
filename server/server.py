from fastapi import FastAPI, UploadFile, File, Form
import uvicorn
import cv2
import mediapipe as mp
import numpy as np
import tempfile
import shutil
import math
from fastapi.responses import JSONResponse
from typing import Dict, Any, List, Tuple
from fastapi import HTTPException
app = FastAPI()
mp_pose = mp.solutions.pose

def _angle_deg(v1: np.ndarray, v2: np.ndarray) -> float:
    denom = (np.linalg.norm(v1) * np.linalg.norm(v2)) + 1e-9
    cosv = float(np.dot(v1, v2) / denom)
    cosv = max(-1.0, min(1.0, cosv))
    return float(math.degrees(math.acos(cosv)))

def _clamp01(x: float) -> float:
    return max(0.0, min(1.0, x))

def _score_0_100(x: float) -> int:
    return int(round(max(0.0, min(100.0, x))))

def extract_abduction_features(
    video_path: str,
    stride: int = 6,
    max_frames: int = 600
) -> Dict[str, Any]:
    """
    v1: overhead와 동일한 핵심 피처(팔 elevation, trunk lean, shrug)를 사용.
    - 외전도 결국 '상완을 들어올림' + '몸통 보상' + '견갑 거상'이 주요 품질 지표라서
      MVP에서는 overhead 피처를 그대로 재사용.
    """
    return extract_overhead_features(video_path, stride=stride, max_frames=max_frames)

def extract_overhead_features(
    video_path: str,
    stride: int = 6,
    max_frames: int = 600
) -> Dict[str, Any]:
    cap = cv2.VideoCapture(video_path)
    pose = mp_pose.Pose(
        static_image_mode=False,
        model_complexity=1,
        enable_segmentation=False,
        min_detection_confidence=0.5,
        min_tracking_confidence=0.5,
    )

    L_SH, R_SH = 11, 12
    L_EL, R_EL = 13, 14
    L_HIP, R_HIP = 23, 24

    left_angles: List[float] = []
    right_angles: List[float] = []
    trunk_angles: List[float] = []
    shrug_ratios: List[float] = []
    vis_list: List[float] = []

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
            lm[L_SH].visibility, lm[R_SH].visibility,
            lm[L_EL].visibility, lm[R_EL].visibility,
            lm[L_HIP].visibility, lm[R_HIP].visibility,
        ]))
        vis_list.append(vis)

        lsh = np.array([lm[L_SH].x, lm[L_SH].y], dtype=np.float32)
        rsh = np.array([lm[R_SH].x, lm[R_SH].y], dtype=np.float32)
        lel = np.array([lm[L_EL].x, lm[L_EL].y], dtype=np.float32)
        rel = np.array([lm[R_EL].x, lm[R_EL].y], dtype=np.float32)
        lhip = np.array([lm[L_HIP].x, lm[L_HIP].y], dtype=np.float32)
        rhip = np.array([lm[R_HIP].x, lm[R_HIP].y], dtype=np.float32)

        sh_mid = 0.5 * (lsh + rsh)
        hip_mid = 0.5 * (lhip + rhip)

        l_upper = (lel - lsh)
        l_trunk = (lhip - lsh)
        r_upper = (rel - rsh)
        r_trunk = (rhip - rsh)

        if np.linalg.norm(l_upper) > 1e-6 and np.linalg.norm(l_trunk) > 1e-6:
            left_angles.append(_angle_deg(l_upper, l_trunk))
        if np.linalg.norm(r_upper) > 1e-6 and np.linalg.norm(r_trunk) > 1e-6:
            right_angles.append(_angle_deg(r_upper, r_trunk))

        torso = (sh_mid - hip_mid)
        vertical = np.array([0.0, -1.0], dtype=np.float32)
        if np.linalg.norm(torso) > 1e-6:
            trunk_angles.append(_angle_deg(torso, vertical))

        torso_len = float(np.linalg.norm(sh_mid - hip_mid) + 1e-9)
        shoulder_height = float((lsh[1] + rsh[1]) / 2.0)
        hip_height = float((lhip[1] + rhip[1]) / 2.0)
        shrug = float((hip_height - shoulder_height) / torso_len)
        shrug_ratios.append(shrug)

    cap.release()
    pose.close()

    def safe_stats(arr: List[float]) -> Dict[str, float]:
        if not arr:
            return {"min": 0.0, "max": 0.0, "mean": 0.0}
        a = np.array(arr, dtype=np.float32)
        return {"min": float(a.min()), "max": float(a.max()), "mean": float(a.mean())}

    return {
        "framesUsed": used,
        "meanVisibility": float(np.mean(vis_list)) if vis_list else 0.0,
        "leftElev": safe_stats(left_angles),
        "rightElev": safe_stats(right_angles),
        "trunkLean": safe_stats(trunk_angles),
        "shrugRatio": safe_stats(shrug_ratios),
    }

def score_abduction_relative(
    ref: Dict[str, Any],
    imi: Dict[str, Any]
) -> Tuple[Dict[str, int], Dict[str, Any], Dict[str, Any]]:
    """
    v1: overhead scoring을 재활용.
    추후 외전 특화(팔이 옆으로 벌어지는 방향성, 전방편위 등)를 features에 추가 가능.
    """
    scores, features, quality = score_overhead_relative(ref, imi)

    # algo name만 외전으로 바꿔서 반환(quality의 algo는 analyze에서 덮어씀)
    return scores, features, quality

def score_overhead_relative(ref: Dict[str, Any], imi: Dict[str, Any]) -> Tuple[Dict[str, int], Dict[str, Any], Dict[str, Any]]:
    refL = ref["leftElev"]["max"]
    refR = ref["rightElev"]["max"]
    imiL = imi["leftElev"]["max"]
    imiR = imi["rightElev"]["max"]

    def ratio_score(imit: float, refv: float) -> float:
        if refv <= 1e-6:
            return 0.0
        return 100.0 * _clamp01(imit / refv)

    rom = (ratio_score(imiL, refL) + ratio_score(imiR, refR)) / 2.0

    diff = abs(imiL - imiR)
    symmetry = max(0.0, 100.0 - (diff * 2.5))

    refTrunk = ref["trunkLean"]["max"]
    imiTrunk = imi["trunkLean"]["max"]
    refShrug = ref["shrugRatio"]["mean"]
    imiShrug = imi["shrugRatio"]["mean"]

    trunk_delta = max(0.0, imiTrunk - refTrunk)
    shrug_delta = max(0.0, imiShrug - refShrug)

    trunk_pen = min(60.0, trunk_delta * 4.0)
    shrug_pen = min(60.0, shrug_delta * 400.0)
    comp = max(0.0, 100.0 - (0.6 * trunk_pen + 0.4 * shrug_pen))

    q_vis = min(ref["meanVisibility"], imi["meanVisibility"])
    q_frames = min(ref["framesUsed"], imi["framesUsed"])
    quality = _clamp01((q_vis / 0.7)) * _clamp01(q_frames / 40.0)

    timing = 60 + int(round(40 * quality))
    smoothness = 60 + int(round(40 * quality))

    overall = (
        0.35 * symmetry +
        0.35 * rom +
        0.15 * timing +
        0.10 * smoothness +
        0.05 * comp
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
        "ref_leftElevMax": refL,
        "ref_rightElevMax": refR,
        "imi_leftElevMax": imiL,
        "imi_rightElevMax": imiR,
        "imi_symmetryDiffDeg": diff,
        "ref_trunkLeanMaxDeg": refTrunk,
        "imi_trunkLeanMaxDeg": imiTrunk,
        "ref_shrugRatioMean": refShrug,
        "imi_shrugRatioMean": imiShrug,
        "trunkDeltaDeg": trunk_delta,
        "shrugDelta": shrug_delta,
    }

    quality_json = {
        "meanVisibility_ref": ref["meanVisibility"],
        "meanVisibility_imi": imi["meanVisibility"],
        "framesUsed_ref": ref["framesUsed"],
        "framesUsed_imi": imi["framesUsed"],
        "analysisStatus": "done",
        "needsRetake": (quality < 0.35),
        "reason": None if quality >= 0.35 else "low_visibility_or_too_few_frames",
        "algo": "blazepose_overhead_v1",
    }

    return scores, features, quality_json

EXERCISES = {
    0: {"name": "overhead_raise", "algo": "blazepose_overhead_v1"},
    1: {"name": "abduction", "algo": "blazepose_abduction_v1"},
    2: {"name": "elbow_flex_ext", "algo": "todo"},
    3: {"name": "pron_sup", "algo": "todo"},
    4: {"name": "wrist_flex_ext", "algo": "todo"},
    5: {"name": "grip_open_close", "algo": "todo"},
    6: {"name": "pinch", "algo": "todo"},
    7: {"name": "bimanual_task", "algo": "todo"},
}

def not_implemented_payload(exerciseId: int, affectedSide: str, reason: str):
    # Flutter가 항상 같은 구조로 파싱할 수 있게 "기본 키"를 유지
    return {
        "exerciseId": exerciseId,
        "exerciseName": EXERCISES.get(exerciseId, {}).get("name", "unknown"),
        "affectedSide": affectedSide,
        "overall": 0,
        "symmetry": 0,
        "timing": 0,
        "smoothness": 0,
        "compensation": 0,
        "rom": 0,
        "features": {},
        "quality": {
            "analysisStatus": "not_implemented",
            "needsRetake": False,
            "reason": reason,
            "algo": EXERCISES.get(exerciseId, {}).get("algo", "unknown"),
        },
    }

@app.post("/analyze")
async def analyze(
    reference: UploadFile = File(...),
    imitation: UploadFile = File(...),
    exerciseId: int = Form(0),
    affectedSide: str = Form("L"),
):
    if exerciseId not in EXERCISES:
        # exerciseId 자체가 잘못 온 경우
        raise HTTPException(status_code=400, detail=f"Unknown exerciseId: {exerciseId}")

    # --- save temp files ---
    with tempfile.NamedTemporaryFile(delete=False, suffix=".mp4") as ref_file:
        shutil.copyfileobj(reference.file, ref_file)
        ref_path = ref_file.name

    with tempfile.NamedTemporaryFile(delete=False, suffix=".mp4") as imi_file:
        shutil.copyfileobj(imitation.file, imi_file)
        imi_path = imi_file.name

    # --- routing ---
    if exerciseId == 0:
        # ✅ 0번(전방 거상) 기존 로직
        ref_feat = extract_overhead_features(ref_path, stride=6)
        imi_feat = extract_overhead_features(imi_path, stride=6)
        scores, features, quality = score_overhead_relative(ref_feat, imi_feat)

        # 공통 응답 포맷 통일
        return {
            "exerciseId": exerciseId,
            "exerciseName": EXERCISES[exerciseId]["name"],
            "affectedSide": affectedSide,
            **scores,
            "features": features,
            "quality": quality,
        }

        if exerciseId == 1:
        # ✅ 1번(외전) v1: overhead 피처 재활용
        ref_feat = extract_abduction_features(ref_path, stride=6)
        imi_feat = extract_abduction_features(imi_path, stride=6)
        scores, features, quality = score_abduction_relative(ref_feat, imi_feat)

        # algo 명시(quality 내부에 algo가 있으면 덮어쓰기)
        if isinstance(quality, dict):
            quality["algo"] = EXERCISES[exerciseId]["algo"]

        return {
            "exerciseId": exerciseId,
            "exerciseName": EXERCISES[exerciseId]["name"],
            "affectedSide": affectedSide,
            **scores,
            "features": {
                **features,
                "note": "abduction_v1_reuses_overhead_features",
            },
            "quality": quality,
        }

    payload = not_implemented_payload(
    exerciseId=exerciseId,
    affectedSide=affectedSide,
    reason="algorithm_not_ready_for_this_exercise",
)
return JSONResponse(status_code=501, content=payload)

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=5000)