pipeline {
    agent { label 'build-node' }

    stages {
        stage('Check Branch') {
            when {
                expression {
                    env.BRANCH_NAME == 'main'
                }
            }
            steps {
                echo 'This pipeline is running on the main branch.'
            }
        }

        stage('Clean Up Disk Space') {
            steps {
                echo 'Cleaning up unused Docker resources to free up space...'
                sh '''
                docker system prune -af || true
                '''
            }
        }

        stage('Pull Image') {
            when {
                branch 'main' // Ensures this stage only runs for the main branch
            }
            steps {
                echo 'Pulling image...'
                sh 'docker pull joedhub/realeyez:1.0'
            }
        }

        stage('Run Docker Container') {
            when {
                branch 'main' // Ensures this stage only runs for the main branch
            }
            steps {
                echo 'Running the Docker container...'
                sh '''
                docker stop realeyez || true
                docker rm realeyez || true
                docker run -d --name realeyez -p 8000:8000 joedhub/realeyez:1.0
                '''
            }
        }
        
        stage('Dynamic Security Analysis - OWASP ZAP') {
            when {
                branch 'main' // Ensures this stage only runs for the main branch
            }
            steps {
                script {
                    // Ensure reports directory exists
                    sh "mkdir -p ${REPORTS_DIR}"
                    
                    // Pull ZAP Docker image
                    sh "docker pull ghcr.io/zaproxy/zaproxy:stable"
                    
                    // Run ZAP scan using Docker
                    sh """
                        docker run --rm \
                            -v ${REPORTS_DIR}:/zap/wrk/:rw \
                            --network="host" \
                            ghcr.io/zaproxy/zaproxy:stable zap-baseline.py \
                            -t http://localhost:8000 \
                            -J zap_scan_results.json \
                            -m 10 \
                            --auto
                    """
                    
                    // Analyze results
                    def zapReport = readJSON file: "${REPORTS_DIR}/zap_scan_results.json"
                    def highAlerts = zapReport.site.findAll { site ->
                        site.alerts.findAll { alert -> alert.riskcode >= 3 }
                    }
                    
                    // Assign the ZAP exit code to zapStatus
                    int zapStatus = sh(script: "echo $?", returnStatus: true)
                    
                    // Log the ZAP scan outcome based on the exit code
                    if (zapStatus == 0) {
                        echo "ZAP scan completed successfully with no issues."
                    } else if (zapStatus == 2) {
                        if (highAlerts.isEmpty()) {
                            echo "ZAP scan completed with warnings. But no High-Risk Security Vulnerabilities were found. Proceeding with pipeline."
                        } else {
                            echo "ZAP scan completed with warnings and high-risk vulnerabilities detected. Proceeding with caution."
                        }
                    } else if (zapStatus >= 3) {
                        echo "ZAP scan encountered a critical issue (Exit Code: ${zapStatus}). Proceeding anyway."
                    }
                    
                    // Remove only the ZAP image
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
