pipeline {
  agent any

  tools {
    jdk 'jdk17'
  }

  environment {
    MVN   = "./app/mvnw -f app/pom.xml"
  }

  options {
    timeout(time: 30, unit: 'MINUTES')
  }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Lint') {
      steps { sh "${MVN} validate" }
    }

    stage('Build') {
      steps { sh "${MVN} clean package -DskipTests" }
    }

    stage('Test') {
      steps { sh "${MVN} test" }
    }

    stage('Archive Artifact') {
      steps {
        archiveArtifacts artifacts: 'app/target/*.jar', fingerprint: true
      }
    }

    stage('Build & Push Image') {
      steps {
        withCredentials([usernamePassword(
          credentialsId: 'dockerhub-cred',
          usernameVariable: 'DOCKERHUB_USERNAME',
          passwordVariable: 'DOCKERHUB_TOKEN'
        )]) {
	  def IMAGE = "docker.io/${DOCKERHUB_USERNAME}/spring-petclinic:${GIT_COMMIT.substring(0,7)}"
          sh """
            ${MVN} compile jib:build \
              -Dimage=${IMAGE} \
              -Djib.to.auth.username=\$DOCKERHUB_USERNAME \
              -Djib.to.auth.password=\$DOCKERHUB_TOKEN
          """
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
          sh 'kubectl apply -k k8s-manifests/app/'
          sh 'kubectl apply -k k8s-manifests/monitoring/'
          sh 'kubectl apply -k k8s-manifests/logging/'
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

