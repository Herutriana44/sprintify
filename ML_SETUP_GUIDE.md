# ML Pose Classifier Setup Guide

## Overview
This guide walks you through training a lightweight pose classification model to distinguish "bersedia" (ready) vs "berlari" (running), then integrating it into your Flutter app.

## Part 1: Python Training Setup

### 1.1 Install Dependencies
```bash
pip install -r requirements.txt
```

### 1.2 Prepare Training Data
Create this folder structure:
```
data/
├── bersedia/
│   ├── image1.jpg
│   ├── image2.jpg
│   └── ...
└── berlari/
    ├── image1.jpg
    ├── image2.jpg
    └── ...
```

**Requirements:**
- Images should show clear full-body poses (head to feet)
- Minimum 20-30 images per class for acceptable accuracy
- Images in JPG/PNG format at reasonable resolution (480p+)

### 1.3 Train the Model
```bash
python train_pose_classifier.py
```

This will:
1. Extract pose landmarks from all images using MediaPipe
2. Normalize features relative to hip position and torso length
3. Train a lightweight 2-layer dense model
4. Export `pose_classifier.tflite` (~500 KB)
5. Save label mapping to `pose_labels.json`

**Expected runtime:** 2-5 minutes depending on dataset size

### 1.4 Verify Output Files
After training, you should have:
- `pose_classifier.tflite` — TFLite model for inference
- `pose_labels.json` — class name mapping
- `pose_classifier_model/` — Keras checkpoint (optional, for re-training)
- `pose_features.npz` — cached extracted features

## Part 2: Flutter Integration

### 2.1 Update pubspec.yaml
Add TFLite support:
```yaml
dependencies:
  tflite_flutter: ^0.10.4
```

Then run:
```bash
flutter pub get
```

### 2.2 Copy Model Files to Assets
```bash
mkdir -p assets/models
cp pose_classifier.tflite assets/models/
cp pose_labels.json assets/models/
```

Update `pubspec.yaml` assets section:
```yaml
flutter:
  assets:
    - assets/models/pose_classifier.tflite
    - assets/models/pose_labels.json
```

### 2.3 Update PoseClassifier Integration
Use the provided `lib/ml/pose_classifier.dart` in your recording flow.

### 2.4 Example Usage in Recording Screen
```dart
// Initialize
final classifier = PoseClassifier();
await classifier.initialize(
  modelPath: 'assets/models/pose_classifier.tflite',
  labels: ['bersedia', 'berlari'],
);

// Extract features from pose landmarks (33 * 3 = 99 coords)
final landmarks = <double>[
  // x1, y1, z1 for landmark 0
  // x2, y2, z2 for landmark 1
  // ... (33 landmarks total)
];

// Run inference
final prediction = await classifier.predictTop(
  classifier.extractFeatures(landmarks),
);
print('${prediction.$1}: ${(prediction.$2 * 100).toStringAsFixed(1)}%');

// Cleanup
classifier.dispose();
```

## Part 3: Model Performance

### What to Expect
- **Inference speed:** <10ms per frame on modern phones
- **Model size:** ~500 KB (fits easily in app bundle)
- **Accuracy:** Depends on training data quality (aim for 85%+ on clean data)

### Improving Accuracy
1. Collect more varied examples (different angles, lighting, body types)
2. Use high-quality video frames (avoid motion blur)
3. Ensure clear, full-body poses in training images
4. Retrain with more epochs if validation accuracy plateaus

## Troubleshooting

**"No pose detected"** → Ensure full body is visible, good lighting, person fills frame

**"Model accuracy is low"** → Collect more training data, check label consistency, retrain

**"TFLite model won't load"** → Verify asset paths in pubspec.yaml, run `flutter clean`

**"Feature dimension mismatch"** → Ensure pose has 33 landmarks; check MediaPipe version compatibility
