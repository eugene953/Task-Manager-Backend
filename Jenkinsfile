pipeline {
    agent any

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timestamps()
        disableConcurrentBuilds()
    }

    environment {
        // ====================================================================
        // GCP & Registry Configuration (Override via Jenkins environment if needed)
        // ====================================================================
        GCP_PROJECT_ID           = "${env.GCP_PROJECT_ID ?: 'cova-taskflow-project'}"
        GCP_REGION               = "${env.GCP_REGION ?: 'europe-west1'}"
        GCP_SA_KEY_CREDENTIAL_ID = 'gcp-sa-key' // Jenkins Secret File credential ID
        ARTIFACT_REPO            = 'taskflow'
        SERVICE_NAME             = 'task-manager-api'

        // Registry Host & Image Name
        REGISTRY_HOST            = "${GCP_REGION}-docker.pkg.dev"
        IMAGE_NAME               = "${REGISTRY_HOST}/${GCP_PROJECT_ID}/${ARTIFACT_REPO}/${SERVICE_NAME}"
        IMAGE_TAG                = "${env.BUILD_NUMBER ?: 'latest'}"
    }

    stages {
        // ====================================================================
        // 1. Checkout Repository
        // ====================================================================
        stage('Checkout') {
            steps {
                checkout scm
                echo "Triggered backend build #${env.BUILD_NUMBER} on branch ${env.BRANCH_NAME ?: 'main'}"
            }
        }

        // ====================================================================
        // 2. Automated Tests & Compilation
        // ====================================================================
        stage('Test & Build (Maven)') {
            steps {
                echo "Running backend unit and integration tests..."
                sh '''
                    chmod +x ./mvnw
                    ./mvnw clean test
                '''
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: 'target/surefire-reports/*.xml'
                }
            }
        }

        // ====================================================================
        // 3. Build Multi-Stage Production Docker Image
        // ====================================================================
        stage('Build Docker Image') {
            steps {
                echo "Building backend production Docker image..."
                sh """
                    docker build -t ${IMAGE_NAME}:${IMAGE_TAG} \
                                 -t ${IMAGE_NAME}:latest \
                                 .
                """
            }
        }

        // ====================================================================
        // 4. Authenticate & Push Image to GCP Artifact Registry
        // ====================================================================
        stage('Push to GCP Artifact Registry') {
            steps {
                withCredentials([file(credentialsId: "${GCP_SA_KEY_CREDENTIAL_ID}", variable: 'GCP_KEY_FILE')]) {
                    sh """
                        # Authenticate gcloud with Service Account
                        gcloud auth activate-service-account --key-file=\${GCP_KEY_FILE}
                        gcloud config set project ${GCP_PROJECT_ID}

                        # Configure Docker helper for GCP Artifact Registry
                        gcloud auth configure-docker ${REGISTRY_HOST} --quiet

                        # Ensure artifact repository exists (idempotent)
                        gcloud artifacts repositories describe ${ARTIFACT_REPO} \
                            --location=${GCP_REGION} >/dev/null 2>&1 || \
                        gcloud artifacts repositories create ${ARTIFACT_REPO} \
                            --repository-format=docker \
                            --location=${GCP_REGION} \
                            --description="TaskFlow Docker Images"

                        echo "Pushing backend image..."
                        docker push ${IMAGE_NAME}:${IMAGE_TAG}
                        docker push ${IMAGE_NAME}:latest
                    """
                }
            }
        }

        // ====================================================================
        // 5. Deploy Backend Service to GCP Cloud Run
        // ====================================================================
        stage('Deploy to Cloud Run') {
            steps {
                withCredentials([
                    file(credentialsId: "${GCP_SA_KEY_CREDENTIAL_ID}", variable: 'GCP_KEY_FILE'),
                    string(credentialsId: 'supabase-db-url', variable: 'DB_URL'),
                    string(credentialsId: 'supabase-db-user', variable: 'DB_USER'),
                    string(credentialsId: 'supabase-db-password', variable: 'DB_PASSWORD'),
                    string(credentialsId: 'jwt-secret-key', variable: 'JWT_SECRET')
                ]) {
                    sh """
                        gcloud auth activate-service-account --key-file=\${GCP_KEY_FILE}
                        gcloud config set project ${GCP_PROJECT_ID}

                        echo "Deploying ${SERVICE_NAME} to Cloud Run..."
                        gcloud run deploy ${SERVICE_NAME} \
                            --image=${IMAGE_NAME}:${IMAGE_TAG} \
                            --platform=managed \
                            --region=${GCP_REGION} \
                            --allow-unauthenticated \
                            --port=5000 \
                            --cpu=1 \
                            --memory=512Mi \
                            --min-instances=0 \
                            --max-instances=3 \
                            --set-env-vars="SPRING_DATASOURCE_URL=\${DB_URL},SPRING_DATASOURCE_USERNAME=\${DB_USER},SPRING_DATASOURCE_PASSWORD=\${DB_PASSWORD},APPLICATION_SECURITY_JWT_SECRET_KEY=\${JWT_SECRET},CORS_ALLOWED_ORIGINS=http://localhost:*,https://*.run.app"

                        BACKEND_URL=\$(gcloud run services describe ${SERVICE_NAME} \
                            --platform=managed \
                            --region=${GCP_REGION} \
                            --format='value(status.url)')

                        echo "==============================================================="
                        echo "🚀 BACKEND DEPLOYED SUCCESSFULLY!"
                        echo "Cloud Run URL : \${BACKEND_URL}"
                        echo "API Endpoint  : \${BACKEND_URL}/api"
                        echo "==============================================================="
                    """
                }
            }
        }
    }

    // ====================================================================
    // Post-Build Notifications & Cleanup
    // ====================================================================
    post {
        success {
            echo "Backend pipeline succeeded! API service is running on GCP Cloud Run."
        }
        failure {
            echo "Backend pipeline failed! Please inspect logs."
        }
        cleanup {
            sh 'docker image prune -f || true'
        }
    }
}
