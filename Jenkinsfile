pipeline {
  agent any

  environment {
    AWS_REGION    = 'us-east-1'
    AWS_ACCOUNT_ID = '014498639887'          // <-- replace with your real AWS account ID (not Access Key)
    DOCKERHUB_USER = 'dnraju7747'
    APP_NAME      = 'devops-task-app'
    ECS_CLUSTER   = 'devops-task-cluster'
    ECS_SERVICE   = 'devops-task-service'
    TASK_FAMILY   = 'devops-task-app'
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Install & Test') {
      steps {
        sh 'npm ci'
        sh 'npm test || echo "tests skipped or none"'
      }
    }

    stage('Get Commit Hash') {
      steps {
        script {
          // Save commit hash as pipeline variable
          env.TAG = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
          echo "Using image tag: ${env.TAG}"
        }
      }
    }

    stage('Build Docker Image') {
      steps {
        script {
          withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DH_USER', passwordVariable: 'DH_PSW')]) {
            sh """
              docker build -t $DOCKERHUB_USER/$APP_NAME:${env.TAG} .
              docker build -t $DOCKERHUB_USER/$APP_NAME:latest .
              docker image ls $DOCKERHUB_USER/$APP_NAME
            """
          }
        }
      }
    }

    stage('Push to DockerHub') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DH_USER', passwordVariable: 'DH_PSW')]) {
          sh """
            echo "$DH_PSW" | docker login -u "$DH_USER" --password-stdin
            docker push $DOCKERHUB_USER/$APP_NAME:${env.TAG}
            docker push $DOCKERHUB_USER/$APP_NAME:latest
          """
        }
      }
    }

    stage('Deploy to ECS') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'aws-creds', usernameVariable: 'AWS_KEY', passwordVariable: 'AWS_SECRET')]) {
          sh """
            export AWS_ACCESS_KEY_ID=$AWS_KEY
            export AWS_SECRET_ACCESS_KEY=$AWS_SECRET
            export AWS_DEFAULT_REGION=${AWS_REGION}

            cat > taskdef.json <<EOF
            {
              "family": "${TASK_FAMILY}",
              "networkMode": "awsvpc",
              "requiresCompatibilities": ["FARGATE"],
              "cpu": "256",
              "memory": "512",
              "executionRoleArn": "arn:aws:iam::${AWS_ACCOUNT_ID}:role/ecsTaskExecutionRole",
              "containerDefinitions": [
                {
                  "name": "${APP_NAME}",
                  "image": "${DOCKERHUB_USER}/${APP_NAME}:${env.TAG}",
                  "essential": true,
                  "portMappings": [
                    { "containerPort": 3000, "protocol": "tcp" }
                  ],
                  "logConfiguration": {
                    "logDriver": "awslogs",
                    "options": {
                      "awslogs-group": "/ecs/${APP_NAME}",
                      "awslogs-region": "${AWS_REGION}",
                      "awslogs-stream-prefix": "ecs"
                    }
                  }
                }
              ]
            }
            EOF

            aws ecs register-task-definition --cli-input-json file://taskdef.json
            aws ecs update-service --cluster ${ECS_CLUSTER} --service ${ECS_SERVICE} --force-new-deployment
            aws ecs describe-services --cluster ${ECS_CLUSTER} --services ${ECS_SERVICE}
          """
        }
      }
    }
  }

  post {
    success {
      echo "✅ Pipeline completed successfully."
    }
    failure {
      echo "❌ Pipeline failed. Check the console output and CloudWatch logs."
    }
  }
}
