# Image Classification Model Training Script
# This script trains a lightweight model to classify images as 'bersedia' or 'berlari'
# using pose detection features, then exports the model for use in a Flutter project.

import os
import numpy as np
import tensorflow as tf
from tensorflow.keras import layers, models
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder

# Configuration
DATA_DIR = 'data'
MODEL_SAVE_PATH = 'image_classifier_model'
BATCH_SIZE = 32
EPOCHS = 20
IMG_SIZE = (224, 224)

# Load and preprocess data
def load_data(data_dir):
    images = []
    labels = []

    for label in os.listdir(data_dir):
        label_dir = os.path.join(data_dir, label)
        if os.path.isdir(label_dir):
            for img_file in os.listdir(label_dir):
                img_path = os.path.join(label_dir, img_file)
                img = tf.keras.preprocessing.image.load_img(img_path, target_size=IMG_SIZE)
                img_array = tf.keras.preprocessing.image.img_to_array(img)
                images.append(img_array)
                labels.append(label)

    return np.array(images), np.array(labels)

# Main training function
def train_model():
    # Load data
    images, labels = load_data(DATA_DIR)

    # Encode labels
    label_encoder = LabelEncoder()
    encoded_labels = label_encoder.fit_transform(labels)
    num_classes = len(label_encoder.classes_)

    # Split data
    X_train, X_test, y_train, y_test = train_test_split(images, encoded_labels, test_size=0.2, random_state=42)

    # Normalize images
    X_train = X_train / 255.0
    X_test = X_test / 255.0

    # Convert labels to one-hot encoding
    y_train = tf.keras.utils.to_categorical(y_train, num_classes)
    y_test = tf.keras.utils.to_categorical(y_test, num_classes)

    # Create a lightweight model using MobileNetV2 as base
    base_model = tf.keras.applications.MobileNetV2(
        input_shape=(*IMG_SIZE, 3),
        include_top=False,
        weights='imagenet'
    )

    # Freeze the base model
    base_model.trainable = False

    # Create new model on top
    inputs = tf.keras.Input(shape=(*IMG_SIZE, 3))
    x = base_model(inputs, training=False)
    x = layers.GlobalAveragePooling2D()(x)
    x = layers.Dense(128, activation='relu')(x)
    x = layers.Dropout(0.2)(x)
    outputs = layers.Dense(num_classes, activation='softmax')(x)

    model = tf.keras.Model(inputs, outputs)

    # Compile the model
    model.compile(optimizer=tf.keras.optimizers.Adam(learning_rate=0.001),
                  loss='categorical_crossentropy',
                  metrics=['accuracy'])

    # Train the model
    history = model.fit(X_train, y_train, batch_size=BATCH_SIZE, epochs=EPOCHS, validation_data=(X_test, y_test))

    # Save the model
    model.save(MODEL_SAVE_PATH)

    # Save label encoder classes
    np.save(os.path.join(MODEL_SAVE_PATH, 'classes.npy'), label_encoder.classes_)

    return history

# Export model for Flutter
def export_for_flutter():
    # Convert the model to TensorFlow Lite
    converter = tf.lite.TFLiteConverter.from_saved_model(MODEL_SAVE_PATH)
    tflite_model = converter.convert()

    # Save the TFLite model
    with open('image_classifier.tflite', 'wb') as f:
        f.write(tflite_model)

# Main execution
if __name__ == '__main__':
    print("Starting model training...")
    train_model()
    print("Training complete. Exporting model for Flutter...")
    export_for_flutter()
    print("Model exported successfully. You can now use image_classifier.tflite in your Flutter project.")
