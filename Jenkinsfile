pipeline {
    agent any

    environment {
        REPORTS_DIR = "${WORKSPACE}/reports"
        SONAR_PROJECT_KEY = 'realeyez'
        LOCAL_APP_URL = 'http://98.83.164.237:8000'  // Django default port
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

                    echo "Starting Django server in the background..."
                    nohup python manage.py runserver 0.0.0.0:8000 &> server.log &
                '''
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
                                -m 10 --auto
                        """
                        sh """
                            echo "ZAP scan completed. Reports generated:"
                            ls -la ${REPORTS_DIR}
                            echo "JSON report: ${REPORTS_DIR}/zap-report.json"
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

            echo "Pipeline cleanup completed."
        }
    }
}

