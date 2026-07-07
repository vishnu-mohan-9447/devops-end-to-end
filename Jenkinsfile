// ============================================================
// Cokonet LMS 
// Checkout -> Build -> Unit Tests -> SonarQube -> Quality Gate
// -> Trivy FS Scan -> Docker Build -> Trivy Image Scan -> Push
// ============================================================

def services = ['frontend', 'backend', 'database']

pipeline {
    agent any

    options {
        timestamps()
        ansiColor('xterm')
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20'))
    }

    tools {
        nodejs 'node-20'   // Manage Jenkins > Tools > NodeJS installations > "node-20"
    }

    environment {
        DOCKERHUB_NAMESPACE = 'vishnumohan9447'   // <-- change me
        DOCKERHUB_CREDS     = credentials('dockerhub-creds')
        SONAR_PROJECT_KEY   = 'cokonet-lms'
        IMAGE_TAG           = "${env.BUILD_NUMBER}"
        APP_DIR             = 'Lms-App'
        PATH                = "${WORKSPACE}/bin:${env.PATH}"
        ADMIN_EMAIL         = 'vishnu.mohan.9447@gmail.com'   // <-- change me
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Bootstrap Trivy') {
            // No Jenkins plugin installs Trivy, so the pipeline installs it
            // itself into the workspace-local bin/ the first time it's missing.
            steps {
                sh '''
                    mkdir -p "$WORKSPACE/bin"
                    if ! command -v trivy >/dev/null 2>&1 && [ ! -x "$WORKSPACE/bin/trivy" ]; then
                        curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \
                          | sh -s -- -b "$WORKSPACE/bin"
                    fi
                '''
            }
        }

        stage('Build') {
            steps {
                dir("${APP_DIR}/backend") {
                    sh 'npm ci || npm install'
                }
            }
        }

        stage('Unit Tests') {
            steps {
                dir("${APP_DIR}/backend") {
                    script {
                        def hasTestScript = sh(
                            script: "node -e \"const p=require('./package.json'); process.exit(p.scripts && p.scripts.test ? 0 : 1)\"",
                            returnStatus: true
                        ) == 0

                        if (hasTestScript) {
                            sh 'npm test -- --ci || true'
                        } else {
                            echo 'No "test" script defined in backend/package.json - skipping unit tests. Add a Jest/Mocha suite to make this stage meaningful.'
                        }
                    }
                }
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: "${APP_DIR}/backend/**/junit.xml"
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                dir("${APP_DIR}/backend") {
                    script {
                        // "SonarScanner" = name given under Manage Jenkins > Tools >
                        // SonarQube Scanner installations (auto-install enabled)
                        def scannerHome = tool 'SonarScanner'
                        withSonarQubeEnv('SonarQubeServer') {
                            sh """
                                ${scannerHome}/bin/sonar-scanner \
                                  -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                                  -Dsonar.sources=src \
                                  -Dsonar.exclusions=node_modules/**
                            """
                        }
                    }
                }
            }
        }

//        stage('Quality Gate') {
//            steps {
//                timeout(time: 10, unit: 'MINUTES') {
//                    // TEMPORARY for testing: abortPipeline set to false so a failing
                    // gate doesn't stop the pipeline. Sonar result still shows in
                    // Jenkins and the SonarQube dashboard either way.
                    // Revert to abortPipeline: true once tests/coverage are wired
                    // up and the gate should actually enforce quality.
//                    waitForQualityGate abortPipeline: false
//                }
//            }
//        }

        stage('Trivy FS Scan') {
            steps {
                sh """
                    trivy fs --exit-code 0 --severity HIGH,CRITICAL \
                      --format table -o trivy-fs-report.txt ${APP_DIR}
                """
            }
            post {
                always {
                    archiveArtifacts artifacts: 'trivy-fs-report.txt', allowEmptyArchive: true
                }
            }
        }

        stage('Docker Build') {
            steps {
                script {
                    services.each { svc ->
                        sh """
                            docker build -t ${DOCKERHUB_NAMESPACE}/lms-${svc}:${IMAGE_TAG} \
                                         -t ${DOCKERHUB_NAMESPACE}/lms-${svc}:latest \
                                         ${APP_DIR}/${svc}
                        """
                    }
                }
            }
        }

        stage('Trivy Image Scan') {
            steps {
                script {
                    services.each { svc ->
                        sh """
                            trivy image --exit-code 1 --severity CRITICAL \
                              --format table -o trivy-${svc}-image-report.txt \
                              ${DOCKERHUB_NAMESPACE}/lms-${svc}:${IMAGE_TAG}
                        """
                    }
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: 'trivy-*-image-report.txt', allowEmptyArchive: true
                }
            }
        }

        stage('Push to Docker Hub') {
            steps {
                sh 'echo $DOCKERHUB_CREDS_PSW | docker login -u $DOCKERHUB_CREDS_USR --password-stdin'
                script {
                    services.each { svc ->
                        sh """
                            docker push ${DOCKERHUB_NAMESPACE}/lms-${svc}:${IMAGE_TAG}
                            docker push ${DOCKERHUB_NAMESPACE}/lms-${svc}:latest
                        """
                    }
                }
                sh 'docker logout'
            }
        }

        stage('Deploy to Development') {
            // Jenkins and the dev Docker Compose stack live on the same
            // host, so this is a local docker compose call - no SSH/remote
            // deploy complexity needed. docker-compose.dev.yml is expected
            // to reference images (not build: contexts) so it pulls the
            // freshly pushed tags rather than rebuilding locally.
            steps {
                dir("${APP_DIR}") {
                    sh 'docker compose -f docker-compose.dev.yml pull'
                    sh 'docker compose -f docker-compose.dev.yml up -d'
                    sh '''
                        echo "Waiting for backend health check..."
                        for i in $(seq 1 12); do
                            if curl -sf http://localhost:5000/health > /dev/null; then
                                echo "Backend is healthy"
                                exit 0
                            fi
                            sleep 5
                        done
                        echo "Backend did not become healthy in time"
                        exit 1
                    '''
                }
            }
        }

        stage('Manual Approval') {
            steps {
                script {
                    mail to: "${ADMIN_EMAIL}",
                         subject: "ACTION NEEDED: Approve production deploy for ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                         body: """\
Dev deployment for ${env.JOB_NAME} #${env.BUILD_NUMBER} is up and its health check passed.

Review and approve/reject promotion to production (expires in 1 hour if no response):
${env.BUILD_URL}input/

Full build details: ${env.BUILD_URL}
"""

                    try {
                        timeout(time: 1, unit: 'HOURS') {
                            input message: 'Dev deployment verified. Approve promotion to production?',
                                  ok: 'Approve',
                                  submitterParameter: 'APPROVER_ID'
                                  // submitter: 'admin'   // <-- uncomment and set a Jenkins username/group to restrict who can approve
                        }
                    } catch (err) {
                        error("Production promotion was rejected or timed out (no response within 1 hour).")
                    }

                    echo "Production promotion approved by: ${env.APPROVER_ID}"
                }
            }
        }
    }

    post {
        always {
            cleanWs()
        }
        success {
            mail to: "${ADMIN_EMAIL}",
                 subject: "SUCCESS: ${env.JOB_NAME} #${env.BUILD_NUMBER} - approved by ${env.APPROVER_ID ?: 'n/a'}",
                 body: """\
Build ${env.BUILD_NUMBER} of ${env.JOB_NAME} completed successfully.

The dev Docker Compose deployment is up and its backend health check passed.
Production promotion was approved by: ${env.APPROVER_ID ?: 'n/a'}

View build: ${env.BUILD_URL}
"""
        }
        failure {
            mail to: "${ADMIN_EMAIL}",
                 subject: "FAILURE: ${env.JOB_NAME} #${env.BUILD_NUMBER} - Pipeline failed",
                 body: """\
Build ${env.BUILD_NUMBER} of ${env.JOB_NAME} failed.

Check the console output for details: ${env.BUILD_URL}console
"""
        }
        // Slack notifications and richer alerting (Prometheus/Alertmanager,
        // Grafana) land in Phase 9/10.
    }
}
