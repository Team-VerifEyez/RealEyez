import boto3
import os
from sklearn.model_selection import train_test_split
from tensorflow.keras.preprocessing.image import ImageDataGenerator
from tensorflow.keras.applications import EfficientNetB0
from tensorflow.keras.models import Model
from tensorflow.keras.layers import Dense, GlobalAveragePooling2D, Dropout
from tensorflow.keras.optimizers import Adam

# Function to download a folder from S3 bucket to a local directory
def download_s3_folder(bucket_name, s3_folder, local_dir):
    """
    Downloads a folder from an S3 bucket to a specified local directory.

    Args:
    - bucket_name: Name of the S3 bucket
    - s3_folder: S3 folder path to download
    - local_dir: Local directory where files will be saved
    """
    s3 = boto3.client('s3')  # Initialize the S3 client
    objects = s3.list_objects_v2(Bucket=bucket_name, Prefix=s3_folder)
    
    # Check if there are files in the folder
    if 'Contents' in objects:
        for obj in objects['Contents']:
            s3_file_path = obj['Key']  # Full path of the file in S3
            # Generate the corresponding local file path
            local_file_path = os.path.join(local_dir, os.path.relpath(s3_file_path, s3_folder))
            # Create directories if they don't exist
            os.makedirs(os.path.dirname(local_file_path), exist_ok=True)
            # Download the file
            s3.download_file(bucket_name, s3_file_path, local_file_path)
            print(f"Downloaded: {s3_file_path}")

# Download the train and test datasets
download_s3_folder("cifake-real", "train/", "./train")
download_s3_folder("cifake-real", "test/", "./test")

# Validation Set:

# 20% of 100,000 = 20,000 images:
# 10,000 real
# 10,000 fake

# Training Set:

# Remaining 80% of 100,000 = 80,000 images:
# 40,000 real
# 40,000 fake

# Function to split train dataset into train and validation sets
def split_train_validation(train_dir, validation_dir, validation_split=0.2):
    """
    Splits the training data into separate training and validation datasets.

    Args:
    - train_dir: Directory containing the training data
    - validation_dir: Directory to store the validation data
    - validation_split: Proportion of data to use for validation
    """
    for category in os.listdir(train_dir):  # Assuming subfolders like 'Real' and 'Fake'
        train_category_path = os.path.join(train_dir, category)
        validation_category_path = os.path.join(validation_dir, category)
        os.makedirs(validation_category_path, exist_ok=True)
        
        # Get all files in the category
        all_files = os.listdir(train_category_path)
        train_files, validation_files = train_test_split(
            all_files, test_size=validation_split, random_state=42
        )
        
        # Move validation files to validation directory
        for file_name in validation_files:
            os.rename(
                os.path.join(train_category_path, file_name),
                os.path.join(validation_category_path, file_name)
            )

# Paths for train, validation, and test datasets
train_dir = './train'
validation_dir = './validation'
test_dir = './test'

# Split the train dataset into training and validation datasets
split_train_validation(train_dir, validation_dir)

# Data augmentation and preprocessing for training and validation
train_datagen = ImageDataGenerator(
    rescale=1.0/255,         # Normalize pixel values to [0, 1]
    rotation_range=20,       # Randomly rotate images
    width_shift_range=0.2,   # Randomly shift images horizontally
    height_shift_range=0.2,  # Randomly shift images vertically
    zoom_range=0.2,          # Randomly zoom images
    horizontal_flip=True     # Randomly flip images horizontally
)

validation_datagen = ImageDataGenerator(rescale=1.0/255)  # Only rescaling for validation
test_datagen = ImageDataGenerator(rescale=1.0/255)       # Only rescaling for test

# Create training data generator
train_generator = train_datagen.flow_from_directory(
    train_dir,
    target_size=(224, 224),  # Resize images to fit the model input
    batch_size=32,           # Number of images per batch
    class_mode='binary'      # Binary classification
)

# Create validation data generator
validation_generator = validation_datagen.flow_from_directory(
    validation_dir,
    target_size=(224, 224),  # Resize images to fit the model input
    batch_size=32,           # Number of images per batch
    class_mode='binary'      # Binary classification
)

# Create testing data generator
test_generator = test_datagen.flow_from_directory(
    test_dir,
    target_size=(224, 224),  # Resize images to fit the model input
    batch_size=32,           # Number of images per batch
    class_mode='binary'      # Binary classification
)

# Function to build the model
def build_model():
    """
    Builds and compiles an EfficientNet-based model for binary classification.

    Returns:
    - Compiled model
    """
    # Load the EfficientNetB0 model without the top classification layer
    base_model = EfficientNetB0(weights='imagenet', include_top=False, input_shape=(224, 224, 3))
    base_model.trainable = False  # Freeze the base model layers
    
    # Add custom layers for binary classification
    x = base_model.output
    x = GlobalAveragePooling2D()(x)  # Reduce feature maps to a single vector
    x = Dropout(0.3)(x)              # Add dropout for regularization
    x = Dense(128, activation='relu')(x)  # Fully connected layer with 128 units
    x = Dropout(0.3)(x)              # Add another dropout layer
    predictions = Dense(1, activation='sigmoid')(x)  # Output layer for binary classification
    
    # Define the full model
    model = Model(inputs=base_model.input, outputs=predictions)
    
    # Compile the model with Adam optimizer and binary cross-entropy loss
    model.compile(optimizer=Adam(learning_rate=0.0001),
                  loss='binary_crossentropy',
                  metrics=['accuracy'])
    return model

# Build and summarize the model
model = build_model()
model.summary()

# Train the model (initial training with frozen base model)
history = model.fit(
    train_generator,
    epochs=10,
    validation_data=validation_generator,  # Use validation_generator
    steps_per_epoch=train_generator.samples // train_generator.batch_size,
    validation_steps=validation_generator.samples // validation_generator.batch_size
)

# Unfreeze the base model for fine-tuning
for layer in model.layers:
    layer.trainable = True

# Recompile the model with a lower learning rate for fine-tuning
model.compile(optimizer=Adam(learning_rate=1e-5),
              loss='binary_crossentropy',
              metrics=['accuracy'])

# Fine-tune the model
history_finetune = model.fit(
    train_generator,
    epochs=5,
    validation_data=validation_generator,  # Use validation_generator
    steps_per_epoch=train_generator.samples // train_generator.batch_size,
    validation_steps=validation_generator.samples // validation_generator.batch_size
)

# Evaluate the model on the test dataset
loss, accuracy = model.evaluate(test_generator)
print(f"Test Accuracy: {accuracy:.2f}")

# Save the trained model to a file
model.save('ai_vs_real_model.h5')




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
