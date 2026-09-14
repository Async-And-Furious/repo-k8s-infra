# Pré-requisitos de configuração da AWS

Este runbook anteriormente mantinha uma cópia, por repositório, do handoff de
configuração da conta. As quatro cópias divergiram entre si e todas descreviam
infraestrutura que não existe mais (um provedor OIDC do GitHub e uma IAM role
criada manualmente, um bucket `tc3-terraform-state` provisionado manualmente
com uma tabela DynamoDB `tc3-terraform-locks`, workspaces do HCP Terraform e
`TF_API_TOKEN`, e um gate de aprovação `hml-apply`).

Os documentos canônicos e atuais vivem na raiz do workspace:

- `HANDOFF-AWS-SETUP.md` — o que uma pessoa configura, por caminho (AWS
  Academy ou uma conta real com OIDC), e o que o pipeline provisiona para si
  mesmo.
- `AWS_HML_RUNBOOK.md` — o procedimento operacional, os gates e o uso do
  `scripts/aws_lab.py`.

Resumo para este repositório: o estado do Terraform fica no S3, no bucket
`tc3-tfstate-<account-id>`, com locking nativo do S3, feito via bootstrap pelo
`.github/scripts/bootstrap-backend.sh` dentro do workflow. Nada do backend de
estado é provisionado manualmente. As credenciais são os valores da sessão do
AWS Academy, rotacionados para secrets com escopo de repositório no início de
cada sessão de laboratório.
