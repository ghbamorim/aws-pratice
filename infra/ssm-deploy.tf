resource "aws_ssm_document" "deploy" {
  name            = "pratice-deploy"
  document_type   = "Command"
  document_format = "YAML"

  content = yamlencode({
    schemaVersion = "2.2"
    description   = "Deploy da aplicação via Docker Compose"

    parameters = {
      version = {
        type           = "String"
        description    = "Tag da release"
        allowedPattern = "^v[0-9]+\\.[0-9]+\\.[0-9]+$"
      }
    }

    mainSteps = [{
      action = "aws:runShellScript"
      name   = "deploy"
      inputs = {
        runCommand = [
          "echo 'Deploy solicitado'",
          "docker --version",
          "docker compose version"
        ]
      }
    }]
  })
}