# Migrating to TFLite Pose Classifier

This guide helps you migrate from the JSON-based pose classifier to the new TFLite model for better accuracy and performance.

## Key Changes

| Feature | JSON Classifier | TFLite Classifier |
|---------|----------------|-------------------|
| **Accuracy** | Medium (Euclidean distance) | High (trained ML model) |
| **Performance** | Fast | Very fast (~5ms inference) |
| **Model Size** | Tiny (JSON) | ~500 KB (TFLite) |
| **Training** | Manual JSON editing | Python training script |
| **Pose Features** | 2D landmarks | 3D landmarks + bone vectors |

## Migration Steps

### 1. Train the Model
Follow the `ML_SETUP_GUIDE.md` to:
1. Organize training data in `data/bersedia/` and `data/berlari/`
2. Run `python train_pose_classifier.py`
3. Copy the exported files to Flutter assets:
   ```bash
   mkdir -p assets/models
   cp pose_classifier.tflite assets/models/
   cp pose_labels.json assets/models/
   ```

### 2. Update pubspec.yaml
Ensure these dependencies are present:
```yaml
dependencies:
  tflite_flutter: ^0.10.4

flutter:
  assets:
    - assets/models/pose_classifier.tflite
    - assets/models/pose_labels.json
```

### 3. Replace PoseClassifier
Replace `lib/services/pose/pose_classifier.dart` with the new TFLite-based implementation.

### 4. Update BatchFrameProcessor
Modify `BatchFrameProcessor` to use the new classifier:

```dart
// Before: JSON-based classifier
final classifier = PoseClassifier(referencePoses: referencePoses);

// After: TFLite-based classifier
final classifier = PoseClassifier();
await classifier.initialize(
  modelPath: 'assets/models/pose_classifier.tflite',
  labels: await loadPoseLabels(),
);
```

### 5. Update Frame Processing
Change how pose classification is called:

```dart
// Before: JSON-based
final result = classifier.classifyFromMap(landmarks);

// After: TFLite-based
final features = classifier.extractFeaturesFromPose(pose);
final (label, confidence) = await classifier.predictTop(features);
```

## Integration with Recording Screen

The new classifier integrates seamlessly with the existing recording flow:

1. **Pose Detection**: Still uses `google_mlkit_pose_detection`
2. **Feature Extraction**: Converts landmarks to normalized bone vectors
3. **Inference**: Runs TFLite model on extracted features
4. **Scoring**: Maintains the same scoring system for best frames

## Performance Considerations

- **Model Loading**: Load the model once during app initialization
- **Inference**: Runs on CPU with minimal latency (~5ms)
- **Memory**: ~500 KB model size, minimal runtime memory

## Troubleshooting

**"Model not found"** → Verify asset paths in pubspec.yaml
**"Feature dimension mismatch"** → Ensure training and Flutter code use same feature dimension
**"Low accuracy"** → Collect more training data, verify pose quality

## Next Steps

1. Train with your dataset
2. Test on device
3. Adjust thresholds as needed
4. Monitor performance metrics