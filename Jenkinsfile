pipeline {
    agent any

    //  environment {
    //     DOCKER_IMAGE = 'realeyez:latest' // The Docker image name
    // }

    stages {
        stage('Run Docker Container') {
            steps {
                echo 'Running the Docker container...'
                script {
                    sh '''
                    # Stop and remove any existing container with the same name
                    docker stop realeyez || true
                    docker rm realeyez || true

                    # Run the container using the local image
                    docker run -d --name realeyez -p 8000:8000 realeyez:latest
                    '''
                }
            }
        }
    }

    post {
        success {
            echo 'Application is running. Access it at http://<your-ip>:8000'
        }
        failure {
            echo 'Pipeline failed. Check the logs for details.'
        }
    }
}

