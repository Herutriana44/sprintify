#!/usr/bin/env python3
"""
Train a lightweight pose classifier for "bersedia" (ready) vs "berlari" (running).
Uses MediaPipe Pose landmarks → bone feature vectors → small dense model.
Exports to TFLite for Flutter integration.
"""

import os
import json
import numpy as np
import cv2
import mediapipe as mp
import tensorflow as tf
from tensorflow.keras import layers, models
from sklearn.model_selection import train_test_split

# ── Config ───────────────────────────────────────────────────────────────────
DATA_DIR = "data"                      # data/bersedia/*.jpg, data/berlari/*.jpg
FEATURES_PATH = "pose_features.npz"    # cached extracted features
MODEL_SAVE_DIR = "pose_classifier_model"
TFLITE_PATH = "pose_classifier.tflite"
LABELS_PATH = "pose_labels.json"

EPOCHS = 80
BATCH_SIZE = 32

# ── MediaPipe Pose ───────────────────────────────────────────────────────────
mp_pose = mp.solutions.pose
pose_detector = mp_pose.Pose(
    static_image_mode=True,
    model_complexity=1,
    min_detection_confidence=0.5,
)

# Connections that define "bones" (same as MediaPipe pose_connections)
BONE_CONNECTIONS = [
    (11, 13), (13, 15),        # left arm
    (12, 14), (14, 16),        # right arm
    (11, 12),                  # shoulders
    (11, 23), (12, 24),        # torso sides
    (23, 25), (25, 27),        # left leg
    (24, 26), (26, 28),        # right leg
    (23, 24),                  # hips
]


def extract_features(image_path: str) -> np.ndarray | None:
    """
    Extract normalized bone-vector features from a single image.
    Returns a flat vector or None if no pose detected.
    """
    img = cv2.imread(image_path)
    if img is None:
        return None
    img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    h, w = img_rgb.shape[:2]

    results = pose_detector.process(img_rgb)
    if not results.pose_landmarks:
        return None

    lm = results.pose_landmarks.landmark

    # 1. Get key landmarks (33 total in MediaPipe)
    coords = np.array([(p.x, p.y, p.z) for p in lm], dtype=np.float32)

    # 2. Normalize: translate so hip center is origin, scale by torso length
    left_hip = coords[23]
    right_hip = coords[24]
    left_shoulder = coords[11]
    right_shoulder = coords[12]

    hip_center = (left_hip + right_hip) / 2.0
    coords -= hip_center  # translate

    torso_len = np.linalg.norm((left_shoulder + right_shoulder) / 2.0 - hip_center)
    if torso_len > 1e-6:
        coords /= torso_len  # scale-invariant

    # 3. Build bone vectors + raw normalized coords as features
    features = []

    # Each landmark (x, y, z) — 33 * 3 = 99 dims
    features.extend(coords.flatten())

    # Bone vectors for each connection — gives relative geometry explicitly
    for start_idx, end_idx in BONE_CONNECTIONS:
        vec = coords[end_idx] - coords[start_idx]
        features.extend(vec)

    # Bone lengths squared (compact pose descriptor)
    for start_idx, end_idx in BONE_CONNECTIONS:
        vec = coords[end_idx] - coords[start_idx]
        features.append(np.dot(vec, vec))

    return np.array(features, dtype=np.float32)


def build_dataset(data_dir: str):
    """
    Walk data_dir/label/*.jpg, extract features, return X, y, label_map.
    """
    X, y = [], []
    labels = sorted(d for d in os.listdir(data_dir) if os.path.isdir(os.path.join(data_dir, d)))
    label_map = {name: idx for idx, name in enumerate(labels)}

    for label_name in labels:
        label_dir = os.path.join(data_dir, label_name)
        print(f"Processing '{label_name}' ...")
        for fname in os.listdir(label_dir):
            if not fname.lower().endswith((".jpg", ".jpeg", ".png")):
                continue
            fpath = os.path.join(label_dir, fname)
            feat = extract_features(fpath)
            if feat is not None:
                X.append(feat)
                y.append(label_map[label_name])
            else:
                print(f"  ⚠ no pose: {fname}")

    return np.array(X, dtype=np.float32), np.array(y, dtype=np.int32), label_map


def get_or_build_dataset(data_dir: str, cache_path: str):
    """Use cached .npz if available, else extract and cache."""
    if os.path.exists(cache_path):
        print(f"Loading cached features from {cache_path}")
        data = np.load(cache_path)
        return data["X"], data["y"], json.loads(data["label_map"].item())

    X, y, label_map = build_dataset(data_dir)
    np.savez(cache_path, X=X, y=y, label_map=json.dumps(label_map))
    print(f"Cached features to {cache_path}")
    return X, y, label_map


def build_tiny_model(input_dim: int, num_classes: int) -> tf.keras.Model:
    """
    Tiny dense model — very fast, tiny footprint, perfect for mobile/Flutter.
    """
    inputs = layers.Input(shape=(input_dim,), name="pose_features")
    x = layers.Dense(64, activation="relu")(inputs)
    x = layers.BatchNormalization()(x)
    x = layers.Dropout(0.3)(x)
    x = layers.Dense(32, activation="relu")(x)
    x = layers.BatchNormalization()(x)
    x = layers.Dropout(0.2)(x)
    outputs = layers.Dense(num_classes, activation="softmax", name="predictions")(x)

    model = models.Model(inputs, outputs)
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=0.001),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )
    return model


def export_tflite(keras_model, tflite_path: str):
    """Convert Keras model to quantized TFLite for minimal size + fast inference."""
    converter = tf.lite.TFLiteConverter.from_keras_model(keras_model)

    # Quantize to int8 for tiny model size & fast CPU inference on mobile
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.target_spec.supported_types = [tf.float16]

    tflite_model = converter.convert()

    with open(tflite_path, "wb") as f:
        f.write(tflite_model)

    size_kb = len(tflite_model) / 1024
    print(f"TFLite model saved: {tflite_path} ({size_kb:.1f} KB)")


def main():
    # ── 1. Prepare data ──────────────────────────────────────────────────────
    if not os.path.isdir(DATA_DIR):
        raise FileNotFoundError(
            f"Data dir '{DATA_DIR}' not found. "
            "Create it like: data/bersedia/*.jpg and data/berlari/*.jpg"
        )

    X, y, label_map = get_or_build_dataset(DATA_DIR, FEATURES_PATH)
    print(f"Dataset: {X.shape[0]} samples, {X.shape[1]} features")
    print(f"Labels: {label_map}")

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )

    # ── 2. Train ─────────────────────────────────────────────────────────────
    model = build_tiny_model(input_dim=X.shape[1], num_classes=len(label_map))
    model.summary()

    early_stop = tf.keras.callbacks.EarlyStopping(
        monitor="val_accuracy", patience=15, restore_best_weights=True
    )

    history = model.fit(
        X_train, y_train,
        validation_data=(X_test, y_test),
        epochs=EPOCHS,
        batch_size=BATCH_SIZE,
        callbacks=[early_stop],
        verbose=2,
    )

    loss, acc = model.evaluate(X_test, y_test, verbose=0)
    print(f"\nTest accuracy: {acc:.4f}")

    # ── 3. Save ──────────────────────────────────────────────────────────────
    os.makedirs(MODEL_SAVE_DIR, exist_ok=True)
    model.save(os.path.join(MODEL_SAVE_DIR, "model.keras"))
    print(f"Keras model saved to {MODEL_SAVE_DIR}")

    export_tflite(model, TFLITE_PATH)

    with open(LABELS_PATH, "w") as f:
        json.dump(label_map, f)
    print(f"Label map saved to {LABELS_PATH}")

    # ── 4. Show inference example ────────────────────────────────────────────
    sample = X_test[:1]
    pred = model.predict(sample, verbose=0)
    print(f"Sample prediction: {pred[0]} → class {np.argmax(pred[0])}")


if __name__ == "__main__":
    main()
