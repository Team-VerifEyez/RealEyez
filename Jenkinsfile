pipeline {
    agent { label 'build-node' }

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
                        // Catch errors and mark the build as unstable without stopping the pipeline
                        echo "Checkov scan failed: ${e}"
                        currentBuild.result = 'UNSTABLE'
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
                            // Instead of failing the pipeline, log the issues and mark as unstable
                            currentBuild.result = 'UNSTABLE'
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
            echo 'Checkov scan completed successfully.'
        }
        failure {
            echo 'Pipeline failed. Check the logs for details.'
        }
    }
}
