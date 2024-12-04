pipeline {
    agent any

    stages {
        stage('Pull Image') {
            steps {
                echo 'Pulling image...'
                sh 'docker pull joedhub/realeyez:1.0'
            }
        }

        stage('Run Docker Container') {
            steps {
                echo 'Running the Docker container...'
                script {
                    sh '''
                    # Stop and remove any existing container with the same name
                    docker stop realeyez || true
                    docker rm realeyez || true

                    # Run the container using the pulled image
                    docker run -d --name realeyez -p 8000:8000 joedhub/realeyez:1.0
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
