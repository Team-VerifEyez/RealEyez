import tensorflow as tf
from tensorflow.keras.models import load_model
import os

MODEL_PATH = os.path.join('detection', 'models', 'efficientnet_model.h5')
    
try:
    # Load the model
    model = load_model(MODEL_PATH)
    print("Model loaded successfully!")

    # Display the model architecture
    print("\nModel Summary:")
    model.summary()

    # Display input and output shapes
    print("\nInput Shape:", model.input_shape)
    print("Output Shape:", model.output_shape)

    # Display the layers and their configurations
    print("\nModel Layers:")
    for layer in model.layers:
        print(f"Layer Name: {layer.name}, Layer Type: {type(layer)}, Output Shape: {layer.output_shape}")

except Exception as e:
    print(f"Error loading the model: {e}")
