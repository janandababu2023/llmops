// ------------------------------------------------------------
// Jenkinsfile — CI/CD pipeline for LLM RAG Project
// Trigger: GitHub webhook on push to master
// Flow:    Checkout → Build Docker image → Push to Docker Hub
//          → SSH to EC2 → Pull image → Restart container
// ------------------------------------------------------------
pipeline {
    agent any

    environment {
        IMAGE_NAME     = "llm-rag-app"
        IMAGE_TAG      = "${BUILD_NUMBER}"                // FIX 1: was ${env.BUILD_NUMBER}
        DOCKERHUB_USER = "janandababu2023"
        EC2_HOST       = credentials('EC2_HOST')
        OPENAI_API_KEY = credentials('OPENAI_API_KEY')
    }

    stages {

        // --------------------------------------------------
        // STAGE 1 : Checkout code from GitHub
        // --------------------------------------------------
        stage('Checkout') {
            steps {
                checkout scm
                echo "✅ Checked out branch: ${env.BRANCH_NAME ?: 'master'}"
            }
        }

        // --------------------------------------------------
        // STAGE 2 : Build Docker image
        // FIX 2: build directly with full name
        // janandababu2023/llm-rag-app:tag
        // so push stage works without re-tagging
        // --------------------------------------------------
        stage('Build Docker Image') {
            when {
                anyOf {
                    branch 'master'
                    expression { env.BRANCH_NAME == null }
                }
            }
            steps {
                sh '''
                    echo "🔨 Building: ${DOCKERHUB_USER}/${IMAGE_NAME}:${IMAGE_TAG}"

                    docker build \
                        -t ${DOCKERHUB_USER}/${IMAGE_NAME}:${IMAGE_TAG} \
                        -t ${DOCKERHUB_USER}/${IMAGE_NAME}:latest \
                        .

                    echo "✅ Build complete"
                '''
            }
        }

        // --------------------------------------------------
        // STAGE 3 : Push image to Docker Hub
        // --------------------------------------------------
        stage('Push to Docker Hub') {
            when {
                anyOf {
                    branch 'master'
                    expression { env.BRANCH_NAME == null }
                }
            }
            steps {
                withCredentials([usernamePassword(
                    credentialsId : 'dockerhub-creds',
                    usernameVariable: 'DH_USER',
                    passwordVariable: 'DH_PASS'
                )]) {
                    sh '''
                        echo "📦 Logging in to Docker Hub..."
                        echo "$DH_PASS" | docker login -u "$DH_USER" --password-stdin

                        echo "📦 Pushing images..."
                        docker push ${DOCKERHUB_USER}/${IMAGE_NAME}:${IMAGE_TAG}
                        docker push ${DOCKERHUB_USER}/${IMAGE_NAME}:latest

                        docker logout
                        echo "✅ Push complete"
                    '''
                }
            }
        }

        // --------------------------------------------------
        // STAGE 4 : Deploy to EC2
        // pulls latest image and restarts container
        // --------------------------------------------------
        stage('Deploy to EC2') {
            when {
                anyOf {
                    branch 'master'
                    expression { env.BRANCH_NAME == null }
                }
            }
            steps {
                sshagent(credentials: ['ec2-ssh-key']) {
                    sh '''
                        echo "🚀 Deploying to EC2: $EC2_HOST"

                        ssh -o StrictHostKeyChecking=no $EC2_HOST "

                            echo '--- Pulling latest image ---'
                            docker pull ${DOCKERHUB_USER}/${IMAGE_NAME}:latest

                            echo '--- Stopping old container ---'
                            docker stop llm-rag || true
                            docker rm   llm-rag || true

                            echo '--- Starting new container ---'
                            docker run -d \
                                --name llm-rag \
                                --restart unless-stopped \
                                -p 8000:8000 \
                                -e OPENAI_API_KEY=${OPENAI_API_KEY} \
                                ${DOCKERHUB_USER}/${IMAGE_NAME}:latest

                            echo '--- Container status ---'
                            docker ps | grep llm-rag

                            echo '--- Cleaning old images ---'
                            docker image prune -f
                        "

                        echo "✅ Deployment complete"
                    '''
                }
            }
        }
    }

    // --------------------------------------------------
    // POST ACTIONS
    // --------------------------------------------------
    post {
        success {
            echo "✅ Build #${BUILD_NUMBER} deployed successfully"
        }
        failure {
            echo "❌ Build #${BUILD_NUMBER} failed — check logs above"
        }
        always {
            sh 'docker image prune -f || true'
        }
    }
}
