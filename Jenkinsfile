pipeline {
    agent any

    environment {
        DOCKER_IMAGE = 'realeyez:latest' // The Docker image name
    }

    stages {
        stage('Deploy Docker Container') {
            steps {
                echo 'Deploying Docker container...'
                sh '''
                # Stop and remove the existing container if it exists
                docker stop realeyez || true
                docker rm realeyez || true

                # Run a new container using the existing Docker image
                docker run -d --name realeyez-p 8000:8000 realeyez:latest
                '''
            }
        }
    }

    post {
        success {
            echo 'Deployment successful!'
        }
        failure {
            echo 'Deployment failed.'
        }
    }
}
