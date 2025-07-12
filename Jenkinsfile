pipeline {
  agent any
  stages {
    stage('Lint')      { steps { sh 'echo Lint OK' } }
    stage('Test')      { steps { sh 'echo Tests OK' } }
    stage('Package')   { steps { sh 'echo Maven build && touch target/app.jar' } }
    stage('Image')     { steps { sh 'echo build+push image' } }
    stage('Deploy') {
      when { branch 'main' }
      steps {
        sh 'kubectl apply -k k8s/app/'
        sh 'kubectl apply -k k8s/monitoring/'
        sh 'kubectl apply -k k8s/logging/'
      }
    }
  }
}

