# Introduction

This documentation provides a comprehensive guide for deploying RealEyez, a Django-based application that detects whether images are real or AI-generated. The deployment process leverages Terraform for modular infrastructure automation, Docker for containerization, and Jenkins for CI/CD pipeline management. The pipeline integrates multiple security tools, such as OWASP Scan, SonarQube, and Checkov, to enhance application and infrastructure integrity. This documentation also details the process used for AI model training as well as how to dynamically set up monitoring with Grafana and Prometheus. By following these instructions, users will be able to set up a scalable and efficient deployment of RealEyez.

# RealEyez 
RealEyez is a machine learning-based project designed to detect whether an image is real or AI-generated. This web application utilizes a Convolutional Neural Network (CNN) model based on EfficientNet to classify images. The project is built using Django for the web framework and integrates an AI model that analyzes images and predicts their authenticity.

## Project Video
https://github.com/user-attachments/assets/fd5b5b5e-0034-4931-9087-067aabbc488e

## Table of Content
- Features
- Dataset Used
- Technologies Used
- Setup and Installation
- Usage
- Model Description
- Contributing
- License
## Features
- Image Upload: Users can upload images to the web app for prediction.
- Real vs AI-Generated Classification: The model classifies the uploaded image as either 'Real' or 'AI-generated' with a percentage likelihood.
- EfficientNet Model: The AI model is built on EfficientNet for efficient and accurate predictions.
- User-friendly Interface: The web interface is intuitive and responsive, designed for seamless interaction with the model.

## Dataset Used
The 140k Real and Fake Faces dataset consists of all 70k REAL faces from the Flickr dataset collected by Nvidia, as well as 70k fake faces sampled from the 1 Million FAKE faces (generated by StyleGAN) that was provided by Bojan. (https://www.kaggle.com/datasets/xhlulu/140k-real-and-fake-faces)

## Technologies Used
- Django: Web framework for building the application.
- Python: Backend language.
- TensorFlow: Deep learning library used to implement the EfficientNet model.
- Keras: API for building and training neural networks, integrated with TensorFlow.
- Bootstrap: Frontend framework for responsive and modern design.
- HTML/CSS/JavaScript: Used for frontend development and interactivity.
- SQLite: Default database used by Django for storing minimal data.\
## Local Setup and Installation
1. Clone the repository:
    ```bash
    git clone https://github.com/Team-VerifEyez/RealEyez.git
    cd RealEyez
2. Set up a Virtual Environment
      ```bash
      python3.12 -m venv venv
      source venv/bin/activate  # On Windows: env\Scripts\activate
3. Install Dependencies:
      ```bash
      pip install -r requirements.txt
4. Run Migrations
      ```bash
      python manage.py migrate
5. Run the Django Development Server
      ```bash
      python manage.py runserver

## Usage
- Navigate to the Home page where you will see the "Upload Image" option.
- Upload an image you want to classify (either real or AI-generated).
- The model will predict whether the image is real or AI-generated, showing the result along with the likelihood percentage.

## Model Description
The model is based on EfficientNet, a highly efficient deep learning architecture for image classification tasks. The network uses a combination of depth, width, and resolution scaling to provide an efficient architecture. The model was trained on a large dataset of real and AI-generated images, achieving a high level of accuracy in classification.

## Training Details
- Model Architecture: EfficientNet (CNN)
- Framework: TensorFlow/Keras
- Input Size: 224x224 pixels
- Training Dataset: Custom dataset of real and AI-generated images
- Accuracy: The model achieves an accuracy of 98.9% on the test dataset.

## License
This project is licensed under the MIT License - see the LICENSE file for details.

## Instructions
In your default VPC, create two EC2s:

1. Jenkins Manager Instance (t3.micro)

    - This EC2 will represent your Jenkins Manager instance. While launching, create and save a new key pair.
    - Install Jenkins & Java 17
    - Security Group Ports: 22 (SSH), 8080 (Jenkins)


2. Jenkins Node Instance (t3.medium)

    -   This EC2 will represent your Jenkins Node instance. While launching, use the same key pair as your Jenkins Manager Instance.
    - Depending on your pipeline, you may need to add additional volume to this EC2 past the free tier AWS offers (at 30 GB.) For this project, our team decided on a total of 70GB. You can configure the volume of your EC2 in the 'Launch Instance' view in AWS or if you've already created it, select your instance > click the "Storage" tab > Click on the Volume ID > Select the Voume ID again on the next page > Click on the "Actions" drop-down menu and select "Attach Volume".

Create a t3.medium EC2 called "Docker_Terraform" to represent your Jenkins Node instance. Use the same key pair as Jenkins EC2.
- Java 17
- Docker
- Terraform

Security Tools (Optional):
- OWASP Zap
- Checkov
- Trivy
- SonarQube (requires an additional EC2 to act as a SonarQube Server)

To provision your infrastructure, use Terraform to create your resources - You may reference the below system diagram to understand what sort of infrastructure you want to build. In your Terraform main.tf file(s), use the user_data section to install Docker on your instances in your VPC of choice. From there, you're able to pull the Docker image of this application onto your EC2.  

## System Diagram
![image](https://github.com/user-attachments/assets/a3d1b110-0d5a-426c-afd4-64caf3afec96)

# Conclusion
The RealEyez deployment exemplifies a secure, efficient, and scalable solution for AI-driven image analysis. By leveraging Terraform for dynamic infrastructure provisioning, Docker for application containerization, and Jenkins for seamless automation, this guide demonstrates how to achieve scalable deployments with high reliability. Moreover, robust security practices and dynamic monitoring further enhance the system's operational integrity. Whether you are a developer, DevOps engineer, or a tech enthusiast, this guide equips you with the knowledge to deploy and maintain this innovative application successfully.
