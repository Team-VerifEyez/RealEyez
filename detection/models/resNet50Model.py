import os
import math
import tensorflow as tf
import numpy as np
from tensorflow.keras.models import Model
from tensorflow.keras.layers import Dense, GlobalAveragePooling2D, Dropout, BatchNormalization, Activation
from tensorflow.keras.applications import EfficientNetB0  # EfficientNetB0 for lightweight efficiency
from tensorflow.keras.callbacks import EarlyStopping, ModelCheckpoint, ReduceLROnPlateau
from tensorflow.keras.preprocessing.image import ImageDataGenerator
from tensorflow.keras.mixed_precision import set_global_policy

# Enable Mixed Precision Training for Faster Performance
set_global_policy('mixed_float16')

# Enable GPU Memory Growth
gpus = tf.config.list_physical_devices('GPU')
if gpus:
    try:
        for gpu in gpus:
            tf.config.experimental.set_memory_growth(gpu, True)
        print("Memory growth enabled")
    except RuntimeError as e:
        print("Memory growth failed:", e)

# **Load Pre-Trained EfficientNetB0 Model**
# Pretrained on ImageNet, without the top classifier layer
base_model = EfficientNetB0(weights='imagenet', include_top=False, input_shape=(256, 256, 3))

# **Add Classification Layers**
x = base_model.output
x = GlobalAveragePooling2D()(x)  # Reduces dimensionality

# Add custom dense layers
x = Dense(256, kernel_regularizer=tf.keras.regularizers.l2(0.001))(x)
x = BatchNormalization()(x)
x = Activation('relu')(x)
x = Dropout(0.3)(x)

x = Dense(256, kernel_regularizer=tf.keras.regularizers.l2(0.001))(x)
x = BatchNormalization()(x)
x = Activation('relu')(x)
x = Dropout(0.3)(x)

# **Output Layer for Binary Classification**
x = Dense(1, activation='sigmoid')(x)

# **Fine-Tune EfficientNetB0's Last Layers**
for layer in base_model.layers[-20:]:  # Unfreeze last 20 layers
    layer.trainable = True

# **Compile the Model**
model = Model(inputs=base_model.input, outputs=x)

# Learning Rate Scheduling
initial_learning_rate = 1e-5
lr_schedule = tf.keras.optimizers.schedules.ExponentialDecay(
    initial_learning_rate=initial_learning_rate,
    decay_steps=10000,
    decay_rate=0.95,
    staircase=True
)

model.compile(
    optimizer=tf.keras.optimizers.Adam(learning_rate=lr_schedule),
    loss='binary_crossentropy',
    metrics=['accuracy']
)

# **Data Augmentation & Data Generators**
batch_size = 32  # Adjust batch size if memory runs out

train_datagen = ImageDataGenerator(
    rescale=1./255,
    rotation_range=15,
    width_shift_range=0.2,
    height_shift_range=0.2,
    horizontal_flip=True,
    zoom_range=0.2,
    fill_mode='nearest'
)

val_datagen = ImageDataGenerator(rescale=1./255)
test_datagen = ImageDataGenerator(rescale=1./255)

train_generator = train_datagen.flow_from_directory(
    '/home/ubuntu/real_vs_fake/real-vs-fake/train',
    target_size=(256, 256),
    batch_size=batch_size,
    class_mode='binary',
    shuffle=True
)
val_generator = val_datagen.flow_from_directory(
    '/home/ubuntu/real_vs_fake/real-vs-fake/valid',
    target_size=(256, 256),
    batch_size=batch_size,
    class_mode='binary',
    shuffle=False
)
test_generator = test_datagen.flow_from_directory(
    '/home/ubuntu/real_vs_fake/real-vs-fake/test',
    target_size=(256, 256),
    batch_size=batch_size,
    class_mode='binary',
    shuffle=False
)

# **Convert to TensorFlow Dataset for Performance**
def convert_to_float32(images, labels):
    return tf.cast(images, tf.float32), labels

train_dataset = tf.data.Dataset.from_generator(
    lambda: train_generator,
    output_signature=(tf.TensorSpec(shape=(None, 256, 256, 3), dtype=tf.float32),
                      tf.TensorSpec(shape=(None,), dtype=tf.float32))
).map(convert_to_float32).prefetch(buffer_size=tf.data.AUTOTUNE)

val_dataset = tf.data.Dataset.from_generator(
    lambda: val_generator,
    output_signature=(tf.TensorSpec(shape=(None, 256, 256, 3), dtype=tf.float32),
                      tf.TensorSpec(shape=(None,), dtype=tf.float32))
).map(convert_to_float32).prefetch(buffer_size=tf.data.AUTOTUNE)

test_dataset = tf.data.Dataset.from_generator(
    lambda: test_generator,
    output_signature=(tf.TensorSpec(shape=(None, 256, 256, 3), dtype=tf.float32),
                      tf.TensorSpec(shape=(None,), dtype=tf.float32))
).map(convert_to_float32).prefetch(buffer_size=tf.data.AUTOTUNE)

# **Define Callbacks**
callbacks = [
    EarlyStopping(monitor='val_loss', patience=5, restore_best_weights=True, verbose=1),
    ModelCheckpoint('best_efficientnet_model.keras', monitor='val_loss', save_best_only=True, verbose=1),
    ReduceLROnPlateau(monitor='val_loss', factor=0.5, patience=3, min_lr=1e-7, verbose=1)
]

# **Train the Model**
history = model.fit(
    train_dataset,
    steps_per_epoch=train_generator.samples // train_generator.batch_size,
    epochs=5,  # Adjust as needed
    validation_data=val_dataset,
    validation_steps=math.ceil(val_generator.samples / val_generator.batch_size),
    callbacks=callbacks
)

# **Save the Trained Model**
model.save('/home/ubuntu/RealEyez/detection/models/efficientnet_model_two.keras', include_optimizer=False)

# **Inference on Test Data**
from tensorflow.keras.models import load_model

# Load the saved model
loaded_model = load_model('/home/ubuntu/RealEyez/detection/models/efficientnet_model_two.keras')



# Evaluate each test image
test_dir = '/home/ubuntu/real_vs_fake/real-vs-fake/test'
for root, dirs, files in os.walk(test_dir):
    for file in files:
        if file.endswith(('.jpg', '.jpeg', '.png')):
            test_image_path = os.path.join(root, file)
            img = tf.keras.preprocessing.image.load_img(test_image_path, target_size=(256, 256))
            img_array = tf.keras.preprocessing.image.img_to_array(img) / 255.
            img_array = np.expand_dims(img_array, axis=0)

            prediction = loaded_model.predict(img_array)
            confidence = float(prediction[0][0])
            result = "Real" if confidence > 0.5 else "AI-Generated"

            print(f"Image: {test_image_path}")
            print(f"Prediction: {result} (confidence: {confidence:.2%})")
            print("---")

# Evaluate the model
loss, accuracy = loaded_model.evaluate(test_generator)
print(f"Test Accuracy: {accuracy:.2f}")