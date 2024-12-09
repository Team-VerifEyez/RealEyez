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
        // Existing stages...

        // Trivy Scan Stage
        stage('Security Scan - Trivy') {
            when { branch 'main' }
            steps {
                script {
                    echo 'Running Trivy container scan for vulnerabilities...'
                    sh """
                        # Pull the latest Trivy image
                        docker pull aquasec/trivy:latest

                        # Run the Trivy scan on the pulled Docker image
                        docker run --rm \
                            -v /var/run/docker.sock:/var/run/docker.sock \
                            -v ${REPORTS_DIR}:${REPORTS_DIR} \
                            aquasec/trivy:latest \
                            --format json \
                            --output ${REPORTS_DIR}/trivy_report.json \
                            joedhub/owasp_realeyez:latest
                    """
                }
            }
        

        // Further stages...
        
        // Post-stage for security issues handling
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

    post {
        success {
            echo 'Application is running. Access it at http://<your-ip>:8000.'
        }
        failure {
            echo 'Pipeline failed. Check the logs for details.'
        }
    }
}
