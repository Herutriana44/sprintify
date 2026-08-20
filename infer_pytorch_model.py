#!/usr/bin/env python3
"""
Quick inference on trained pose classifier.
Use for testing the exported TFLite model with sample frames.
"""

import numpy as np
import cv2
import mediapipe as mp
import tensorflow as tf

# ── Config ───────────────────────────────────────────────────────────
TFLITE_PATH = "pose_classifier.tflite"
LABEL_PATH = "pose_labels.json"  # generated automatically
TEST_IMAGE = "test_image.jpg"

# ── Load Model & Labels ───────────────────────────────────────────────
def load_tflite_model(tflite_path):
    interpreter = tf.lite.Interpreter(model_path=tflite_path)
    interpreter.allocate_tensors()
    return interpreter

# ── MediaPipe Pose ─────────────────────────────────────────────────────
mp_pose = mp.solutions.pose
pose_detector = mp_pose.Pose(
    static_image_mode=True,
    model_complexity=1,
    min_detection_confidence=0.5,
)

# Connections defining feature-matched "bones"
BONE_CONNECTIONS = [
    (11, 13), (13, 15),        # left arm
    (12, 14), (14, 16),        # right arm
    (11, 12),                  # shoulders
    (11, 23), (12, 24),        # torso sides
    (23, 25), (25, 27),        # left leg
    (24, 26), (26, 28),        # right leg
    (23, 24),                  # hips
]

# Extract features (MUST match training script exactly)
def extract_features(image_path: str) -> np.ndarray:
    img = cv2.imread(image_path)
    img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    h, w = img_rgb.shape[:2]

    results = pose_detector.process(img_rgb)
    if not results.pose_landmarks:
        raise ValueError(f"No pose detected: {image_path}")

    lm = results.pose_landmarks.landmark
    coords = np.array([(p.x, p.y, p.z) for p in lm], dtype=np.float32)

    # Normalize → origin=hip_center, scale=torso_len
    left_hip = coords[23]
    right_hip = coords[24]
    hip_center = (left_hip + right_hip) / 2.0
    coords -= hip_center

    shoulder_center = ((coords[11] + coords[12]) / 2.0)
    torso_len = np.linalg.norm(shoulder_center)
    if torso_len > 1e-6:
        coords /= torso_len

    # Build features, aligned with training
    feats = []
    feats.extend(coords.flatten())           # landmark xyz (99 dim)

    # Bone vectors (repeats goals)
    for start_idx, end_idx in BONE_CONNECTIONS:
        vec = coords[end_idx] - coords[start_idx]
        feats.extend(vec)

    # Bone lengths squared
    for start_idx, end_idx in BONE_CONNECTIONS:
        vec = coords[end_idx] - coords[start_idx]
        feats.append(np.dot(vec, vec))

    return np.array(feats[:147], dtype=np.float32)  # same dimension

# Main demo
if __name__ == "__main__":
    print("Loading TFLite model...")
    interpreter = load_tflite_model(TFLITE_PATH)

    # Demo inference
    print(f"Testing on {TEST_IMAGE}")
    test_feat = extract_features(TEST_IMAGE)
    input_idx = interpreter.get_input_details()[0]['index']
    output_idx = interpreter.get_output_details()[0]['index']

    test_feat = np.expand_dims(test_feat, axis=0)
    interpreter.set_tensor(input_idx, test_feat)
    interpreter.invoke()
    predictions = interpreter.get_tensor(output_idx)[0]

    print("Predictions:")
    for label, prob in zip(["bersedia", "berlari"], predictions):
        print(f"  {label}: {prob:.2%}")