
import os

def count_images_in_directory(directory_path):
    """
    Counts the number of images in a given directory and its subdirectories.

    Args:
    - directory_path: Path to the directory to count images.

    Returns:
    - A dictionary with category names as keys and image counts as values.
    """
    image_counts = {}
    for category in os.listdir(directory_path):
        category_path = os.path.join(directory_path, category)
        if os.path.isdir(category_path):
            image_counts[category] = len([
                f for f in os.listdir(category_path)
                if os.path.isfile(os.path.join(category_path, f))
            ])
    return image_counts

# Directories to verify
train_dir = '/content/datasets/FACE_DATASET/train'
validation_dir = '/content/datasets/FACE_DATASET/valid'
test_dir = '/content/datasets/FACE_DATASET/test'

# Count images in each directory
print("Image counts in Train Directory:")
print(count_images_in_directory(train_dir))

print("\nImage counts in Validation Directory:")
print(count_images_in_directory(validation_dir))

print("\nImage counts in Test Directory:")
print(count_images_in_directory(test_dir))

import math
from tensorflow.keras.preprocessing.image import ImageDataGenerator
import tensorflow as tf

# ImageDataGenerator setup
image_gen = ImageDataGenerator(rescale=1.0 / 255.0)

batch_size = 32


# Full generators
train_gen = image_gen.flow_from_directory(
    '/content/datasets/FACE_DATASET/train',
    target_size=(224, 224),
    batch_size=batch_size,
    class_mode="binary",
    shuffle=True,
)
valid_gen = image_gen.flow_from_directory(
    '/content/datasets/FACE_DATASET/valid',
    target_size=(224, 224),
    batch_size=batch_size,
    class_mode="binary",
    shuffle=True,
)
test_gen = image_gen.flow_from_directory(
    '/content/datasets/FACE_DATASET/test',
    target_size=(224, 224),
    batch_size=batch_size,
    class_mode="binary",
    shuffle=False,
)

# Convert generators to tf.data.Dataset
AUTOTUNE = tf.data.AUTOTUNE
train_flow = tf.data.Dataset.from_generator(
    lambda: train_gen,
    output_signature=(
        tf.TensorSpec(shape=(None, 224, 224, 3), dtype=tf.float32),
        tf.TensorSpec(shape=(None,), dtype=tf.float32),
    )
).repeat().prefetch(AUTOTUNE)

valid_flow = tf.data.Dataset.from_generator(
    lambda: valid_gen,
    output_signature=(
        tf.TensorSpec(shape=(None, 224, 224, 3), dtype=tf.float32),
        tf.TensorSpec(shape=(None,), dtype=tf.float32),
    )
).repeat().prefetch(AUTOTUNE)



import math

from tensorflow.keras.applications import EfficientNetB0
from tensorflow.keras.models import Model
from tensorflow.keras.layers import (Conv2D, BatchNormalization, Activation, MaxPooling2D, GlobalAveragePooling2D,
                          Dense, Flatten, Dropout)
from tensorflow.keras.callbacks import ModelCheckpoint, EarlyStopping, ReduceLROnPlateau, CSVLogger
from tensorflow.keras.models import Sequential
from tensorflow.keras.optimizers import Adam


from tensorflow.keras.regularizers import l2
from tensorflow.keras.metrics import AUC

def build_model(pretrained):
    model = Sequential([
        pretrained,
        GlobalAveragePooling2D(),
        Dense(512, activation='relu'),
        BatchNormalization(),
        Dropout(0.2),
        Dense(1, activation='sigmoid')
    ])

    model.compile(
        loss='binary_crossentropy',
        optimizer = Adam(learning_rate = 0.001),
        metrics=['accuracy']
    )

    return model

checkpoint = ModelCheckpoint(filepath='best_model.keras',
                             save_best_only=True,
                             verbose=1,
                             mode='min',
                             monitor='val_loss'
                            )
reduce_lr = ReduceLROnPlateau(monitor='val_loss',
                              factor=0.2,
                              patience=3,
                              verbose=1,
                              min_delta=0.0001
                             )
csv_logger = CSVLogger('training.log')

callbacks = [checkpoint, reduce_lr, csv_logger]

base_model = EfficientNetB0(weights='imagenet', include_top=False, input_shape=(224, 224, 3))
model = build_model(base_model)
model.summary()

# Define steps for training
steps_per_epoch = math.ceil(train_gen.samples / batch_size)
validation_steps = math.ceil(valid_gen.samples / batch_size)

# Training
history = model.fit(
    train_flow,  # TensorFlow dataset for training
    epochs=10,
    callbacks=callbacks,
    steps_per_epoch=steps_per_epoch,
    validation_data=valid_flow,  # TensorFlow dataset for validation
    validation_steps=validation_steps,
)

_, accu = model.evaluate(test_gen)
print('Final Test Acccuracy = {:.3f}'.format(accu*100))

import os
import numpy as np
import tensorflow as tf
from tensorflow.keras.preprocessing.image import load_img, img_to_array
from tensorflow.keras.models import load_model
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.metrics import confusion_matrix, classification_report

def test_model(model_path, test_dir):
    """
    Comprehensively test the model on all images in the test directory

    Parameters:
    - model_path: Path to the saved .h5 model file
    - test_dir: Path to the test directory with FAKE and REAL subdirectories
    """
    # Load the trained model
    model = load_model(model_path)

    # Prepare lists to store true labels and predictions
    true_labels = []
    predicted_labels = []
    image_paths = []

    # Image preprocessing parameters
    img_height, img_width = 224, 224

    # Loop through each class (FAKE and REAL)
    for class_name in ['FAKE', 'REAL']:
        class_dir = os.path.join(test_dir, class_name)
        class_label = 0 if class_name == 'FAKE' else 1

        # Loop through all images in the class directory
        for img_name in os.listdir(class_dir):
            img_path = os.path.join(class_dir, img_name)

            # Load and preprocess the image
            img = load_img(img_path, target_size=(img_height, img_width))
            img_array = img_to_array(img)
            img_array = img_array / 255.0  # Normalize pixel values
            img_array = np.expand_dims(img_array, axis=0)

            # Predict
            prediction = model.predict(img_array)
            print(f"Image: {img_path}, Prediction: {prediction}")
            predicted_label = 1 if prediction >= 0.5 else 0

            # Store results
            true_labels.append(class_label)
            predicted_labels.append(predicted_label)
            image_paths.append(img_path)

    # Convert to numpy arrays
    true_labels = np.array(true_labels)
    predicted_labels = np.array(predicted_labels)

    # Generate detailed metrics
    print("Classification Report:")
    print(classification_report(true_labels, predicted_labels,
                                target_names=['FAKE', 'REAL']))

    # Confusion Matrix
    cm = confusion_matrix(true_labels, predicted_labels)
    plt.figure(figsize=(10, 7))
    sns.heatmap(cm, annot=True, fmt='d', cmap='Blues',
                xticklabels=['FAKE', 'REAL'],
                yticklabels=['FAKE', 'REAL'])
    plt.title('Confusion Matrix')
    plt.xlabel('Predicted Label')
    plt.ylabel('True Label')
    plt.tight_layout()
    plt.show()

# Usage example
test_model(
    model_path='detection/models/real_vs_fake_classifier.h5',
    test_dir='/content/datasets/FACE_DATASET/test'
)
