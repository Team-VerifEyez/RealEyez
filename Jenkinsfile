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
                        # Save detailed report to JSON file
                        docker run --rm \
                            -v /var/run/docker.sock:/var/run/docker.sock \
                            -v $HOME/.trivy:/root/.cache/trivy \
                            aquasec/trivy:latest image \
                            --format json \
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

        // Further stages...
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
