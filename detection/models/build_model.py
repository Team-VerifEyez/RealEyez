import os
import math

import tensorflow as tf
import numpy as np
from tensorflow.keras.preprocessing.image import ImageDataGenerator
from tensorflow.keras.applications import EfficientNetB0
from tensorflow.keras.models import Model
from tensorflow.keras.layers import Dense, GlobalAveragePooling2D, Dropout, GaussianNoise
from tensorflow.keras.optimizers import Adam
from tensorflow.keras.callbacks import ModelCheckpoint, EarlyStopping, ReduceLROnPlateau
from tensorflow.keras.regularizers import l2
from tensorflow.keras.metrics import AUC
from sklearn.model_selection import train_test_split

# Function to download a folder from S3 bucket to a local directory
# def download_s3_folder(bucket_name, s3_folder, local_dir):
#     """
#     Downloads a folder from an S3 bucket to a specified local directory.

#     Args:
#     - bucket_name: Name of the S3 bucket
#     - s3_folder: S3 folder path to download
#     - local_dir: Local directory where files will be saved
#     """
#     s3 = boto3.client('s3')  # Initialize the S3 client
#     objects = s3.list_objects_v2(Bucket=bucket_name, Prefix=s3_folder)
    
#     # Check if there are files in the folder
#     if 'Contents' in objects:
#         for obj in objects['Contents']:
#             s3_file_path = obj['Key']  # Full path of the file in S3
#             # Generate the corresponding local file path
#             local_file_path = os.path.join(local_dir, os.path.relpath(s3_file_path, s3_folder))
#             # Create directories if they don't exist
#             os.makedirs(os.path.dirname(local_file_path), exist_ok=True)
#             # Download the file
#             s3.download_file(bucket_name, s3_file_path, local_file_path)
#             print(f"Downloaded: {s3_file_path}")

# # Download the train and test datasets
# download_s3_folder("cifake-real", "train/", "./train")
# download_s3_folder("cifake-real", "test/", "./test")

# Validation Set:

# 20% of 100,000 = 20,000 images:
# 10,000 real
# 10,000 fake

# Training Set:

# Remaining 80% of 100,000 = 80,000 images:
# 40,000 real
# 40,000 fake

# Function to split train dataset into train and validation sets

# Define paths
train_dir = '/content/datasets/cifake-real/train'
validation_dir = '/content/datasets/cifake-real/validation'

# Define split train/validation function
def split_train_validation(train_dir, validation_dir, validation_split=0.2):
    """
    Splits the training dataset into training and validation datasets.

    Args:
    - train_dir: Path to the training dataset.
    - validation_dir: Path to save the validation dataset.
    - validation_split: Proportion of data to use for validation (default=0.2).
    """
    if not os.path.exists(train_dir):
        raise FileNotFoundError(f"Training directory {train_dir} does not exist!")

    os.makedirs(validation_dir, exist_ok=True)  # Ensure validation directory exists

    for category in os.listdir(train_dir):
        train_category_path = os.path.join(train_dir, category)
        validation_category_path = os.path.join(validation_dir, category)

        # Process only directories
        if not os.path.isdir(train_category_path):
            print(f"Skipping non-directory item: {train_category_path}")
            continue

        os.makedirs(validation_category_path, exist_ok=True)  # Create validation category directory

        # Get all files in the current category
        all_files = [f for f in os.listdir(train_category_path) if os.path.isfile(os.path.join(train_category_path, f))]

        if not all_files:
            print(f"No files found in category {category}. Skipping.")
            continue

        # Split the files into training and validation sets
        train_files, validation_files = train_test_split(
            all_files, test_size=validation_split, random_state=42
        )

        # Move validation files
        for file_name in validation_files:
            src_path = os.path.join(train_category_path, file_name)
            dest_path = os.path.join(validation_category_path, file_name)
            try:
                os.rename(src_path, dest_path)
                print(f"Moved: {src_path} -> {dest_path}")
            except Exception as e:
                print(f"Error moving file {src_path} to {dest_path}: {e}")

    print("Train/Validation split completed.")

# Create validation directory and split data
split_train_validation(train_dir, validation_dir)

# Data Generators
train_datagen = ImageDataGenerator(
    rescale=1.0/255,
    rotation_range=30,
    width_shift_range=0.3,
    height_shift_range=0.3,
    zoom_range=0.3,
    shear_range=0.2,
    horizontal_flip=True,
    brightness_range=[0.8, 1.2]  # Add brightness adjustments
)

validation_datagen = ImageDataGenerator(rescale=1.0/255)
test_datagen = ImageDataGenerator(rescale=1.0/255)

batch_size = 64

train_generator = train_datagen.flow_from_directory(
    './datasets/train',
    target_size=(224, 224),
    batch_size=batch_size,
    class_mode='binary',
    shuffle=True
)

validation_generator = validation_datagen.flow_from_directory(
    './datasets/validation',
    target_size=(224, 224),
    batch_size=batch_size,
    class_mode='binary',
    shuffle=False
)

test_generator = test_datagen.flow_from_directory(
    './datasets/test',
    target_size=(224, 224),
    batch_size=batch_size,
    class_mode='binary',
    shuffle=False
)

# Convert generators to tf.data.Dataset
AUTOTUNE = tf.data.AUTOTUNE
train_dataset = tf.data.Dataset.from_generator(
    lambda: train_generator,
    output_signature=(
        tf.TensorSpec(shape=(None, 224, 224, 3), dtype=tf.float32),
        tf.TensorSpec(shape=(None,), dtype=tf.float32),
    )
).repeat().prefetch(AUTOTUNE)

validation_dataset = tf.data.Dataset.from_generator(
    lambda: validation_generator,
    output_signature=(
        tf.TensorSpec(shape=(None, 224, 224, 3), dtype=tf.float32),
        tf.TensorSpec(shape=(None,), dtype=tf.float32),
    )
).repeat().prefetch(AUTOTUNE)

# Model Building Function
def build_model():
    base_model = EfficientNetB0(weights='imagenet', include_top=False, input_shape=(224, 224, 3))
    base_model.trainable = False

    x = GaussianNoise(0.1)(base_model.output)  # Add Gaussian noise for robustness
    x = GlobalAveragePooling2D()(x)
    x = Dropout(0.5)(x)  # Increase dropout rate
    x = Dense(128, activation='relu', kernel_regularizer=l2(0.01))(x)  # Add L2 regularization
    x = Dropout(0.5)(x)
    predictions = Dense(1, activation='sigmoid')(x)  # Binary classification

    model = Model(inputs=base_model.input, outputs=predictions)
    model.compile(
        optimizer=Adam(learning_rate=0.0001),
        loss='binary_crossentropy',
        metrics=['accuracy', AUC(name='auc'), tf.keras.metrics.Precision(), tf.keras.metrics.Recall()]
    )
    return model

# Build the model
model = build_model()

# Define steps for training
steps_per_epoch = math.ceil(train_generator.samples / train_generator.batch_size)
validation_steps = math.ceil(validation_generator.samples / validation_generator.batch_size)

# Callbacks
checkpoint = ModelCheckpoint(
    filepath='best_model.keras',
    monitor='val_loss',
    save_best_only=True,
    verbose=1
)

early_stopping = EarlyStopping(
    monitor='val_loss',
    patience=3,
    verbose=1
)

lr_scheduler = ReduceLROnPlateau(monitor='val_loss', factor=0.5, patience=2, verbose=1)

# Training
history = model.fit(
    train_dataset,
    epochs=10,
    validation_data=validation_dataset,
    steps_per_epoch=steps_per_epoch,
    validation_steps=validation_steps,
    callbacks=[checkpoint, early_stopping, lr_scheduler]
)

# Unfreeze for fine-tuning
for layer in model.layers:
    layer.trainable = True

# Recompile with a lower learning rate for fine-tuning
model.compile(optimizer=Adam(learning_rate=1e-5), loss='binary_crossentropy', metrics=['accuracy'])

# Fine-tuning
history_finetune = model.fit(
    train_dataset,
    epochs=5,
    validation_data=validation_dataset,
    steps_per_epoch=steps_per_epoch,
    validation_steps=validation_steps,
    callbacks=[checkpoint, early_stopping, lr_scheduler]
)

# Evaluate the model
loss, accuracy = model.evaluate(test_generator)
print(f"Test Accuracy: {accuracy:.2f}")

# Evaluate confidence in predictions
predictions = model.predict(test_generator)
confidence_scores = predictions.flatten()
print(f"Confidence Analysis: Min={confidence_scores.min()}, Max={confidence_scores.max()}, Mean={confidence_scores.mean()}")

# Calibration Metric: Expected Calibration Error (ECE)
def expected_calibration_error(confidences, labels, bins=10):
    bin_edges = np.linspace(0, 1, bins + 1)
    ece = 0.0
    for i in range(bins):
        bin_mask = (confidences > bin_edges[i]) & (confidences <= bin_edges[i + 1])
        bin_acc = labels[bin_mask].mean() if bin_mask.any() else 0
        bin_conf = confidences[bin_mask].mean() if bin_mask.any() else 0
        ece += bin_mask.mean() * np.abs(bin_acc - bin_conf)
    return ece

ece = expected_calibration_error(confidence_scores, test_generator.labels)
print(f"Expected Calibration Error (ECE): {ece:.4f}")



# The model outputs a single value (prediction), where:
# Label 1 (Real): Represents real images.
# Label 0 (Fake): Represents AI-generated (fake) images.
# Values > 0.5 correspond to the "Real" class (label 1).
# Values ≤ 0.5 correspond to the "Fake" class (label 0).

# def predict_image(img_path, model_path):
#     from tensorflow.keras.preprocessing import image
#     import numpy as np
#     from tensorflow.keras.models import load_model

#     # Load model
#     model = load_model(model_path)

#     # Load and preprocess image
#     img = image.load_img(img_path, target_size=(224, 224))
#     img_array = image.img_to_array(img) / 255.0
#     img_array = np.expand_dims(img_array, axis=0)

#     # Make prediction
#     prediction = model.predict(img_array)[0][0]
#     if prediction > 0.5:
#         return "Real", prediction
#     else:
#         return "Fake", prediction

# # Example usage
# result, confidence = predict_image('./test/Fake/example.jpg', 'ai_vs_real_model.h5')
# print(f"Prediction: {result}, Confidence: {confidence:.2f}")



