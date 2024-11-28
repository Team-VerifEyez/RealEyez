pipeline {
    agent any
    
    environment {
        REPORTS_DIR = "${WORKSPACE}/reports"
        SONAR_PROJECT_KEY = 'realeyez'
        LOCAL_APP_URL = 'http://localhost:8000'  // Django default port
    }
    
    stages {
        stage('Initialize') {
            steps {
                sh """
                    mkdir -p ${REPORTS_DIR}
                    echo "Created reports directory at ${REPORTS_DIR}"
                """
            }
        }

        stage('Build & Test') {
            steps {
                sh '''
                    python3.9 -m venv venv
                    source venv/bin/activate
                    pip install -r requirements.txt
                    python manage.py migrate
                    python manage.py runserver &
                    echo "Django server started in background"
                '''
            }
        }

        stage('Security Scans') {
            parallel {
                stage('SonarQube Analysis') {
                    steps {
                        withSonarQubeEnv('SonarQube') {
                            sh """
                                sonar-scanner \
                                -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                                -Dsonar.sources=. \
                                -Dsonar.host.url=http:/98.83.164.237:9000 \
                                -Dsonar.python.version=3.12
                            """
                        }
                    }
                }

                stage('OWASP ZAP Scan') {
                    steps {
                        sh """
                            docker run --rm \
                                --network="host" \
                                -v ${REPORTS_DIR}:/zap/wrk/:rw \
                                owasp/zap2docker-stable zap-baseline.py \
                                -t ${LOCAL_APP_URL} \
                                -J zap-report.json
                        """
                    }
                }
            }
        }
    }
    
    post {
        always {
            archiveArtifacts artifacts: 'reports/**/*', fingerprint: true
            sh 'pkill -f "runserver"'  // Stop Django server
        }
    }
}
