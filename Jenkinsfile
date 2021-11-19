#!/usr/bin/env groovy

pipeline {
    agent any
    tools {
        maven 'maven3'
    }
    environment {
        RELEASE_NAME="webchat"
        DOCKER_REGISTRY="docker.ehsan.cf"
        K8S_DEPLOYMENT_NAME="webchat"
        CHART_NAME="webchat"
        REPO_NAME="nexus"
        K8S_PROD_NAMESPACE="prod"
        K8S_CONFIG="/opt/kubeconfig/config"
        HELM_REPO="https://nexus.ehsan.cf/repository/helm-hosted/"
    }
    stages {
        stage('increment version') {
            steps {
                script {
                    echo 'incrementing app version...'
                    sh 'mvn build-helper:parse-version versions:set \
                       -DnewVersion=\\\${parsedVersion.majorVersion}.\\\${parsedVersion.minorVersion}.\\\${parsedVersion.nextIncrementalVersion} \
                        versions:commit'
                    def matcher = readFile('pom.xml') =~ '<version>(.+)</version>'
                    def version = matcher[0][1]
                    env.IMAGE_VERSION = "$version-$BUILD_NUMBER"
                }
            }
        }
        stage('build app') {
            steps {
                script {
                    echo "building the application..."
                    sh 'mvn clean package'
                }
            }
        }
        stage('build image') {
            steps {
                script {
                    echo "building the docker image..."
                    withCredentials([usernamePassword(credentialsId: 'nexus-repo', passwordVariable: 'PWD', usernameVariable: 'USER')]) {
                        sh "docker build -t ${DOCKER_REGISTRY}/${RELEASE_NAME}:${IMAGE_VERSION} ."
                        sh "echo $PWD | docker login ${DOCKER_REGISTRY} -u $USER --password-stdin"
                        sh "docker push ${DOCKER_REGISTRY}/${RELEASE_NAME}:${IMAGE_VERSION}"
                    }
                }
            }
        }
        stage('Pushing the helm chart') {
            steps {
                script {
                    withCredentials([usernamePassword(credentialsId: 'nexus-repo', passwordVariable: 'PWD', usernameVariable: 'USER')]) {
                        sh """
                            cd ./chart/${CHART_NAME}
                            helm --kubeconfig ${K8S_CONFIG} dependency update ./
                            version="${IMAGE_VERSION}" yq e -i '.version = env(version)' Chart.yaml
                            version="${IMAGE_VERSION}" yq e -i '.appVersion = env(version)' Chart.yaml
                            version="${IMAGE_VERSION}" yq e -i '.image.tag = env(version)' values.yaml
                            helm package ./
                            curl -u $USER:$PWD ${HELM_REPO} --upload-file ${CHART_NAME}-${IMAGE_VERSION}.tgz
                            rm -rf ./${CHART_NAME}-${IMAGE_VERSION}.tgz
                            sleep 1
                        """
                    }
                }
            }
        }
        stage('Deploy on Kubernetes') {
            steps {
                script {
                   sh '''
                       helm repo update
                       helm --kubeconfig ${K8S_CONFIG} upgrade -i ${K8S_DEPLOYMENT_NAME} -n ${K8S_PROD_NAMESPACE} --create-namespace \
                         ${REPO_NAME}/${CHART_NAME} --version ${IMAGE_VERSION} --set image.tag=${IMAGE_VERSION}
                       sleep 1
                   '''
               }
            }
        }
        stage('commit version update') {
            steps {
                script {
                    withCredentials([usernamePassword(credentialsId: 'github-repo', passwordVariable: 'PWD', usernameVariable: 'USER')]) {
                        sh 'git config --global user.email "ehsanhedayatpour@gmail.com"'
                        sh 'git config --global user.name "ehsanhedayatpour"'
                        sh "git remote set-url origin https://${USER}:${PWD}@github.com/ehsanhedayatpour/webchat.git"
                        sh 'git add .'
                        sh 'git commit -m "ci: version bump"'
                        sh 'git push origin HEAD:master'
                    }
                }
            }
        }
    }
}
