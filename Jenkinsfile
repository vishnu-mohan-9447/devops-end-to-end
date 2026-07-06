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

        stage('Quality Gate') {
            steps {
                timeout(time: 10, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: false 
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
    }

    post {
        always {
            cleanWs()
        }
        // Slack/email notifications land in Phase 10 (Alerting)
    }
}
