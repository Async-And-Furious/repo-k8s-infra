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
O node group gerenciado usa por padrão, intencionalmente, apenas o tipo de
instância `t3.micro`. Evitar uma lista de tipos de instância impede que o
Terraform/EKS substitua o node group e sobreponha temporariamente seus nós, o
que pode exceder a quota de vCPU da conta. O Stage 1 define temporariamente o
node group gerenciado para `min=2`, `desired=2` e `max=2`, para que a
substituição fique dentro do limite de 8 vCPUs da conta. Depois que o apply do
stage 1 for bem-sucedido, um follow-up precisa reescalar os três valores de
volta para 3.

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
`ubuntu-latest`, sem credenciais AWS. Um push na branch de integração
`develop` aplica automaticamente o HML (usando variáveis do repositório para
seu modo). Um push na `main` gera um plan de produção e só o aplica depois
que o Environment protegido `production` do GitHub aprovar o job de apply.
O disparo manual seleciona `hml` ou `prod` e `plan`, `apply`,
`destroy-plan` ou `destroy`. O modo normal usa os labels de runner
self-hosted `self-hosted`, `linux` e `eks-private`, para que o endpoint
privado do EKS e o provider Helm fiquem acessíveis.
O modo Academy HML usa `ubuntu-latest`; cada execução valida o endereço
IPv4 público atual do runner hospedado e restringe temporariamente o
endpoint público do EKS a esse `/32` único. O workflow preserva o acesso ao
endpoint privado e sempre desabilita o acesso ao endpoint público depois que
Terraform e Helm terminam. Nenhum CIDR irrestrito é usado. Operações
manuais de plan e apply rodam diretamente contra o state S3 do ambiente
selecionado. Execuções de produção usam o Environment protegido do GitHub
`production`; suas regras de aprovação controlam o job de apply. O apply de
produção também exige `confirm="APPLY PROD"`. As mesmas credenciais
temporárias do AWS Academy podem ser usadas para qualquer um dos dois
ambientes lógicos; state, variáveis e artefatos de plan continuam
escopados por ambiente. Operações de state do mesmo ambiente não rodam
concorrentemente.

Antes do bootstrap de backend ou de uma mudança no endpoint do EKS, o
workflow faz uma checagem somente leitura de credenciais STS e uma consulta
ao state qualificada por conta. Ele falha de forma clara quando as
credenciais estão ausentes, expiradas ou não autorizadas. Os plans são
salvos como `tfplan` e enviados como artefato da execução; o apply usa esse
plan salvo.

Operações de destroy só estão disponíveis para execuções Academy HML. As
duas ações de destroy inspecionam o objeto de state S3 qualificado por
conta sem criar ou configurar o bucket; um objeto ausente ou um state sem
recursos é um no-op bem-sucedido. `destroy-plan` roda apenas um plan de
destroy. `destroy` exige a confirmação exata `DESTROY HML`, cria um plan de
destroy salvo e aplica exatamente esse plan. Nenhuma das duas ações remove
o bucket de state nem o objeto de state. O Academy HML permite que o
Terraform apague o repositório ECR com suas imagens; o comportamento padrão
e de produção do ECR continua rejeitando exclusão de repositório não vazio.

O disparo manual expõe `aws_academy`, `manage_iam` e `lab_role_arn`.
Selecione `aws_academy=true`, `manage_iam=false`, e cole o ARN atual do
LabRole em `lab_role_arn`. Alternativamente, defina a variável de
repositório `LAB_ROLE_ARN`; o workflow a exporta como `TF_VAR_lab_role_arn`.
Defina `AWS_ROLE_ARN` para o caminho normal via OIDC. Para uma sessão AWS
Academy, configure estes secrets de repositório juntos:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_SESSION_TOKEN`

O workflow usa as credenciais temporárias somente quando os três secrets
estão presentes; caso contrário, usa OIDC como fallback. Rotacione os
secrets depois de cada sessão AWS Academy com `gh secret set` (nunca
commite nem imprima seus valores).

## Convenção de nomenclatura

`tc3-{resource}-{environment}` (ex.: `tc3-eks-hml`).
