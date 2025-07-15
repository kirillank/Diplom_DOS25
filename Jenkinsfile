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
    stage('Archive Artifact') {
      steps {
        archiveArtifacts artifacts: 'app/target/*.jar', fingerprint: true
        stash name: 'app', includes: 'app/**'
      }
    }

    stage('Build & Push Image') {
      agent {
        kubernetes {
          inheritFrom 'kaniko'
          defaultContainer 'kaniko'
        }
      }
      steps {
        unstash 'app'
        container('kaniko') {
            sh 'ls -la /workspace/app'              
            sh 'cat /workspace/app/Dockerfile' 
       
          sh '''
            /kaniko/executor \
              --context=dir:/workspace/app \
              --dockerfile=app/Dockerfile \
              --destination=${IMAGE} \
              --oci-layout-path=/dev/null
              --verbosity=debug
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

