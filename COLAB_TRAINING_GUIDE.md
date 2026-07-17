# Training ML Model in Google Colab

## Step 1: Prepare Training Data Locally

Create this folder structure on your computer:
```
training_data/
  ├── bersedia/
  │   ├── img1.jpg
  │   ├── img2.jpg
  │   └── ... (20-30 images of ready/standby pose)
  └── berlari/
      ├── img1.jpg
      ├── img2.jpg
      └── ... (20-30 images of running pose)
```

**Image requirements:**
- Full body visible (head to feet)
- Clear lighting
- JPG or PNG format
- Min 480p resolution
- Varied angles and people

## Step 2: Open Google Colab

1. Go to https://colab.research.google.com
2. Click "New notebook"
3. Copy & paste the code below

## Step 3: Run Training in Colab

```python
# Install dependencies
!pip install -q tensorflow mediapipe opencv-python scikit-learn

# Clone the repo
!git clone https://github.com/your-username/sprintify.git
%cd sprintify

# Upload training data
from google.colab import files
print("Upload your training_data.zip file:")
uploaded = files.upload()

# Extract
!unzip -q training_data.zip

# Run training
!python3 train_pose_classifier.py
```

After training completes (~3-5 min), download these files:
- `pose_classifier.tflite`
- `pose_labels.json`

## Step 4: Integrate into Flutter

```bash
mkdir -p assets/models
cp pose_classifier.tflite assets/models/
cp pose_labels.json assets/models/
flutter pub get
```

Update `pubspec.yaml`:
```yaml
dependencies:
  tflite_flutter: ^0.10.4
flutter:
  assets:
    - assets/models/pose_classifier.tflite
    - assets/models/pose_labels.json
```

Done! The model is ready to use in the app.
