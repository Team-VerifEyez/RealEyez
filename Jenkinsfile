pipeline {
    agent { label 'build-node' }

    environment {
        REPORTS_DIR = "${WORKSPACE}/reports"
        SONARQUBE_PROJECT_KEY = 'realeyez'   
        SONARQUBE_PROJECT_NAME = 'realeyez'         
        SONARQUBE_HOST_URL = 'http://172.31.40.40:9001'  
        SONARQUBE_LOGIN = credentials('sonarqube-token')  
    }
    
    stages {
        stage('Check Branch') {
            when {
                expression { env.BRANCH_NAME == 'main' }
            }
            steps {
                echo 'This pipeline is running on the main branch.'
            }
        }

        stage('Clean Up Disk Space') {
            steps {
                echo 'Cleaning up unused Docker resources to free up space...'
                sh 'docker system prune -af || true'
            }
        }

        stage('Pull Image') {
            when { branch 'main' }
            steps {
                echo 'Pulling image...'
                sh 'docker pull joedhub/realeyez:1.0'
            }
        }

        stage('Run Docker Container') {
            when { branch 'main' }
            steps {
                echo 'Running the Docker container...'
                sh '''
                    docker stop realeyez || true
                    docker rm realeyez || true
                    docker run -d --name realeyez -p 8000:8000 joedhub/realeyez:1.0
                '''
            }
        }

        stage('SonarQube Analysis') {
            when { branch 'main' }
            steps {
                echo 'Running SonarQube analysis...'
               withCredentials([string(credentialsId: 'sonarqube-token', variable: 'SONARQUBE_TOKEN')]) {
                    sh """
                        sonar-scanner \
                            -Dsonar.projectKey=${SONARQUBE_PROJECT_KEY} \
                            -Dsonar.projectName=${SONARQUBE_PROJECT_NAME} \
                            -Dsonar.sources=./detection,./RealVsAI \    
                            -Dsonar.host.url=${SONARQUBE_HOST_URL} \
                            -Dsonar.login=${SONARQUBE_TOKEN}
                    """
                }
            }
        }

        stage('Dynamic Security Analysis - OWASP ZAP') {
            when { branch 'main' }
            steps {
                script {
                    sh "mkdir -p ${REPORTS_DIR}"
                    sh "docker pull ghcr.io/zaproxy/zaproxy:stable"
                    
                    try { 
                        echo 'Running ZAP Scan...'
                        sh """
                            docker run --rm \
                                -v ${REPORTS_DIR}:/zap/wrk/:rw \
                                --network="host" \
                                ghcr.io/zaproxy/zaproxy:stable zap-baseline.py \
                                -t http://localhost:8000 \
                                -J zap_scan_results.json \
                                -m 10 \
                                --auto || true
                        """
                    } catch (Exception e) {
                        echo "Error during ZAP scan: ${e.message}"
                        error 'OWASP ZAP scan failed.'
                    }
                    
                    def zapReport = readJSON file: "${REPORTS_DIR}/zap_scan_results.json"
                    def highAlerts = zapReport.site.collectMany { site ->
                        site.alerts.findAll { alert -> (alert.riskcode as int) >= 3 }
                    }
                    
                    if (highAlerts.isEmpty()) {
                        echo "No high-risk vulnerabilities found. Proceeding with the pipeline."
                    } else {
                        echo "High-risk vulnerabilities detected. Failing the pipeline:"
                        highAlerts.each { alert ->
                            echo "- ${alert.name}: ${alert.description}"
                        }
                        error 'High-risk vulnerabilities found during OWASP ZAP scan.'
                    }

                    sh "docker rmi ghcr.io/zaproxy/zaproxy:stable"
                }
            }
        }
    }
    
    post {
        success {
            echo 'Application is running. Access it at http://<your-ip>:8000.'
        }
        failure {
            echo 'Pipeline failed. Check the logs for details.'
        }
    }
}
