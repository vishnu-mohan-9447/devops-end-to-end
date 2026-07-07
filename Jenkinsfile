// ============================================================
// Cokonet LMS - CI/CD Pipeline
// Checkout -> Build -> Tests -> Sonar -> Trivy -> Docker -> Push
// -> Deploy Dev -> Manual Approval -> Update GitOps (ArgoCD)
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
        nodejs 'node-20'
    }
    environment {
        DOCKERHUB_NAMESPACE = 'vishnumohan9447'
        DOCKERHUB_CREDS = credentials('dockerhub-creds')
        SONAR_PROJECT_KEY = 'cokonet-lms'
        IMAGE_TAG = "${env.BUILD_NUMBER}"
        APP_DIR = 'Lms-App'
        PATH = "${WORKSPACE}/bin:${env.PATH}"
        ADMIN_EMAIL = 'linuxgeeknotes@gmail.com'
        
        GITOPS_REPO_URL = 'https://github.com/vishnu-mohan-9447/lms-gitops-source.git'
        GITOPS_CREDENTIALS = 'github-pat'
    }
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        stage('Bootstrap Trivy') {
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
                            echo 'No "test" script defined in backend/package.json - skipping unit tests.'
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
                        }
                    } catch (err) {
                        error("Production promotion was rejected or timed out (no response within 1 hour).")
                    }
                    echo "Production promotion approved by: ${env.APPROVER_ID}"
                }
            }
        }

        // ====================== CD STAGE ======================
        stage('Update GitOps Repo') {
            steps {
                script {
                    def gitOpsDir = 'gitops-repo'
                    def newTag = IMAGE_TAG
                    
                    dir(gitOpsDir) {
                        withCredentials([usernamePassword(credentialsId: "${GITOPS_CREDENTIALS}",
                                                        usernameVariable: 'GIT_USER',
                                                        passwordVariable: 'GIT_TOKEN')]) {
                            
                            // Clone using credentials in URL (most reliable)
                            sh """
                                git clone https://${GIT_USER}:${GIT_TOKEN}@github.com/vishnu-mohan-9447/lms-gitops-source.git .
                                git config user.name "Jenkins CI"
                                git config user.email "linuxgeeknotes@gmail.com"
                                git checkout main
                            """
                            
                            // Update image tags - matches the image name (constant) and
                            // replaces only the tag (variable), so this works on every
                            // run regardless of whatever tag is currently deployed.
                            sh """
                                sed -i -E 's|(${DOCKERHUB_NAMESPACE}/lms-backend:)[^[:space:]]+|\\1${newTag}|' plain-manifests/backend-deployment.yaml
                                sed -i -E 's|(${DOCKERHUB_NAMESPACE}/lms-frontend:)[^[:space:]]+|\\1${newTag}|' plain-manifests/frontend-deployment.yaml
                            """
                            
                            sh """
                                echo "--- Image tag changes ---"
                                git diff plain-manifests/*.yaml || true
                                git add plain-manifests/*.yaml
                                git commit -m "Update images to tag ${newTag} (build #${env.BUILD_NUMBER})" || echo "No changes to commit"
                                git push origin main
                            """
                        }
                    }
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
                 subject: "SUCCESS: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                 body: """\
Build ${env.BUILD_NUMBER} completed successfully.
GitOps repo updated → ArgoCD should start syncing.
View build: ${env.BUILD_URL}
"""
        }
        failure {
            mail to: "${ADMIN_EMAIL}",
                 subject: "FAILURE: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                 body: """\
Build ${env.BUILD_NUMBER} failed.
Check console: ${env.BUILD_URL}console
"""
        }
    }
}
