# repo-k8s-infra

Tech Challenge Fase 3 — VPC, EKS e ECR via Terraform.

O módulo EKS também faz o bootstrap do AWS Load Balancer Controller (incluindo
sua CRD TargetGroupBinding) e do Metrics Server, com versões fixas de chart
Helm. A versão do EKS é preservada para clusters existentes por padrão; defina
`cluster_version` explicitamente quando um upgrade intencional for aprovado.
Em modo AWS Academy, o controller usa o `LabRole` já existente do node group
em vez de IRSA. A API do Kubernetes é privada por padrão; defina
`cluster_endpoint_public_access=true` somente quando necessário e forneça no
máximo 40 entradas restritas em `cluster_endpoint_public_access_cidrs`.
O node group gerenciado usa um único tipo de instância, `t3.small` por padrão
(`node_instance_types = null` no root, resolvido por `coalesce`). Evitar uma
lista de tipos impede que o EKS substitua o node group e sobreponha nós
temporariamente, o que pode exceder a quota de vCPU da conta. A escala padrão
é `desired=3`, `min=2`, `max=3`. A capacidade é SPOT em HML e ON_DEMAND em
PROD (`capacity_type` em `modules/eks/main.tf`).

## Escopo

Provisiona a rede (VPC/subnets), o cluster Kubernetes (EKS) e o registro de
containers (ECR). É consumido pelos repositórios de banco de dados,
autenticação e aplicação.

Também provisiona um ALB HTTP interno por ambiente. Seu ARN de listener, DNS
name, security group e target group de IP vazio são outputs para os
contratos de integração do Auth/API Gateway e do deployment da aplicação. O
deployment da aplicação registra os IPs dos pods nesse target group; o ALB
nunca fica exposto à internet.

Fora de escopo: regra de negócio, migrations, schema de banco de dados,
código das Lambdas.

## Validação local

```bash
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```

A validação local não inicializa nem contata o backend remoto S3. Para um
plan local de verdade, configure as credenciais AWS e siga os passos de
backend S3 abaixo.

## Pré-requisitos de bootstrap

- Terraform >= 1.11 e AWS CLI configurada para a conta alvo.
- A inicialização do provider Helm exige acesso de rede ao Terraform
  Registry; os charts Helm são buscados dos repositórios fixados durante o
  apply.
- Fora do modo Academy, o AWS Load Balancer Controller usa o role IRSA criado
  pelo Terraform (no modo Academy, o `LabRole` dos nós). O
  CLI `aws` precisa estar disponível onde quer que os recursos Helm sejam
  aplicados, porque o provider usa `aws eks get-token`.
- Não aplique até que os pré-requisitos do cluster EKS e do node group
  estejam prontos.

## State e plans do Terraform no S3

O state fica armazenado no bucket S3 qualificado por conta
`tc3-tfstate-<ACCOUNT_ID>`, sob
`repo-k8s-infra/<environment>/terraform.tfstate`. A configuração de backend
gerada habilita o lock nativo do S3 com `use_lockfile = true`; nenhuma
tabela de lock do DynamoDB é usada. Com as credenciais AWS configuradas para
a conta alvo, rode a partir da raiz do repositório:

```bash
# HML
bash .github/scripts/bootstrap-backend.sh repo-k8s-infra hml
terraform init -reconfigure -input=false -backend-config=backend.hcl
terraform plan -input=false -var=environment=hml
```

O workflow roda o mesmo bootstrap de backend para o ambiente selecionado. O
bucket é versionado, criptografado e bloqueado para acesso público.

### Modo AWS Academy/Lab

Contas Academy usam credenciais temporárias e costumam negar escritas de
IAM. Defina exatamente estas variáveis para reutilizar o `LabRole` já
existente tanto para o control plane do EKS quanto para o node group
gerenciado:

```bash
export TF_VAR_aws_academy=true
export TF_VAR_manage_iam=false
export TF_VAR_lab_role_arn="arn:aws:iam::<ACCOUNT_ID>:role/LabRole"
```

Use o ARN da conta Lab ativa; não fixe o account ID no código. O modo
Academy não cria roles IAM nem recursos OIDC/IRSA. O controller continua
instalado e usa o role de node do EKS (`LabRole`), que precisa permitir as
ações do AWS Load Balancer Controller.
O Metrics Server continua habilitado.

Quando `manage_iam=false` fora do modo Academy, um role IRSA existente do
Load Balancer Controller é obrigatório. Defina a variável do repositório
nesse caso; com `manage_iam=true`, deixá-la vazia ou sem definir preserva a
criação do role pelo Terraform:

```bash
gh variable set LOAD_BALANCER_CONTROLLER_ROLE_ARN --body "arn:aws:iam::<ACCOUNT_ID>:role/<LOAD_BALANCER_CONTROLLER_ROLE_NAME>"
```

### Contrato do load balancer da aplicação

O repositório da aplicação consome outputs do state Terraform do ambiente
correspondente:

- `internal_alb_target_group_arn` (ou o alias retrocompatível
  `application_target_group_arn`) como `spec.targetGroupARN`.
- `application_backend_port` como a porta do Service (atualmente `3000`).
- `internal_alb_listener_arn` para a integração HTTP proxy do API Gateway; a
  aplicação não cria outro ALB ou listener.

A aplicação precisa criar um Service `ClusterIP` para seus pods e aplicar um
`TargetGroupBinding` no mesmo namespace, com `spec.targetType: ip`,
`spec.targetGroupARN` definido com o output acima, e
`spec.serviceRef.name`/`spec.serviceRef.port` apontando para esse Service e
sua porta de backend. O controller registra e desregistra os IPs dos pods no
target group pré-criado. Use o output de `hml` ou `prod` do state
correspondente; nunca cruze ARNs entre ambientes.

## GitHub Actions

Pull requests rodam apenas checks de formatação e validação em
`ubuntu-latest`, sem credenciais AWS. Um push em `develop` aplica o HML; um
push em `main` gera o plan de produção e só o aplica depois que o Environment
protegido `production` aprovar o job. O disparo manual seleciona `hml` ou
`prod` e a ação `plan`, `apply`, `destroy-plan` ou `destroy`. O apply manual
de produção exige `confirm="APPLY PROD"`. Os plans são salvos como `tfplan` no
artefato da execução, e o apply usa exatamente esse plan. Operações de state
do mesmo ambiente não rodam concorrentemente.

O runner é `eks-private` por padrão, para alcançar o endpoint privado do EKS e
o provider Helm. Um disparo manual com `academy_mode=true` usa `ubuntu-latest`:
o workflow descobre o IPv4 público do runner, restringe temporariamente o
endpoint público do EKS a esse `/32` e restaura a configuração original ao
final, em passos separados para HML e para produção. Nenhum CIDR irrestrito é
usado.

Antes do bootstrap de backend ou de qualquer mudança no endpoint, o workflow
faz uma checagem somente leitura de credenciais STS e do state qualificado por
conta, e falha de forma clara quando as credenciais estão ausentes, expiradas
ou sem permissão.

### Destroy

`destroy-plan` e `destroy` estão disponíveis para HML e PROD, sempre em
disparo manual (`ci.yml` ou `down.yml`). O `destroy` exige a confirmação exata
`DESTROY HML` ou `DESTROY PROD`, cria um plan de destroy salvo e aplica
exatamente esse plan. As duas ações inspecionam o objeto de state sem criar ou
configurar o bucket; objeto ausente ou state vazio é um no-op bem-sucedido, e
nem o bucket nem o objeto de state são removidos. No Academy HML o Terraform
pode apagar o repositório ECR com as imagens (`force_delete`); nos demais
casos o ECR continua rejeitando exclusão de repositório não vazio.

### Credenciais e variáveis

Não há OIDC. O workflow usa os secrets `AWS_ACCESS_KEY_ID` e
`AWS_SECRET_ACCESS_KEY`, e inclui `AWS_SESSION_TOKEN` quando ele está presente
(sessão AWS Academy). Rotacione os três depois de cada sessão com
`gh secret set`, sem commitar nem imprimir os valores.

No modo Academy, o disparo manual expõe `academy_mode` e `lab_role_arn`; com
`academy_mode=true` o workflow define `manage_iam=false`. Alternativamente,
defina a variável `LAB_ROLE_ARN`, exportada como `TF_VAR_lab_role_arn`.

## Observabilidade (New Relic)

O root também provisiona a observabilidade do cluster e da aplicação na New
Relic: o chart `nri-bundle` `8.0.24` (infraestrutura, logs e
`kube-state-metrics`), um dashboard, uma política de alertas com condições de
indisponibilidade, taxa de erro, CPU, memória e crash loop, e um workflow de
notificação por e-mail. O output `observability_dashboard_url` publica o link
do dashboard.

O CI exige:

| Nome | Tipo |
| --- | --- |
| `NEW_RELIC_LICENSE_KEY` | secret |
| `NEW_RELIC_API_KEY` | secret |
| `NEW_RELIC_ACCOUNT_ID` | variável |
| `NEW_RELIC_ALERT_EMAIL` | variável |

## Workflows

| Workflow | Disparo | O que faz |
| --- | --- | --- |
| `ci.yml` | pull request, push em `develop`/`main`, manual | Validação, plan, apply e destroy |
| `up.yml` | manual | Apply de HML |
| `down.yml` | manual | Destroy de HML ou PROD, com confirmação digitada |
| `diagnose-ec2-capacity.yml` | manual | Diagnóstico somente leitura da capacidade EC2 de HML |
| `trivy.yml` | push, pull request, agendado | Scan de configuração IaC com gate em HIGH e CRITICAL |

## Convenção de nomenclatura

`tc3-{resource}-{environment}` (ex.: `tc3-eks-hml`).
