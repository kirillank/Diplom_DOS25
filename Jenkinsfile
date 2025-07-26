def waitForRollout(String kind, String name, String ns, String to='600s') {
    sh "echo '⏳ waiting for ${kind}/${name} in namespace ${ns}' && " +
       "kubectl -n ${ns} rollout status ${kind}/${name} --timeout=${to}"
}

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
            steps {
                sh "${MVN} validate"
            }
        }

        stage('Build') {
            steps {
                sh "${MVN} clean package -DskipTests"
            }
        }

        stage('Test') {
            steps {
                sh "${MVN} test"
            }
        }

        stage('Archive Artifact') {
            steps {
                archiveArtifacts artifacts: 'app/target/*.jar', fingerprint: true
            }
        }

        stage('Build & Push Image') {
            steps {
                script {
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
                        env.IMAGE = IMAGE
                    }
                }
            }
        }

        stage('Deploy Monitoring') {
            when { branch 'main' }
            agent {
                kubernetes {
                    label 'kubectl'
                    defaultContainer 'kubectl'
                }
            }
            steps {
                sh 'kubectl apply -k k8s-manifests/monitoring/'
                parallel(
                    "prometheus":    { waitForRollout('deployment', 'prometheus',   'monitoring') },
                    "alertmanager":  { waitForRollout('deployment', 'alertmanager', 'monitoring') },
                    "grafana":       { waitForRollout('deployment', 'grafana',      'monitoring') },
                    "node-exporter": { waitForRollout('daemonset',  'node-exporter','monitoring') }
                )
            }
        }

        stage('Deploy Logging') {
            when { branch 'main' }
            agent {
                kubernetes {
                    label 'kubectl'
                    defaultContainer 'kubectl'
                }
            }
            steps {
                sh 'chmod +x k8s-manifests/logging/install_elk.sh'
                sh 'k8s-manifests/logging/install_elk.sh'

                parallel(
                    "elasticsearch": { waitForRollout('statefulset', 'elasticsearch-master', 'elasticsearch') },
                    "logstash":      { waitForRollout('statefulset', 'logstash-logstash',    'elasticsearch') },
                    "filebeat":      { waitForRollout('daemonset',  'filebeat-filebeat',    'elasticsearch') },
                    "kibana":        { waitForRollout('deployment', 'kibana-kibana',        'elasticsearch') }
                )
            }
        }

        stage('Deploy Application') {
            when { branch 'main' }
            agent {
                kubernetes {
                    label 'kubectl'
                    defaultContainer 'kubectl'
                }
            }
            steps {
                sh """
                  cd k8s-manifests/app
                  kustomize edit set image IMAGE_PLACEHOLDER=${IMAGE}
                """
                sh 'kubectl apply -k k8s-manifests/app/'
            }
        }
    }

    post {
        success {
            echo "✅ All components deployed successfully: ${IMAGE}"
        }
        failure {
            echo "❌ Deployment failed. Check the logs above."
        }
    }
}

