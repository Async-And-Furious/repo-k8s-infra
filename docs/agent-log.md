# Log do agente

## 2026-09-14 (runner de CI privado para o EKS)

- Movidos os jobs normais de plan/apply do Terraform em HML e produção para o
  runner configurado `eks-private`, para que os providers Helm/Kubernetes do
  Terraform usem acesso privado à API do EKS.
- Preservados a descoberta de endpoint do runner hospedado e a exposição
  temporária de `/32` apenas para o modo AWS Academy explicitamente
  selecionado; as asserções de Terraform e de endpoint continuam
  bloqueantes, enquanto os diagnósticos permanecem best-effort.
- Nenhum apply do Terraform, operação de produção ou mudança de recurso AWS
  foi realizada.

## 2026-09-14 (diagnósticos best-effort pós-deploy)

- Marcados os diagnósticos do New Relic e do controller de load balancer em
  HML como best-effort, para que problemas transitórios de conectividade no
  EKS ou buscas de pod desatualizadas não possam mascarar os resultados de
  apply do Terraform, restauração de endpoint ou asserção de endpoint.
- Nenhum apply do Terraform, operação de produção ou mudança de recurso AWS
  foi realizada.

## 2026-09-06 (diagnósticos read-only de capacidade EC2 em HML)

- Adicionado um workflow disparado apenas manualmente (workflow-dispatch) que
  usa o padrão normal de configuração de credenciais AWS para reportar
  informações de EC2, Auto Scaling, EKS, conta e quota de vCPU em `us-east-1`,
  sem alterar recursos.
- Nenhum apply, destroy, terminação ou modificação na AWS foi realizada.

## 2026-09-04 (plano do Terraform específico do runner de apply em HML)

- Corrigido o apply em HML para gerar `terraform.auto.tfvars.json` a partir do
  `/32` atual do runner de apply, criar um `tfplan` novo nesse mesmo runner e
  aplicá-lo, em vez de usar o artefato de plano do runner de plan. O
  comportamento de planejamento/apply de produção foi mantido inalterado.
- Mantida a exposição temporária de endpoint restrita ao runner de HML e a
  restauração incondicional das configurações originais, com uma asserção
  final read-only de restauração. Nenhum apply do Terraform ou disparo de
  workflow foi realizado.

## 2026-09-04 (capacidade de substituição do node group gerenciado, etapa 1)

- Definido temporariamente o node group gerenciado AL2023 `t3.micro` para
  `min=2`, `desired=2` e `max=2`, para que a substituição possa ser concluída
  dentro do limite de 8 vCPUs da conta enquanto os dois nós antigos
  permanecem.
- Esta é apenas a etapa 1; após um apply bem-sucedido, um follow-up deve
  reverter os três valores de volta para 3. Nenhum apply na AWS foi realizado.

## 2026-09-04 (estabilidade do tipo de instância do node group gerenciado)

- Revertido o padrão do node group gerenciado para o único tipo de instância
  `t3.micro` que já funcionava anteriormente. Evitar uma lista de tipos de
  instância impede que node groups de substituição e a sobreposição
  temporária de nós excedam a quota de vCPU da conta; a capacidade fixa
  `min=3`, `desired=3`, `max=3` permanece inalterada.
- Preservados AL2023, rede privada, IAM e security groups. Nenhum apply do
  Terraform, comando destrutivo ou operação na AWS foi realizado.

## 2026-09-04 (resiliência de capacidade do node group gerenciado)

- Adicionado `t3a.micro` junto com `t3.micro` no `instance_types` do node
  group gerenciado do EKS, para que o EC2 possa usar qualquer um dos dois
  tipos de capacidade após um NodeCreationFailure.
- Preservados AL2023, capacidade fixa de três nós em HML/produção, subnets
  privadas, IAM e security groups. Nenhum apply do Terraform ou operação na
  AWS foi realizada.

## 2026-09-04 (capacidade do node group gerenciado)

- Definida para HML e produção uma capacidade fixa de três nós no node group
  gerenciado (`min=3`, `desired=3`, `max=3`), para que os Jobs de migração
  tenham capacidade agendável sem introduzir um intervalo de auto scaling;
  `t3.micro` e a rede privada permanecem inalterados.
- Nenhum validate, apply do Terraform ou operação na AWS foi realizada.

## 2026-09-04 (capacidade de réplicas do Load Balancer Controller)

- Definido `replicaCount` igual a um no chart 1.8.2, para que o controller
  caiba na capacidade de pods do node `t3.micro` configurado, preservando
  readiness, webhook, IRSA e configurações de rede. Nenhum apply na AWS foi
  realizado.

## 2026-09-04 (inicialização do Load Balancer Controller em HML)

- Passados a região AWS e o VPC ID para o chart 1.8.2 e completada a política
  IAM do controller com as ações de EC2 e ELB diretamente necessárias.
- Preservados a prontidão do EKS, IMDSv2, segurança de endpoint e os caminhos
  de HML/produção; nenhum apply na AWS foi realizado.

## 2026-09-04 (AMI do EKS e limpeza de endpoint em HML)

- Selecionada a AMI de node gerenciado `AL2023_x86_64_STANDARD`, suportada
  pela conta, para o EKS 1.30, preservando as sobrescritas de AMI e versão por
  node group.
- O plan/apply de HML agora corrige o acesso ao endpoint privado antes do
  Terraform e restaura as configurações de endpoint sempre na limpeza final,
  inclusive para clusters recém-criados. Nenhum apply ou destroy na AWS foi
  realizado.

## 2026-09-04 (limpeza idempotente do ECR de produção)

- A limpeza do ECR do ambiente-alvo agora deriva o nome do repositório e trata
  um repositório inexistente como um no-op bem-sucedido, preservando a
  limpeza de imagens existente, os guards de destroy, o estado do Terraform e
  as permissões com escopo restrito.
- Nenhum destroy do Terraform ou operação destrutiva na AWS foi realizada.

## 2026-09-04 (workflow explícito de destroy de produção)

- Adicionados guards de destroy de HML/produção disparados apenas manualmente,
  com confirmações exatas por ambiente; produção permanece atrás do
  Environment protegido `production`.
- O destroy de produção agora preserva o fluxo existente de estado/backend,
  restaura o acesso temporário ao endpoint do EKS e esvazia apenas o
  repositório ECR do ambiente-alvo. Nenhum destroy foi executado.

## 2026-09-03 (configuração de endpoint no apply de produção)

- As configurações de endpoint desejadas do Terraform em produção agora
  correspondem ao acesso público temporário `/32` do runner tanto no plan
  quanto no apply; o apply de produção reexecuta o plan no seu próprio runner
  para que o CIDR não fique desatualizado entre jobs.
- As configurações de endpoint existentes continuam sendo restauradas após o
  plan/apply de produção, inclusive em caso de falha. Nenhum apply ou destroy
  na AWS foi realizado.

## 2026-09-03 (acesso ao endpoint pelo runner de produção)

- Adicionado acesso `/32` do runner de plan/apply de produção ao endpoint do
  EKS, com limpeza das configurações capturadas; cluster inexistente
  permanece como no-op.
- Nenhum apply ou destroy na AWS foi realizado.

## 2026-09-04 (dimensionamento de nós no Free Tier)

- Definido como padrão para os nós gerenciados de HML e produção o tipo
  `t3.micro`, elegível ao AWS Free Tier, mantendo uma sobrescrita explícita
  via `node_instance_types`.
- Os releases do Helm agora esperam o módulo completo do EKS, para não entrar
  em disputa com um node group que falhou ou ainda está inacessível.
- Mantida a seleção de subnets a partir do módulo de VPC; nenhum input manual
  de subnet, apply ou destroy na AWS foi realizado.

## 2026-09-03 (deriva de versão do EKS)

- Tornada opcional a versão raiz do EKS, para que clusters existentes não
  sejam planejados em direção ao padrão histórico 1.30 do módulo, o que
  poderia invocar um rollback inválido.
- Upgrades intencionais permanecem disponíveis através de um
  `cluster_version` explícito.
- Nenhum apply ou destroy na AWS foi realizado.

## 2026-08-31 (achados do Trivy)

- Restringido o egress do ALB interno ao CIDR da VPC, habilitado o descarte de
  cabeçalhos inválidos e habilitados os logs de control plane do controller
  manager e do scheduler do EKS.
- Mantido o listener HTTP do VPC Link privado já aprovado e documentada sua
  exceção estritamente restrita ao AWS-0054; o ECR permanece com a
  criptografia gerenciada pela AWS, pois um design com KMS de cliente não é
  suportado pelo contrato da conta Academy.
- Nenhum apply do Terraform, commit ou push foi realizado.

## 2026-08-30 (integração do TargetGroupBinding)

- Mantido o AWS Load Balancer Controller habilitado para HML e produção e
  explicitamente mantida a instalação de CRDs via Helm, para que o
  TargetGroupBinding fique disponível.
- O modo Academy usa a LabRole existente do node em vez de uma anotação IRSA;
  o modo normal continua usando a role IRSA configurada/do controller.
- Adicionado um output explícito de target group interno e documentado o
  contrato exato de TargetGroupBinding, Service, porta e listener.
- Nenhum apply ou destroy na AWS foi realizado.

## 2026-08-30 (alvo de entrega confirmado)

- Permitido o uso do mesmo conjunto de credenciais temporárias do AWS Academy
  para HML e produção; os applies de produção permanecem atrás do Environment
  protegido `production` e de confirmação explícita.
- Adicionados um ALB interno com escopo por ambiente, listener, target group
  de IP e outputs para os contratos do Auth/API Gateway e da aplicação.
- Tornada temporária a exposição de endpoint em modo Academy para clusters
  existentes e novos, restaurando as configurações capturadas de
  privado/público/CIDR após cada caminho de plan/apply.
- Nenhum apply ou destroy na AWS foi realizado.

## 2026-08-29 (fortalecimento do caminho de release)

- Adicionados apply automático em HML no `develop`, gate do Environment
  protegido `production`, artefatos de plano do Terraform salvos e
  verificação prévia read-only de AWS/estado.
- O modo Academy permanece compatível com LabRole para HML e é explicitamente
  rejeitado para produção; nenhum apply ou destroy foi realizado.
- Publicado o output estável do nome do repositório ECR e esclarecido o
  contrato de outputs existente de VPC/EKS/OIDC/ECR.

## 2026-08-26 (workflow de apply direto)

- O apply do Terraform agora roda diretamente após a validação; o job de plan
  permanece limitado a disparos explícitos de plan.
- Preservados os tfvars automáticos gerados, a inicialização do estado remoto
  no HCP, os guardrails do Academy, as aprovações de ambiente e o locking de
  estado do Terraform.
- O apply do Terraform não foi executado.

## 2026-08-24 (execução local do backend remoto do Terraform)

- Alterado o plan/apply manual para usar tfvars automáticos locais gerados,
  removendo variáveis de CLI incompatíveis com o backend remoto e a
  transferência de artefato de plano.
- Preservados a validação de CIDR de endpoint público do Academy e o
  comportamento do modo normal.
- Nenhum apply do Terraform foi realizado.

## 2026-08-24 (inicialização do backend remoto em HML)

- Configurado o backend remoto raiz para o workspace `tc3-k8s-hml` do HCP
  Terraform e removidas sobrescritas inválidas de CLI de backend remoto do
  plan/apply.
- Preservados o comportamento de credenciais Academy, runner, CIDR, LabRole e
  IAM.
- Nenhum apply do Terraform foi realizado.

## 2026-08-24 (estado no HCP Terraform)

- Substituído o backend S3 pelo backend de estado remoto do HCP Terraform,
  usando execução local e workspaces `tc3-k8s-*` específicos por ambiente.
- Atualizados CI e runbooks para usar `TF_API_TOKEN`; as credenciais AWS
  permanecem no GitHub e o comportamento de runner hospedado/CIDR/LabRole do
  Academy permanece inalterado.
- Nenhum apply do Terraform, commit ou push foi realizado.

## 2026-08-13

- Substituídos os blocos de backend aninhados do Terraform por arquivos de
  configuração de backend de HML e PROD consumíveis pela raiz, preservando as
  configurações de estado.
- Parametrizado o CI de plan/apply manual por ambiente, com escopo restrito de
  permissões OIDC, preservação de artefatos de plano para o apply e
  serialização de operações de estado por ambiente.
- Atualizada a documentação de uso do repositório e de CI.
- Nenhum apply do Terraform, commit, push ou contato com a AWS foi realizado.

## 2026-08-15

- Adicionados releases Helm de bootstrap fixados por versão para o AWS Load
  Balancer Controller e o Metrics Server, usando a role IRSA do controller.
- Tornado o endpoint da API do EKS privado por padrão, com variáveis opcionais
  de acesso público restrito por CIDR.
- Nenhum apply do Terraform ou inicialização remota foi realizada.

## 2026-08-16

- Adicionados inputs opcionais de ARN de role para o cluster EKS e para o node
  group gerenciado, permitindo o reuso de roles do AWS Academy/Lab e
  preservando os padrões de roles criadas pelo Terraform.
- Documentados `TF_VAR_eks_cluster_role_arn`, `TF_VAR_eks_node_role_arn` e a
  descoberta do ARN da Lab role.
- Nenhum apply do Terraform ou inicialização remota foi realizada.

## 2026-08-16 (reuso de role do Load Balancer Controller)

- Adicionados inputs opcionais de ARN de role do Load Balancer Controller na
  raiz/módulo, preservando a criação de role pelo Terraform quando vazios.
- Conectada a variável `LOAD_BALANCER_CONTROLLER_ROLE_ARN` do GitHub ao nome
  canônico em minúsculas `TF_VAR_load_balancer_controller_role_arn` e
  documentado o uso de `gh variable set`.
- Nenhum apply do Terraform ou contato com a AWS foi realizado.

## 2026-08-22 (guardrails de revisão profunda limitada)

- Removidas entradas duplicadas/incompatíveis de ambiente de role do Terraform
  e tornada a seleção de credenciais AWS dependente dos valores de ambiente do
  job; o download de artefato agora tem a permissão explícita `actions:
  read`.
- Adicionada validação para CIDRs de endpoint público do EKS e ARNs de IAM
  role neutros quanto à partition. A política do Load Balancer Controller e o
  contrato de output de role nulo existente foram intencionalmente mantidos
  inalterados.
- Nenhum apply do Terraform, commit ou push foi realizado.

## 2026-08-24 (compatibilidade com AWS Academy)

- Adicionadas variáveis explícitas de modo Academy/IAM e validado o reuso do
  ARN da LabRole para o control plane do EKS e o node group gerenciado.
- O modo Academy desabilita IAM, OIDC/IRSA e recursos do AWS Load Balancer
  Controller, mantendo o Metrics Server e o caminho de Service
  LoadBalancer do Kubernetes.
- Adicionados inputs de disparo de workflow e documentado o uso de
  credenciais temporárias.
- Nenhum apply de infraestrutura, inicialização remota, commit ou push foi
  realizado.

## 2026-08-24 (integração do workflow Academy)

- Adicionados gates explícitos de disparo de plan/apply e checagens
  obrigatórias do modo Academy.
- Movidos os jobs manuais de plan/apply do Terraform para os labels de runner
  `self-hosted`, `linux`, `eks-private`; a validação sem credenciais permanece
  no `ubuntu-latest`.
- Exigida uma role pré-existente do Load Balancer Controller quando o
  gerenciamento de IAM está desabilitado fora do modo Academy.
- Nenhum apply do Terraform, commit, push ou merge foi realizado.

## 2026-08-24 (acesso via runner hospedado do Academy)

- O plan/apply do Academy agora usam `ubuntu-latest`; o modo normal mantém os
  labels de runner self-hosted privado.
- Os jobs do Academy liberam na allowlist os CIDRs atuais do GitHub Actions
  para o endpoint público da API do EKS, sem usar um CIDR irrestrito; o
  comportamento de LabRole/IAM desabilitado e os inputs de ação do workflow
  permanecem inalterados.
- Nenhum apply do Terraform, commit ou push foi realizado.

## 2026-08-24 (correção de contexto de sessão IAM do Academy)

- Vendorizado o módulo runtime resolvido terraform-aws-modules/eks/aws
  v20.37.2, incluindo seus módulos aninhados necessários, restringindo apenas
  sua data source de contexto de sessão IAM a permissões de admin do criador.
- O modo Academy desabilita explicitamente as permissões de admin do criador,
  mantendo a seleção da LabRole e nenhuma criação de role IAM/IRSA/ALB.
- Terraform fmt, init sem backend e validate passaram. O plan do AWS Academy
  não foi executado porque a AWS CLI local falhou antes que as credenciais
  pudessem ser verificadas.
