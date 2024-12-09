pipeline {
    agent { label 'build-node' }

    parameters {
        booleanParam(name: 'RUN_CHECKOV', defaultValue: true, description: 'Run Checkov stage')
    }

    environment {
        REPORTS_DIR = "${WORKSPACE}/reports"
        DJANGO_KEY = credentials('DJANGO_KEY')
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

        stage('Infrastructure Security - Checkov') {
            when {
                expression { params.RUN_CHECKOV }
            }
            steps {
                script {
                    sh "mkdir -p ${REPORTS_DIR}"
                    
                    try {
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
                    } 
                    catch (Exception e) {
                        echo "Checkov scan failed: ${e}"
                        error "Checkov scan failed, stopping the pipeline."  // Ensures pipeline fails on scan failure
                    }
                    
                    if (fileExists("${REPORTS_DIR}/checkov_report.json")) {
                        def checkovReport = readJSON file: "${REPORTS_DIR}/checkov_report.json"
                        def highSeverityIssues = checkovReport.results.failed_checks.findAll { 
                            it.severity in ['HIGH', 'CRITICAL'] 
                        }

                        if (highSeverityIssues) {
                            echo "High severity issues found: ${highSeverityIssues.size()}"
                            highSeverityIssues.each { issue -> 
                                echo "Resource: ${issue.resource} | Check ID: ${issue.check_id} | Severity: ${issue.severity} | Message: ${issue.check_name}"
                            }
                            error "High severity infrastructure issues detected."
                        } else {
                            echo "No high severity issues found."
                        }
                    } else {
                        error "Checkov report not generated. Skipping further analysis."
                    }
                }
            }
        }

        // Other stages can remain commented out or can be skipped conditionally
        stage('Cleanup Virtual Environment') {
            when {
                expression { params.RUN_CHECKOV }
            }
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
            echo 'Checkov scan completed successfully.'
        }
        failure {
            echo 'Pipeline failed. Check the logs for details.'
        }
    }
}
