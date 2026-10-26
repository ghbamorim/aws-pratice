resource "aws_ssm_document" "docker_compose" {
  name          = "aws_pratice_install_docker_compose"
  document_type = "Command"

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Install Docker Compose plugin"

    mainSteps = [
      {
        action = "aws:runShellScript"
        name   = "installDockerCompose"

        inputs = {
          runCommand = [
            trimspace(replace(<<-SCRIPT
              set -euo pipefail

              # Wait for EC2 initialization
              cloud-init status --wait

              # Install Docker Compose plugin
              mkdir -p /usr/local/lib/docker/cli-plugins

              curl -fSL --retry 3 \
                "https://github.com/docker/compose/releases/download/v2.40.3/docker-compose-linux-$(uname -m)" \
                -o /usr/local/lib/docker/cli-plugins/docker-compose

              chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

              # Verify installation
              docker compose version
            SCRIPT
            , "\r\n", "\n"))
          ]
        }
      }
    ]
  })
}

resource "aws_ssm_association" "docker_compose" {
  name = aws_ssm_document.docker_compose.name

  targets {
    key    = "InstanceIds"
    values = [aws_instance.app.id]
  }
}
