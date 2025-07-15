pipeline {
  agent any

  tools {
    jdk 'jdk17'
  }

  environment {
    MVN = "./app/mvnw -f app/pom.xml"
    IMAGE = "docker.io/${DOCKERHUB_USERNAME}/spring-petclinic:${GIT_COMMIT.substring(0,7)}"
  }

  options {
    timeout(time: 30, unit: 'MINUTES')
  }

  stages {
    stage('Checkout')         { steps { checkout scm } }
    stage('Lint')             { steps { sh "${MVN} validate" } }
    stage('Build')            { steps { sh "${MVN} clean package -DskipTests" } }
    stage('Test')             { steps { sh "${MVN} test" } }
    stage('Archive Artifact') { steps { archiveArtifacts artifacts: 'app/target/*.jar', fingerprint: true } }

    stage('Build & Push Image') {
      agent {
        kubernetes {
          inheritFrom 'kaniko'
          defaultContainer 'kaniko'
        }
      }
      environment {
        GOOGLE_APPLICATION_CREDENTIALS = '/kaniko/.docker/config.json'
      }
      steps {
        container('kaniko') {
          sh '''
            /kaniko/executor \
              --context=dir://workspace/app \
              --dockerfile=app/Dockerfile \
              --destination=${IMAGE} \
              --oci-layout-path=/dev/null
          '''
        }
      }
    }

    stage('Deploy to Kubernetes') {
      when { branch 'main' }
      steps {
        script {
          sh """
            cd k8s-manifests/app
            kustomize edit set image IMAGE_PLACEHOLDER=${IMAGE}
          """
          sh 'kubectl apply -k k8s/app/'
          sh 'kubectl apply -k k8s/monitoring/'
          sh 'kubectl apply -k k8s/logging/'
        }
      }
    }
  }

  post {
    failure {
      echo "❌ Build failed: ${BUILD_URL}"
    }
    success {
      echo "✅ Deployed: ${IMAGE}"
    }
  }
}

