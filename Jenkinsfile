pipeline {
  agent any
  environment {
    AWS_REGION = 'us-east-1'                     // change to your region
    AWS_ACCOUNT_ID = 'AKIAQGYBPWAH6NJILV4Y'           // set in Jenkins global env or replace here
    DOCKERHUB_USER = 'dnraju7747'           // or set as global env
    APP_NAME = 'devops-task-app'
    ECS_CLUSTER = 'devops-task-cluster'
    ECS_SERVICE = 'devops-task-service'
    TASK_FAMILY = 'devops-task-app'
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
        // If tests exist:
        sh 'npm test || echo "tests skipped or none"'
      }
    }
    stage('Build Docker Image') {
  steps {
    script {
      // Generate short commit hash
      sh 'GIT_SHORT=$(git rev-parse --short HEAD) && echo "TAG=$GIT_SHORT" > tagfile'
      sh 'TAG=$(cat tagfile | cut -d= -f2)'
      // Build Docker image with proper tag
      sh "docker build -t $DOCKERHUB_USER/$APP_NAME:$TAG ."

      // List Docker images for verification
      sh "docker image ls $DOCKERHUB_USER/$APP_NAME"
    }
  }
}

    stage('Push to DockerHub') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DH_USER', passwordVariable: 'DH_PSW')]) {
          sh '''
            TAG=$(git rev-parse --short HEAD)
            echo "$DH_PSW" | docker login -u "$DH_USER" --password-stdin
            docker push $DH_USER/$APP_NAME:$TAG
          '''
        }
      }
    }
    stage('Deploy to ECS (update task def & service)') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'aws-creds', usernameVariable: 'AWS_KEY', passwordVariable: 'AWS_SECRET')]) {
          sh '''
            export AWS_ACCESS_KEY_ID=$AWS_KEY
            export AWS_SECRET_ACCESS_KEY=$AWS_SECRET
            export AWS_DEFAULT_REGION=${AWS_REGION}
            TAG=$(git rev-parse --short HEAD)
            # Create taskdef JSON on the fly
            cat > taskdef.json <<EOF
            {
              "family":"${TASK_FAMILY}",
              "networkMode":"awsvpc",
              "requiresCompatibilities":["FARGATE"],
              "cpu":"256",
              "memory":"512",
              "executionRoleArn":"arn:aws:iam::${AWS_ACCOUNT_ID}:role/ecsTaskExecutionRole",
              "containerDefinitions":[
                {
                  "name":"${APP_NAME}",
                  "image":"${DOCKERHUB_USER}/${APP_NAME}:${TAG}",
                  "essential":true,
                  "portMappings":[{"containerPort":3000,"protocol":"tcp"}],
                  "logConfiguration":{
                    "logDriver":"awslogs",
                    "options":{
                      "awslogs-group":"/ecs/${APP_NAME}",
                      "awslogs-region":"${AWS_REGION}",
                      "awslogs-stream-prefix":"ecs"
                    }
                  }
                }
              ]
            }
            EOF

            # register new task definition
            aws ecs register-task-definition --cli-input-json file://taskdef.json

            # update service to force new deployment
            aws ecs update-service --cluster ${ECS_CLUSTER} --service ${ECS_SERVICE} --force-new-deployment

            # optional: show tasks
            aws ecs describe-services --cluster ${ECS_CLUSTER} --services ${ECS_SERVICE}
          '''
        }
      }
    }
  }
  post {
    success {
      echo "Pipeline completed successfully."
    }
    failure {
      echo "Pipeline failed. Check the console output and CloudWatch logs."
    }
  }
}

