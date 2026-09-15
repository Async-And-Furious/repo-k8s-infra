# repo-k8s-infra

Tech Challenge Fase 3 — VPC, EKS e ECR via Terraform.

O módulo EKS também faz o bootstrap do AWS Load Balancer Controller (incluindo
sua CRD TargetGroupBinding) e do Metrics Server, com versões fixas de chart
Helm. A versão do EKS é preservada para clusters existentes por padrão; defina
`cluster_version` explicitamente quando um upgrade intencional for aprovado.
O AWS Load Balancer Controller usa o role IRSA criado pelo Terraform (com
`manage_iam = true` e `aws_academy = false`, a configuração em uso). A API do
Kubernetes é privada por padrão; defina
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
- O AWS Load Balancer Controller usa o role IRSA criado pelo Terraform. O
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

### Conta AWS

Os ambientes rodam em uma conta AWS pessoal, no free tier, autenticada por
credenciais de usuário IAM. Nessa configuração o Terraform cria as próprias
roles: control plane e node group do EKS, e o IRSA do AWS Load Balancer
Controller. Não é preciso definir `aws_academy`, `manage_iam` nem
`lab_role_arn`; os padrões (`aws_academy = false`, `manage_iam = true`) já
descrevem esse caminho.

O código ainda carrega um caminho alternativo para contas AWS Academy, hoje
inativo: com `aws_academy = true` e `manage_iam = false`, os módulos deixam de
criar IAM e reutilizam o `LabRole` informado em `lab_role_arn`, tanto no
control plane quanto no node group, e o controller passa a depender das
permissões desse role. Trate essa combinação como legado, não como
configuração de uso.

Quando `manage_iam=false` na conta pessoal, um role IRSA existente do
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
nem o bucket nem o objeto de state são removidos. O `force_delete` do ECR de
HML só é ativado com `aws_academy = true`, que não é o caso da conta em uso:
esvazie o repositório de imagens antes de destruir, senão o ECR rejeita a
exclusão de repositório não vazio.

### Credenciais e variáveis

Não há OIDC. O workflow usa os secrets `AWS_ACCESS_KEY_ID` e
`AWS_SECRET_ACCESS_KEY` do usuário IAM da conta pessoal, e inclui
`AWS_SESSION_TOKEN` apenas quando esse secret está preenchido (credenciais
temporárias). Chaves de usuário IAM não expiram sozinhas; rotacione-as com
`gh secret set`, sem commitar nem imprimir os valores.

O disparo manual ainda expõe `academy_mode` e `lab_role_arn`, do caminho
legado descrito em "Conta AWS". Mantenha `academy_mode=false`, que é o padrão
e o valor que `up.yml` e `down.yml` passam.

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
