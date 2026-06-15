#!/usr/bin/env python3
"""
extract_keypoints.py — Detecta pose na soph_base_tpose.png via MediaPipe e
salva:
  - assets/rig/soph_tpose/keypoints.json (33 landmarks + mapping nomeado)
  - assets/rig/soph_tpose/mask.png (segmentation alpha do personagem)
  - assets/rig/soph_tpose/tpose_clean.png (T-pose com fundo transparente)
"""
from __future__ import annotations
import json, sys
from pathlib import Path
import cv2
import numpy as np
import mediapipe as mp
from mediapipe.tasks import python as mptp
from mediapipe.tasks.python import vision as mpv

HERE   = Path(__file__).parent
ROOT   = HERE.parent.parent
SRC    = ROOT / "docs" / "concept_art" / "soph_base_tpose.png"
MODEL  = ROOT / "tools" / "art_director" / "models" / "pose_landmarker_heavy.task"
OUTDIR = ROOT / "assets" / "rig" / "soph_tpose"

NAMES = {
    0:"nose", 1:"L_eye_inner", 2:"L_eye", 3:"L_eye_outer",
    4:"R_eye_inner", 5:"R_eye", 6:"R_eye_outer",
    7:"L_ear", 8:"R_ear", 9:"mouth_L", 10:"mouth_R",
    11:"L_shoulder", 12:"R_shoulder",
    13:"L_elbow", 14:"R_elbow",
    15:"L_wrist", 16:"R_wrist",
    17:"L_pinky", 18:"R_pinky", 19:"L_index", 20:"R_index",
    21:"L_thumb", 22:"R_thumb",
    23:"L_hip", 24:"R_hip",
    25:"L_knee", 26:"R_knee",
    27:"L_ankle", 28:"R_ankle",
    29:"L_heel", 30:"R_heel",
    31:"L_foot_idx", 32:"R_foot_idx",
}


def main() -> int:
    OUTDIR.mkdir(parents=True, exist_ok=True)

    # 1) pose detection com segmentation mask
    base = mptp.BaseOptions(model_asset_path=str(MODEL))
    opts = mpv.PoseLandmarkerOptions(
        base_options=base,
        running_mode=mpv.RunningMode.IMAGE,
        output_segmentation_masks=True,
    )
    det = mpv.PoseLandmarker.create_from_options(opts)
    img = mp.Image.create_from_file(str(SRC))
    res = det.detect(img)
    if not res.pose_landmarks:
        print("x nao detectou pose"); return 1

    src_bgr = cv2.imread(str(SRC))
    h, w = src_bgr.shape[:2]
    print(f"image: {w}x{h}")

    # 2) salva keypoints
    lms = res.pose_landmarks[0]
    kp = {}
    for i, lm in enumerate(lms):
        kp[NAMES[i]] = {
            "x": int(round(lm.x * w)),
            "y": int(round(lm.y * h)),
            "z": float(lm.z),
            "visibility": float(lm.visibility),
        }
    # derivados uteis pra rig
    def mid(a, b):
        return {"x": (kp[a]["x"]+kp[b]["x"])//2, "y": (kp[a]["y"]+kp[b]["y"])//2}
    kp["_neck"]  = mid("L_shoulder", "R_shoulder")
    kp["_pelvis"] = mid("L_hip", "R_hip")
    kp["_spine_mid"] = {
        "x": (kp["_neck"]["x"] + kp["_pelvis"]["x"]) // 2,
        "y": (kp["_neck"]["y"] + kp["_pelvis"]["y"]) // 2,
    }

    (OUTDIR / "keypoints.json").write_text(
        json.dumps(kp, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    print(f"ok keypoints.json ({len(kp)} entries)")

    # 3) salva mask + cutout
    if res.segmentation_masks:
        mask = res.segmentation_masks[0].numpy_view()  # float 0..1
        mask = np.squeeze(np.asarray(mask))
        if mask.ndim != 2:
            print(f"  ! mask.ndim={mask.ndim}, shape={mask.shape}; pegando canal 0")
            mask = mask[..., 0] if mask.shape[-1] in (1, 3, 4) else mask[0]
        mask_u8 = (mask * 255).astype(np.uint8)
        print(f"  mask shape final={mask_u8.shape}")
        cv2.imwrite(str(OUTDIR / "mask_pose.png"), mask_u8)
        print(f"ok mask_pose.png  range=[{mask_u8.min()},{mask_u8.max()}]")
    else:
        mask_u8 = None
        print("! sem mask de pose; vou usar so threshold de branco")

    # cutout combinando: pose mask OU threshold de branco
    gray = cv2.cvtColor(src_bgr, cv2.COLOR_BGR2GRAY)
    not_white = (gray < 240).astype(np.uint8) * 255
    if mask_u8 is not None:
        # mask de pose costuma cortar cabelo/pontas — combinamos com not_white
        combo = np.maximum(mask_u8, not_white)
    else:
        combo = not_white
    # garante 2D contiguo e uint8 pra OpenCV
    combo = np.ascontiguousarray(np.squeeze(combo).astype(np.uint8))
    if combo.shape[:2] != (h, w):
        combo = cv2.resize(combo, (w, h), interpolation=cv2.INTER_LINEAR)
    print(f"  combo shape={combo.shape} dtype={combo.dtype} c_contig={combo.flags['C_CONTIGUOUS']}")

    rgba = cv2.cvtColor(src_bgr, cv2.COLOR_BGR2BGRA)
    rgba[:, :, 3] = combo
    cv2.imwrite(str(OUTDIR / "mask.png"), combo)
    cv2.imwrite(str(OUTDIR / "tpose_clean.png"), rgba)
    print(f"ok tpose_clean.png + mask.png")

    # 4) overlay debug com os keypoints desenhados (pra inspecao visual)
    dbg = src_bgr.copy()
    show = ["nose","L_shoulder","R_shoulder","L_elbow","R_elbow","L_wrist","R_wrist",
            "L_hip","R_hip","L_knee","R_knee","L_ankle","R_ankle","_neck","_pelvis","_spine_mid"]
    for name in show:
        p = kp[name]
        cv2.circle(dbg, (p["x"], p["y"]), 6, (0,0,255), -1)
        cv2.putText(dbg, name, (p["x"]+8, p["y"]-6),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.4, (0,0,255), 1, cv2.LINE_AA)
    cv2.imwrite(str(OUTDIR / "keypoints_debug.png"), dbg)
    print(f"ok keypoints_debug.png")
    return 0


if __name__ == "__main__":
    sys.exit(main())
