pipeline {
    agent { label 'build-node' }

    environment {
        REPORTS_DIR = "${WORKSPACE}/reports"
        SONARQUBE_PROJECT_KEY = 'realeyez'   
        SONARQUBE_PROJECT_NAME = 'realeyez'         
        SONARQUBE_HOST_URL = 'http://172.31.40.40:9001'  
        SONARQUBE_LOGIN = credentials('sonarqube-token')  
        DJANGO_KEY = credentials('DJANGO_KEY')
    }

    stages {
        // SonarQube Analysis Stage to perform code quality and static analysis
        stage('SonarQube Analysis') {
            when { branch 'main' }
            steps {
                echo 'Running SonarQube analysis...'
                withCredentials([string(credentialsId: 'sonarqube-token', variable: 'SONARQUBE_TOKEN')]) {
                    sh """
                        export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
                        export PATH=\$JAVA_HOME/bin:\$PATH
                        /opt/sonar-scanner/bin/sonar-scanner \
                            -Dsonar.projectKey=${SONARQUBE_PROJECT_KEY} \
                            -Dsonar.projectName=${SONARQUBE_PROJECT_NAME} \
                            -Dsonar.sources=./detection,./RealVsAI \
                            -Dsonar.host.url=${SONARQUBE_HOST_URL} \
                            -Dsonar.login=${SONARQUBE_TOKEN}
                    """
                }
            }
        }
        
        // Branch Validation Stage to ensure the pipeline runs only on the main branch
        stage('Check Branch') {
            when {
                expression { env.BRANCH_NAME == 'main' }
            }
            steps {
                echo 'This pipeline is running on the main branch.'
            }
        }

        // Cleanup Stage to remove temporary and unused resources
        stage('Cleanup') {
            steps {
            sh '''
                echo "Performing in-pipeline cleanup after Test..."
                docker system prune -f
                git clean -ffdx -e ".tfstate" -e ".terraform/*"
            '''
      }
    }

        // Pull Docker Image Stage to retrieve the latest application image
        stage('Pull Image') {
            when { branch 'main' }
            steps {
                echo 'Pulling image...'
                sh 'docker pull joedhub/owasp_realeyez:latest'
            }
        }

        // Trivy Scan Stage to scan the application image for vulnerabilities
        stage('Security Scan - Trivy') {
            when { branch 'main' }
            steps {
                script {
                    sh "mkdir -p ${REPORTS_DIR}"
                    echo 'Running Trivy container scan for vulnerabilities...'
                    
                    sh """
                        # Save detailed report to JSON file
                        docker run --rm \
                            -v /var/run/docker.sock:/var/run/docker.sock \
                            -v $HOME/.trivy:/root/.cache/trivy \
                            aquasec/trivy:latest image \
                            --format json \
                            --debug \
                            --quiet \
                            --skip-update \
                            --scanners vuln \
                            --timeout 20m \
                            --severity HIGH,CRITICAL \
                            joedhub/owasp_realeyez:latest > ${REPORTS_DIR}/trivy_report.json
                    """
                    
                    // Archive the detailed report
                    archiveArtifacts artifacts: 'reports/trivy_report.json'
                }
            }
        
            post {
                failure {
                    script {
                        if (fileExists("${REPORTS_DIR}/trivy_report.json")) {
                            def trivyReport = readJSON file: "${REPORTS_DIR}/trivy_report.json"
                            def highSeverityIssues = trivyReport.findAll { 
                                it.Severity in ['HIGH', 'CRITICAL']
                            }

                            if (highSeverityIssues) {
                                echo "High-severity vulnerabilities detected:"
                                highSeverityIssues.each { issue ->
                                    echo "Vulnerability: ${issue.VulnerabilityID} | Severity: ${issue.Severity} | Package: ${issue.PkgName}"
                                }
                                error "Trivy scan found high-severity vulnerabilities."
                            } else {
                                echo "No high-severity vulnerabilities found in Trivy scan."
                            }
                        } else {
                            error "Trivy scan report not found."
                        }
                    }
                }
            }
        }

        // Docker Container Run Stage to start the application container
        stage('Run Docker Container') {
            when { branch 'main' }
            steps {
                echo 'Running the Docker container...'
                withCredentials([string(credentialsId: 'DJANGO_KEY', variable: 'DJANGO_KEY')]) {
                sh '''
                    docker run -d --name owasp_realeyez -p 8000:8000 -e DJANGO_KEY=${DJANGO_KEY} joedhub/owasp_realeyez:latest
                '''
            }
            } 
        }

        // OWASP ZAP Scan Stage to perform dynamic security analysis
        stage('Dynamic Security Analysis - OWASP ZAP') {
            when { branch 'main' }
            steps {
                script {
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
                        echo "High-risk vulnerabilities detected. Failing the pipeline!"
                        highAlerts.each { alert ->
                            echo "- ${alert.name}: ${alert.description}"
                        }
                        error 'High-risk vulnerabilities found during OWASP ZAP scan.'
                    }

                    sh "docker rmi ghcr.io/zaproxy/zaproxy:stable"
                }
            }
        }

        // Disk Cleanup Stage to remove unused Docker resources
        stage('Clean Up Disk Space') {
            steps {
                echo 'Cleaning up unused Docker resources to free up space...'
                sh '''
                    docker stop owasp_realeyez || true
                    docker rm owasp_realeyez || true
                    docker system prune -af || true
                '''
            }
        }

        // Terraform Plan Stage to prepare infrastructure for deployment
        stage('Terraform Plan') {
            steps {
                dir('Terraform/Dev') {
                    withCredentials([
                        string(credentialsId: 'DOCKERHUB_USERNAME', variable: 'DOCKERHUB_USERNAME'),
                        string(credentialsId: 'DOCKERHUB_PASSWORD', variable: 'DOCKERHUB_PASSWORD'),
                        string(credentialsId: 'RDS_PASSWORD', variable: 'RDS_PASSWORD'),
                        string(credentialsId: 'DJANGO_KEY', variable: 'DJANGO_KEY')
                    ]) {
                        sh '''
                            echo "Initializing Terraform..."
                            terraform init

                            echo "Running Terraform plan..."
                            terraform plan -out=tfplan \
                            -var="dockerhub_username=${DOCKERHUB_USERNAME}" \
                            -var="dockerhub_password=${DOCKERHUB_PASSWORD}" \
                            -var="db_password=${RDS_PASSWORD}" \
                            -var="django_key=${DJANGO_KEY}"
                        '''
                    }
                }
            }
        }
        
        // Infrastructure Security Stage to analyze Terraform and Kubernetes code with Checkov
        stage('Infrastructure Security - Checkov') {
                    steps {
                        script {
                            // Create the reports directory in Jenkins workspace if it doesn't exist
                            sh "mkdir -p ${REPORTS_DIR}"

                            try {
                                // Run Checkov scan
                                sh """
                                    python3 -m venv checkov_env
                                    . checkov_env/bin/activate  # Use absolute path if needed
                                    pip install --upgrade pip
                                    pip install checkov
                                    checkov \
                                        --directory ${WORKSPACE}/Terraform/Dev   # Points to the app code
                                        --output json \
                                        --output-file-path ${REPORTS_DIR}/checkov_report.json \
                                        --framework terraform,kubernetes \
                                        --soft-fail
                                    deactivate
                                """
                            } catch (Exception e) {
                                // Catch errors and mark the build as a success without stopping the pipeline
                                echo "Checkov scan failed: ${e}"
                                currentBuild.result = 'SUCCESS'
                                echo "Pipeline continues even after Checkov failure."
                            }

                            // Ensure the file exists before reading
                            if (fileExists("${REPORTS_DIR}/checkov_report.json")) {
                                // Read and parse the Checkov report
                                def checkovReport = readJSON file: "${REPORTS_DIR}/checkov_report.json"
                                def highSeverityIssues = checkovReport.results.failed_checks.findAll { 
                                    it.severity in ['HIGH', 'CRITICAL'] 
                                }

                                // Save and print the full Checkov report in the Jenkins workspace
                                echo "Checkov Scan Report: Saving to workspace report directory"
                                sh "cat ${REPORTS_DIR}/checkov_report.json"

                                // Archive the report file in Jenkins
                                archiveArtifacts artifacts: "${REPORTS_DIR}/checkov_report.json", allowEmptyArchive: true

                                if (highSeverityIssues) {
                                    echo "High severity issues found: ${highSeverityIssues.size()}"
                                    highSeverityIssues.each { issue ->
                                        echo "Resource: ${issue.resource} | Check ID: ${issue.check_id} | Severity: ${issue.severity} | Message: ${issue.check_name}"
                                    }
                                    // Instead of failing the pipeline, log the issues and mark as a success
                                    currentBuild.result = 'SUCCESS'
                                    echo "High severity infrastructure issues detected. Pipeline continues."
                                } else {
                                    echo "No high severity issues found."
                                }
                            } else {
                                // If report is not generated, just log the message and continue
                                echo "Checkov report not generated. Skipping further analysis."
                            }
                        }
                    }
                }

        // Virtual Environment Cleanup Stage to remove Python virtual environment
        stage('Cleanup Virtual Environment') {
            steps {
                sh '''
                    echo "Removing Python virtual environment..."
                    rm -rf checkov_env
                '''
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
