from django.shortcuts import render, redirect
from django.conf import settings
from django.contrib.auth.models import User
from django.contrib.auth.decorators import login_required
from django.http import HttpResponse
from django.core.mail import send_mail
from .forms import ImageUploadForm
from django.contrib import messages
from .models import Image  # Assuming the ImageSlider model exists
from django.contrib.auth import authenticate, login, logout
from tensorflow.keras.models import load_model  # type: ignore
from tensorflow.keras.applications.efficientnet import preprocess_input  # type: ignore
from tensorflow.keras.preprocessing.image import load_img, img_to_array

import numpy as np
from PIL import Image  # Correct import for handling images
import os

# Load model once during server startup
MODEL_PATH = os.path.join('detection', 'models', 'real_vs_fake_classifier.h5')
model = load_model(MODEL_PATH)

def predict_image(image):
    # Open the image and ensure RGB
    # img = Image.open(image).convert("RGB")
    
    # Resize the image to the expected size for EfficientNet
    # img = img.resize((224, 224))
    
    # Convert the image to a NumPy array
    # img_array = np.array(img)
    
    # Add batch dimension
    # img_array = np.expand_dims(img_array, axis=0)
    
    # Preprocess the image
    # img_array = preprocess_input(img_array)

    img = load_img(image, target_size=(224, 224))
    img_array = img_to_array(img)
    img_array = img_array / 255.0  # Normalize pixel values
    img_array = np.expand_dims(img_array, axis=0)

    # Make predictions
    prediction = model.predict(img_array)
    
    # Determine predicted class and confidence
    # Class with highest confidence
    confidence = prediction[0][0]  # Confidence for the predicted class

    # Debugging and output
    print(f'The Predictions: {prediction}')
    print(f'The confidence: {confidence}')
    
    # Use the confidence to determine the label and return the result
    if confidence >= 0.5:
        # If confidence is above the threshold, classify as "Real"
        return "Real", confidence * 100  # Return confidence as percentage
    else:
        # If confidence is below the threshold, classify as "AI-Generated"
        return "AI-Generated", (1 - confidence) * 100  # Return the inverted confidence as percentage

def upload(request):
    form = ImageUploadForm()  # Always initialize 'form' to avoid the error
    if request.method == 'POST':
        form = ImageUploadForm(request.POST, request.FILES)
        if form.is_valid():
            # Save the uploaded image
            image_file = request.FILES['image']
            image_path = os.path.join('media', image_file.name)

            # Ensure the directory exists
            if not os.path.exists('media'):
                os.makedirs('media')

            with open(image_path, 'wb+') as destination:
                for chunk in image_file.chunks():
                    destination.write(chunk)

            # Preprocess the image and pass it to the model
            label, confidence = predict_image(image_path)

            result = f"{label} ({confidence:.2f}%)"
            relative_image_path = f"{settings.MEDIA_URL}{image_file.name}"
            return render(request, 'result.html', {
                'result': result,
                'image_path': relative_image_path  # Use relative path for the template
            })
        else:
            form = ImageUploadForm()

    return render(request, 'upload.html', {'form': form})

def home(request):
    return render(request, 'home.html')

from rest_framework.response import Response
from rest_framework.decorators import api_view

@api_view(['GET'])
def api_data(request):
    data = {"message": "Hello from Django API!"}
    return Response(data)


def pricing(request):
    return render(request, "pricing.html")

def about(request):
    return render(request, "about.html")

def contact(request):
    message_sent = False
    if request.method == 'POST':
        # Get data from the form
        full_name = request.POST.get('full_name')
        email = request.POST.get('email')
        message = request.POST.get('message')

        # Process the form (e.g., save to database, send an email)
        # For now, we'll just display a success message on the same page.

        message_sent = True  # Set the flag to display the success message
        messages.success(request, 'Thank you for your message. We will revert back to you as soon as possible.')

    return render(request, 'contact.html', {'message_sent': message_sent})

def user_login(request):
    if request.method == "POST":
        username = request.POST["username"]
        password = request.POST["password"]
        user = authenticate(request, username=username, password=password)
        if user is not None:
            login(request, user)
            return redirect("home")
        else:
            return render(request, "login.html", {"error": "Invalid credentials"})
    return render(request, "login.html")

def register(request):
    if request.method == "POST":
        username = request.POST["username"]
        password = request.POST["password"]
        User.objects.create_user(username=username, password=password)
        return redirect("login")
    return render(request, "register.html")

@login_required
def test_here_view(request):
    # Your logic for the "Test Here" page
    return render(request, 'upload.html')

def logout_user(request):
    logout(request)
    return redirect("home")

