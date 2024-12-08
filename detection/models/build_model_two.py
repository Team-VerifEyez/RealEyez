import cv2
import math

import numpy as np
from tensorflow.keras import layers
from tensorflow.keras.applications import EfficientNetB0
from tensorflow.keras.layers import (Conv2D, BatchNormalization, Activation, MaxPooling2D, GlobalAveragePooling2D, 
                          Dense, Flatten, Dropout)
from tensorflow.keras.callbacks import Callback, ReduceLROnPlateau , ModelCheckpoint, CSVLogger
from tensorflow.keras.preprocessing.image import ImageDataGenerator
from tensorflow.keras.models import Sequential
from tensorflow.keras.optimizers import Adam
from tensorflow.keras.models import load_model
import matplotlib.pyplot as plt
import pandas as pd
from sklearn import metrics
import tensorflow as tf
from tqdm import tqdm

image_gen = ImageDataGenerator(rescale=1./255.)

batch_size = 64

train_flow = image_gen.flow_from_directory(
    './datasets/train',
    target_size=(256, 256),
    batch_size=batch_size,
    class_mode='binary'
)

valid_flow = image_gen.flow_from_directory(
    './datasets/validation',
    target_size=(256, 256),
    batch_size=batch_size,
    class_mode='binary'
)

test_flow = image_gen.flow_from_directory(
    './datasets/test',
    target_size=(256, 256),
    batch_size=batch_size,
    class_mode='binary'
)

# Convert generators to tf.data.Dataset
AUTOTUNE = tf.data.AUTOTUNE
train_dataset = tf.data.Dataset.from_generator(
    lambda: train_flow,
    output_signature=(
        tf.TensorSpec(shape=(None, 256, 256, 3), dtype=tf.float32),
        tf.TensorSpec(shape=(None,), dtype=tf.float32),
    )
).repeat().prefetch(AUTOTUNE)

validation_dataset = tf.data.Dataset.from_generator(
    lambda: valid_flow,
    output_signature=(
        tf.TensorSpec(shape=(None, 256, 256, 3), dtype=tf.float32),
        tf.TensorSpec(shape=(None,), dtype=tf.float32),
    )
).repeat().prefetch(AUTOTUNE)

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
                             moniter='val_loss'
                            )
reduce_lr = ReduceLROnPlateau(monitor='val_loss', 
                              factor=0.2, 
                              patience=3, 
                              verbose=1, 
                              min_delta=0.0001
                             )
csv_logger = CSVLogger('training.log')

callbacks = [checkpoint, reduce_lr, csv_logger]

base_model = EfficientNetB0(weights='imagenet', include_top=False, input_shape=(256, 256, 3))
model = build_model(base_model)
model.summary()

# Define steps for training
steps_per_epoch = math.ceil(train_flow.samples / train_flow.batch_size)
validation_steps = math.ceil(valid_flow.samples / valid_flow.batch_size)

# Training
history = model.fit(
    train_flow,
    epochs=10,
    callbacks = callbacks,
    steps_per_epoch=steps_per_epoch,
    validation_data=valid_flow,
    validation_steps=validation_steps,
)

_, accu = model.evaluate(test_flow)
print('Final Test Acccuracy = {:.3f}'.format(accu*100))