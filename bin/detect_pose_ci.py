#!/usr/bin/env python3
"""
CI Pose Detection Script — pengganti detect_pose.dart untuk environment headless.

Memproses semua gambar di folder `dataset/` (atau folder yang diberikan sebagai
argumen), menghasilkan:
  - output/annotated/<nama_file>_annotated.jpg  : gambar dengan landmark tergambar
  - output/vectors/<nama_file>_vector.json      : koordinat landmark (x, y, z, visibility)
  - output/summary.txt                          : ringkasan semua gambar yang diproses

Penggunaan:
  python bin/detect_pose_ci.py [dataset_folder] [output_folder]
  python bin/detect_pose_ci.py dataset output
"""

import sys
import os
import json
import math
from pathlib import Path
from datetime import datetime

try:
    import cv2
    import mediapipe as mp
    import numpy as np
except ImportError as e:
    print(f"[ERROR] Library tidak tersedia: {e}")
    print("Jalankan: pip install mediapipe opencv-python-headless numpy")
    sys.exit(1)

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

LANDMARK_NAMES = [
    "nose", "left_eye_inner", "left_eye", "left_eye_outer",
    "right_eye_inner", "right_eye", "right_eye_outer",
    "left_ear", "right_ear",
    "mouth_left", "mouth_right",
    "left_shoulder", "right_shoulder",
    "left_elbow", "right_elbow",
    "left_wrist", "right_wrist",
    "left_pinky", "right_pinky",
    "left_index", "right_index",
    "left_thumb", "right_thumb",
    "left_hip", "right_hip",
    "left_knee", "right_knee",
    "left_ankle", "right_ankle",
    "left_heel", "right_heel",
    "left_foot_index", "right_foot_index",
]

# Warna per koneksi (BGR)
SKELETON_CONNECTIONS = [
    # Wajah
    (0, 1), (1, 2), (2, 3), (3, 7),
    (0, 4), (4, 5), (5, 6), (6, 8),
    # Bahu
    (11, 12),
    # Lengan kiri
    (11, 13), (13, 15), (15, 17), (15, 19), (15, 21),
    # Lengan kanan
    (12, 14), (14, 16), (16, 18), (16, 20), (16, 22),
    # Torso
    (11, 23), (12, 24), (23, 24),
    # Kaki kiri
    (23, 25), (25, 27), (27, 29), (27, 31),
    # Kaki kanan
    (24, 26), (26, 28), (28, 30), (28, 32),
]

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------

def draw_landmarks_on_image(image: np.ndarray, landmarks) -> np.ndarray:
    """Gambar skeleton dan landmark pada image."""
    annotated = image.copy()
    h, w = annotated.shape[:2]

    # Gambar koneksi skeleton
    for (a, b) in SKELETON_CONNECTIONS:
        lm_a = landmarks.landmark[a]
        lm_b = landmarks.landmark[b]
        if lm_a.visibility < 0.3 or lm_b.visibility < 0.3:
            continue
        pt_a = (int(lm_a.x * w), int(lm_a.y * h))
        pt_b = (int(lm_b.x * w), int(lm_b.y * h))
        cv2.line(annotated, pt_a, pt_b, (0, 255, 0), 2, cv2.LINE_AA)

    # Gambar titik landmark
    for idx, lm in enumerate(landmarks.landmark):
        if lm.visibility < 0.3:
            continue
        cx = int(lm.x * w)
        cy = int(lm.y * h)
        # Lingkaran putih sebagai border
        cv2.circle(annotated, (cx, cy), 6, (255, 255, 255), -1)
        # Titik merah di tengah
        cv2.circle(annotated, (cx, cy), 4, (0, 0, 255), -1)
        # Label nama landmark (hanya landmark utama agar tidak terlalu padat)
        if idx < len(LANDMARK_NAMES) and idx in {0, 11, 12, 23, 24, 25, 26, 27, 28}:
            label = LANDMARK_NAMES[idx].replace("_", " ")
            cv2.putText(
                annotated, label, (cx + 7, cy - 4),
                cv2.FONT_HERSHEY_SIMPLEX, 0.35, (255, 255, 0), 1, cv2.LINE_AA
            )

    return annotated


def landmarks_to_dict(landmarks, image_w: int, image_h: int) -> dict:
    """Konversi landmark ke dict dengan koordinat pixel dan normalized."""
    result = {}
    for idx, lm in enumerate(landmarks.landmark):
        name = LANDMARK_NAMES[idx] if idx < len(LANDMARK_NAMES) else f"landmark_{idx}"
        result[name] = {
            # Koordinat normalized (0.0 - 1.0) — sama dengan output ML Kit
            "x": round(lm.x, 6),
            "y": round(lm.y, 6),
            "z": round(lm.z, 6),
            "visibility": round(lm.visibility, 6),
            # Koordinat pixel
            "px": int(lm.x * image_w),
            "py": int(lm.y * image_h),
        }
    return result


def format_vector_text(landmarks_dict: dict) -> str:
    """Format teks mirip output detect_pose.dart."""
    lines = ["--- Detected Pose Landmarks ---"]
    for name, vals in landmarks_dict.items():
        lines.append(
            f"{name}: "
            f"x={vals['x']:.2f}, "
            f"y={vals['y']:.2f}, "
            f"z={vals['z']:.2f}, "
            f"visibility={vals['visibility']:.2f}"
        )
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Main processing
# ---------------------------------------------------------------------------

def process_image(
    image_path: Path,
    dataset_root: Path,
    out_annotated_dir: Path,
    out_vectors_dir: Path,
    pose_detector,
) -> dict:
    """
    Proses satu gambar. Kembalikan dict status.
    Struktur subfolder dataset dipertahankan di output.
    """
    # Pertahankan path relatif terhadap dataset root
    # Contoh: dataset/berlari/running_001.jpg → berlari/running_001
    try:
        rel = image_path.relative_to(dataset_root)
    except ValueError:
        rel = Path(image_path.name)

    stem = rel.with_suffix("").as_posix().replace("/", "__")  # berlari__running_001
    result = {"file": str(rel), "status": "ok", "landmarks": 0}

    # Baca gambar
    image_bgr = cv2.imread(str(image_path))
    if image_bgr is None:
        result["status"] = "error_read"
        return result

    h, w = image_bgr.shape[:2]
    image_rgb = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2RGB)

    # Deteksi pose
    detection = pose_detector.process(image_rgb)

    if not detection.pose_landmarks:
        # Simpan gambar tanpa anotasi dengan label "no pose"
        annotated = image_bgr.copy()
        cv2.putText(
            annotated, "No pose detected", (10, 30),
            cv2.FONT_HERSHEY_SIMPLEX, 1.0, (0, 0, 255), 2, cv2.LINE_AA
        )
        out_path = out_annotated_dir / f"{stem}_annotated.jpg"
        cv2.imwrite(str(out_path), annotated)
        result["status"] = "no_pose"
        return result

    # Gambar landmark
    annotated = draw_landmarks_on_image(image_bgr, detection.pose_landmarks)

    # Tambahkan info file di pojok kiri atas
    label_text = str(rel)
    cv2.putText(
        annotated, label_text, (8, 22),
        cv2.FONT_HERSHEY_SIMPLEX, 0.55, (255, 255, 255), 2, cv2.LINE_AA
    )
    cv2.putText(
        annotated, label_text, (8, 22),
        cv2.FONT_HERSHEY_SIMPLEX, 0.55, (0, 0, 0), 1, cv2.LINE_AA
    )

    # Simpan annotated image
    out_img_path = out_annotated_dir / f"{stem}_annotated.jpg"
    cv2.imwrite(str(out_img_path), annotated, [cv2.IMWRITE_JPEG_QUALITY, 95])

    # Konversi landmark ke dict
    lm_dict = landmarks_to_dict(detection.pose_landmarks, w, h)

    # Simpan JSON vector
    out_json_path = out_vectors_dir / f"{stem}_vector.json"
    with open(str(out_json_path), "w") as f:
        json.dump({
            "source_image": str(rel),
            "image_size": {"width": w, "height": h},
            "detected_at": datetime.utcnow().isoformat() + "Z",
            "landmarks": lm_dict,
        }, f, indent=2)

    # Simpan teks vector (format mirip detect_pose.dart)
    out_txt_path = out_vectors_dir / f"{stem}_vector.txt"
    with open(str(out_txt_path), "w") as f:
        f.write(format_vector_text(lm_dict))
        f.write(f"\n\nSource: {rel}\n")
        f.write(f"Size: {w}x{h}\n")

    result["landmarks"] = len(lm_dict)
    return result


def main():
    dataset_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("dataset")
    output_dir  = Path(sys.argv[2]) if len(sys.argv) > 2 else Path("output")

    if not dataset_dir.exists():
        print(f"[ERROR] Dataset folder tidak ditemukan: {dataset_dir}")
        sys.exit(1)

    # Kumpulkan semua file gambar
    extensions = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}
    images = sorted([
        p for p in dataset_dir.rglob("*")
        if p.suffix.lower() in extensions
    ])

    if not images:
        print(f"[WARN] Tidak ada gambar di folder: {dataset_dir}")
        sys.exit(0)

    print(f"[INFO] Ditemukan {len(images)} gambar di {dataset_dir}")

    # Buat folder output
    out_annotated = output_dir / "annotated"
    out_vectors   = output_dir / "vectors"
    out_annotated.mkdir(parents=True, exist_ok=True)
    out_vectors.mkdir(parents=True, exist_ok=True)

    # Inisialisasi MediaPipe Pose (sekali, reuse untuk semua gambar)
    mp_pose = mp.solutions.pose
    pose = mp_pose.Pose(
        static_image_mode=True,
        model_complexity=2,        # 0=lite, 1=full, 2=heavy (paling akurat)
        enable_segmentation=False,
        min_detection_confidence=0.5,
    )

    results = []
    ok_count = 0
    no_pose_count = 0
    error_count = 0

    for i, img_path in enumerate(images, 1):
        print(f"[{i:3d}/{len(images)}] Processing: {img_path.relative_to(dataset_dir)} ...", end=" ", flush=True)
        r = process_image(img_path, dataset_dir, out_annotated, out_vectors, pose)
        results.append(r)

        if r["status"] == "ok":
            ok_count += 1
            print(f"OK ({r['landmarks']} landmarks)")
        elif r["status"] == "no_pose":
            no_pose_count += 1
            print("No pose detected")
        else:
            error_count += 1
            print(f"ERROR ({r['status']})")

    pose.close()

    # Tulis summary
    summary_path = output_dir / "summary.txt"
    with open(str(summary_path), "w") as f:
        f.write(f"Pose Detection Summary\n")
        f.write(f"======================\n")
        f.write(f"Run at   : {datetime.utcnow().isoformat()}Z\n")
        f.write(f"Dataset  : {dataset_dir.resolve()}\n")
        f.write(f"Total    : {len(images)}\n")
        f.write(f"OK       : {ok_count}\n")
        f.write(f"No pose  : {no_pose_count}\n")
        f.write(f"Error    : {error_count}\n")
        f.write(f"\nPer-file results:\n")
        f.write(f"-----------------\n")
        for r in results:
            status_str = f"OK ({r['landmarks']} landmarks)" if r["status"] == "ok" else r["status"].upper()
            f.write(f"  {r['file']:<40} {status_str}\n")

    print(f"\n[DONE] OK={ok_count} | No pose={no_pose_count} | Error={error_count}")
    print(f"[DONE] Annotated images : {out_annotated}")
    print(f"[DONE] Vector files     : {out_vectors}")
    print(f"[DONE] Summary          : {summary_path}")

    # Exit code non-zero hanya jika semua gambar gagal
    if error_count == len(images):
        sys.exit(1)


if __name__ == "__main__":
    main()
