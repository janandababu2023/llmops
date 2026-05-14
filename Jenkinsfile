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
        IMAGE_TAG      = "${env.BUILD_NUMBER}"
        EC2_HOST       = credentials('EC2_HOST')          // e.g. ubuntu@1.2.3.4
        OPENAI_API_KEY = credentials('OPENAI_API_KEY')    // Jenkins secret
        DOCKERHUB_USER = "excelr"                         // Your Docker Hub username
    }

    stages {

        stage('Checkout') {
            steps {
                // Pulls whatever branch this job is configured to track
                // (configured in Jenkins UI: Branch Specifier = */master)
                checkout scm
                echo "Building branch: ${env.BRANCH_NAME ?: 'master'}"
            }
        }

        stage('Build Docker Image') {
            // Only build/deploy from master — protects against feature branches
            when {
                anyOf {
                    branch 'master'
                    expression { env.BRANCH_NAME == null }   // classic Pipeline job
                }
            }
            steps {
                sh '''
                    docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
                    docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:latest
                '''
            }
        }

        stage('Push to Docker Hub') {
            when {
                anyOf {
                    branch 'master'
                    expression { env.BRANCH_NAME == null }
                }
            }
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-creds',
                    usernameVariable: 'DH_USER',
                    passwordVariable: 'DH_PASS'
                )]) {
                    sh '''
                        echo "$DH_PASS" | docker login -u "$DH_USER" --password-stdin
                        docker tag ${IMAGE_NAME}:latest $DH_USER/${IMAGE_NAME}:latest
                        docker push $DH_USER/${IMAGE_NAME}:latest
                        docker logout
                    '''
                }
            }
        }

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
                        ssh -o StrictHostKeyChecking=no $EC2_HOST "
                            docker pull ${DOCKERHUB_USER}/${IMAGE_NAME}:latest &&
                            docker stop llm-rag || true &&
                            docker rm   llm-rag || true &&
                            docker run -d \
                                --name llm-rag \
                                -p 8000:8000 \
                                -e OPENAI_API_KEY='${OPENAI_API_KEY}' \
                                --restart unless-stopped \
                                ${DOCKERHUB_USER}/${IMAGE_NAME}:latest
                        "
                    '''
                }
            }
        }
    }

    post {
        success { echo "✅ Deployed build #${env.BUILD_NUMBER} successfully" }
        failure { echo "❌ Build #${env.BUILD_NUMBER} failed — check logs" }
        always  { sh 'docker image prune -f || true' }
    }
}

