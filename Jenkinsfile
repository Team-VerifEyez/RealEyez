pipeline {
    agent any

    environment {
        REPORTS_DIR = "${WORKSPACE}/reports"
        SONAR_PROJECT_KEY = 'realeyez'
        LOCAL_APP_URL = 'http://0.0.0.0:8000'  // Django server URL
        
        // Terraform credentials
        SONAR_TOKEN = credentials('sonar-token')
	DOCKER_CREDS = credentials('dockerhub-credentials')
        DB_PASSWORD = credentials('db-password')
    }

    stages {
        stage('Initialize') {
            steps {
                sh """
                    mkdir -p ${REPORTS_DIR}
                    echo "Reports directory created: ${REPORTS_DIR}"
                """
            }
        }

        stage('Build & Test') {
            steps {
                sh '''
                    echo "Setting up Python environment and dependencies..."
                    python3.9 -m venv venv
                    source venv/bin/activate
                    pip install -r requirements.txt

                    echo "Running database migrations..."
                    python manage.py migrate

                    echo "Starting Django development server on 0.0.0.0:8000..."
                    nohup python manage.py runserver 0.0.0.0:8000 &> server.log &
                '''
            }
        }

        stage('Terraform Plan') {
            agent { label 'build-node' }
            steps {
                dir('Terraform') {
                    sh '''
                        echo "Initializing Terraform..."
                        terraform init

                        echo "Running Terraform plan..."
                        terraform plan -out=tfplan \
                          -var="dockerhub_username=${DOCKER_CREDS_USR}" \
                          -var="dockerhub_password=${DOCKER_CREDS_PSW}" \
                          -var="db_password=${DB_PASSWORD}"
                    '''
                }
            }
        }

        stage('Terraform Apply') {
            agent { label 'build-node' }
            steps {
                dir('Terraform') {
                    sh '''
                        echo "Applying Terraform configuration..."
                        terraform apply -auto-approve tfplan
                    '''
                }
            }
        }

        stage('Security Scans') {
            parallel {
                stage('SonarQube Analysis') {
                    steps {
                        withSonarQubeEnv('SonarQube') {
                            sh """
                                echo "Running SonarQube analysis..."
                                sonar-scanner \
                                    -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                                    -Dsonar.sources=. \
                                    -Dsonar.host.url=http://98.83.164.237:9000 \
                                    -Dsonar.python.version=3.12
                            """
                        }
                    }
                }

                stage('OWASP ZAP Scan') {
                    steps {
                        sh """
                            echo "Starting OWASP ZAP baseline scan..."
                            docker run --rm \
                                --network="host" \
                                -v ${REPORTS_DIR}:/zap/wrk/:rw \
                                owasp/zap2docker-stable zap-baseline.py \
                                -t ${LOCAL_APP_URL} \
                                -J /zap/wrk/zap-report.json \
                                -r /zap/wrk/zap_scan_report.html \
                                -m 10 --auto
                        """
                        sh """
                            echo "ZAP scan completed. Reports generated:"
                            ls -la ${REPORTS_DIR}
                            echo "JSON report: ${REPORTS_DIR}/zap-report.json"
                            echo "HTML report: ${REPORTS_DIR}/zap_scan_report.html"
                        """
                    }
                }
            }
        }
    }

    post {
        always {
            echo "Archiving reports..."
            archiveArtifacts artifacts: 'reports/**/*', fingerprint: true

            echo "Stopping Django server..."
            sh 'pkill -f "manage.py runserver"' || true  // Ensure the server is stopped

            echo "Performing Docker cleanup..."
            sh '''
                docker logout
                docker system prune -f
            '''
        }

        success {
            echo "Pipeline executed successfully!"
        }

        failure {
            echo "Pipeline failed. Cleaning up Terraform resources..."
            dir('Terraform') {
                sh '''
                    terraform destroy -auto-approve \
                      -var="dockerhub_username=${DOCKER_CREDS_USR}" \
                      -var="dockerhub_password=${DOCKER_CREDS_PSW}" \
                      -var="db_password=${DB_PASSWORD}"
                '''
            }
        }
    }
}

