pipeline {
  agent { label 'MaverickServer' }

  environment {
	AWS_CREDS_ID = "${env.AWS_CREDENTIALS_ID}"
    GITHUB_CREDS = "${env.GITHUB_CREDENTIALS_ID}"
    PRIVATE_KEY_ID = "${env.PRIVATE_KEY_ID}"
    DOCKER_IMAGE = 'wealliam/maverick-reg'
    HOST_PORT = '80'
    CONTAINER_PORT = '10000'
  }

  stages {

    stage('Clone App and Infra Repos') {
      steps {
        dir('app') {
          checkout([
            $class: 'GitSCM',
            branches: [[name: '*/master']],
            userRemoteConfigs: [[
              url: 'https://github.com/weal-liam/aws-hosting-project.git',
              credentialsId: "${GITHUB_CREDS}"
            ]]
          ])
        }
        dir('infra') {
          checkout([
            $class: 'GitSCM',
            branches: [[name: '*/main']],
            userRemoteConfigs: [[
              url: 'https://github.com/weal-liam/MaverickServer-IAC-Config.git',
              credentialsId: "${GITHUB_CREDS}"
            ]]
          ])
        }
      }
    }

  stage('Terraform Init & Apply') {
  steps {
    script {
      withCredentials([
        [$class: 'AmazonWebServicesCredentialsBinding',
          credentialsId: "${AWS_CREDS_ID}",
          accessKeyVariable: 'AWS_ACCESS_KEY_ID',
          secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']
      ]) {
          dir('infra/terraform') {
            sh '''
              terraform init
              terraform apply -auto-approve
              terraform output -json > ../../kube-output.json
              ls -l ../../kube-output.json || true
              cat ../../kube-output.json || true
            '''
          }
      }
    }
  }
}
    
        stage('Provision Tools on EC2') {
          steps {
            dir('infra/ansible') {
              sshagent(["$PRIVATE_KEY_ID"]) {
                script {
                  def output = readJSON file: '../../kube-output.json'
                  def instance_ip = output.maverick_server_public_ip.value
    
                  // Dynamically create inventory.ini with the actual IP
                  writeFile file: 'inventory.ini', text: """
[web]
${instance_ip} ansible_user=ubuntu
"""
                  sh '''
                    export ANSIBLE_HOST_KEY_CHECKING=False
                    ansible-playbook -i inventory.ini playbook_initial.yml
                  '''
                }
              }
            }
          }
        }

/*    stage('Configure kubectl') {
      steps {
        script {
          def output = readJSON file: 'kube-output.json'
          def token = output.cluster_token.value
          def cert = output.cluster_CA.value
          def ec2_endpoint = output.kubeconfig.value

          writeFile file: 'kubeconfig.yml', text: """
apiVersion: v1
clusters:
- cluster:
    server: ${ec2_endpoint}
    certificate-authority-data: ${cert}
  name: weal-eks-cluster
contexts:
- context:
    cluster: weal-eks-cluster
    user: admin
  name: custom-context
current-context: custom-context
kind: Config
preferences: {}
users:
- name: admin
  user:
    exec:
      apiVersion: "client.authentication.k8s.io/v1beta1"
      command: "aws"
      args:
        - "eks"
        - "get-token"
        - "--cluster-name"
        - "weal-eks-cluster"
"""
        }
      }
    }
*/
    stage('Build Docker Image') {
      steps {
        dir('app') {
          sh 'sudo usermod -aG docker jenkins'
          sh 'docker build -t mav-app:latest .'
        }
      }
    }

    stage('Push to Docker Desktop') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
          sh '''
            echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin
            docker tag mav-app:latest wealliam/maverick-reg
            docker push wealliam/maverick-reg
          '''
        }
      }
    }

    stage('Run Ansible Playbook') {
      steps {
        dir('infra/ansible') {
          sshagent(["$PRIVATE_KEY_ID"]) {
            script {
              def output = readJSON file: '../../kube-output.json'
              def instance_ip = output.maverick_server_public_ip.value

              // Dynamically create inventory.ini with the actual IP
              writeFile file: 'inventory.ini', text: """
[web]
${instance_ip} ansible_user=ubuntu
"""

              sh 'ansible-playbook -i inventory.ini playbook.yml --extra-vars "docker_image=${DOCKER_IMAGE} host_port=${HOST_PORT} container_port=${CONTAINER_PORT}"'
            }
          }
        }
      }
    }

/*    stage('Deploy to EKS') {
      steps {
        sh '''
          set -e
          KUBECONFIG=kubeconfig.yml kubectl apply -f app/app/deployment.yaml || \
          KUBECONFIG=kubeconfig.yml kubectl apply -f app/app/deployment.yaml --validate=false

          KUBECONFIG=kubeconfig.yml kubectl apply -f app/app/service.yaml || \
          KUBECONFIG=kubeconfig.yml kubectl apply -f app/app/service.yaml --validate=false

          KUBECONFIG=kubeconfig.yml kubectl apply -f app/ngnix/ingress.yaml || \
          KUBECONFIG=kubeconfig.yml kubectl apply -f app/ngnix/ingress.yaml --validate=false
          KUBECONFIG=kubeconfig.yml kubectl get nodes -o wide
          KUBECONFIG=kubeconfig.yml kubectl get pods -o wide
          KUBECONFIG=kubeconfig.yml kubectl get ns
          KUBECONFIG=kubeconfig.yml kubectl get svc -o wide
          KUBECONFIG=kubeconfig.yml kubectl describe pod maverick-code-65c4c6f4f8-gxvmr
        '''
      }
    }
*/
    stage('Cleanup Docker') {
      steps {
        script {
          echo "Cleaning up Docker resources..."
          sh '''
            docker ps -a --filter "ancestor=mav-app:latest" -q | xargs -r docker rm -f
            docker ps -a --filter "ancestor=wealliam/maverick-reg" -q | xargs -r docker rm -f
            docker rmi -f mav-app:latest || true
            docker rmi -f wealliam/maverick-reg || true
            docker container prune -f
            docker image prune -f --filter "until=24h"
            docker volume prune -f
            docker network prune -f
          '''
        }
      }
    }

    stage('Cleanup Sensitive Files') {
      steps {
        script {
          echo "Removing temporary files..."
          //sh 'rm -f kubeconfig.yml || true'
          sh 'rm -f kube-output.json || true'
        }
      }
    }

  }

  post {
    success {
      echo "Deployment successful!"
    }
    failure {
      echo "Pipeline failed. Check logs for details."
    }
  }
}
