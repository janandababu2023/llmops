// ------------------------------------------------------------
// Jenkinsfile — CI/CD pipeline for LLM RAG Project
// Trigger: GitHub webhook on push to main
// Flow:    Checkout → Build Docker image → Push (optional)
//          → SSH to EC2 → Pull image → Restart container  (50% Cloud Know AWS / AZURE / GCP)
// ------------------------------------------------------------
pipeline {
    agent any

    environment {
        IMAGE_NAME     = "llm-rag-app"
        IMAGE_TAG      = "${env.BUILD_NUMBER}"
        EC2_HOST       = credentials('EC2_HOST')          // e.g. ec2-user@1.2.3.4
        OPENAI_API_KEY = credentials('OPENAI_API_KEY')    // Jenkins secret
        // Optional: if you push to Docker Hub
        DOCKERHUB_USER = "your-dockerhub-username"
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                    docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
                    docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:latest
                '''
            }
        }

        // OPTIONAL — push image to Docker Hub so EC2 can pull it.
        // If you skip this, the "Deploy to EC2" stage below should
        // instead copy the source to EC2 and build there.
        stage('Push to Docker Hub') {
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
                    '''
                }
            }
        }

        stage('Deploy to EC2') {
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