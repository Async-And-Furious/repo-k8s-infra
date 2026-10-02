# Servico de Execucao: o que este repositorio deve entregar

Refs Async-And-Furious/async-furious-project#319. O codigo do servico vive em `repo-execucao-service`.

O servico consome, sem provisionar, os itens abaixo (Epic #312):

| Item | Estado atual | Necessario |
|---|---|---|
| Namespace | `modules/` nao cria namespaces; os manifests do OS Service fixam `async-furious` | namespace `execucao` no cluster EKS existente |
| ECR | `modules/ecr` cria um unico repositorio `tc3-app-<env>` | repositorio proprio do servico (ex.: `tc3-execucao-<env>`), tags imutaveis, scan on push |
| Kafka | n/d | brokers, credencial SASL e consumer group `execucao-service` no configmap/secret do namespace |
| ALB | n/d | regra por path `/api/docs/execucao` e healthcheck do target group em `/api/v1/health/ready` |

Os manifests do servico estao em `repo-execucao-service/k8s/`.
