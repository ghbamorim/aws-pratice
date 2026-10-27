
resource "aws_ssm_document" "https_setup" {
  name            = "pratice-https-setup"
  document_type   = "Command"
  document_format = "JSON"

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Configure Nginx HTTPS and Let's Encrypt"

    parameters = {
      ScriptHash = {
        type = "String"
      }
    }

    mainSteps = [
      {
        action = "aws:runShellScript"
        name   = "configureHttps"

        inputs = {
          timeoutSeconds = "900"

          runCommand = [
            "echo '${base64encode(replace(file("${path.module}/https-setup.sh"), "\r\n", "\n"))}' | base64 -d | bash"
          ]
        }
      }
    ]
  })
}

resource "aws_ssm_association" "https_setup" {
  name                = aws_ssm_document.https_setup.name
  association_name    = "pratice-https-setup"
  schedule_expression = "rate(30 minutes)"

  targets {
    key    = "InstanceIds"
    values = [aws_instance.app.id]
  }

  parameters = {
    ScriptHash = filesha256("${path.module}/https-setup.sh")
  }

  depends_on = [
    aws_eip_association.app
  ]
}
