# ADR-0020 — Base para múltiplos serviços

- `async-furious`, `billing` e `execucao` são namespaces de serviço; `platform`
  é reservado ao Kafka. O Terraform também declara o namespace legado
  `async-furious`; em um cluster existente, importar os quatro endereços antes
  do apply evita disputa de ownership (`terraform import ...managed[\"...\"]`).
- Cada serviço recebe apenas um `LimitRange` com request padrão `100m/128Mi` e
  limit `500m/512Mi`. Não há `ResourceQuota` nem `NetworkPolicy`; portanto os
  serviços devem validar JWT localmente.
- ECR usa `for_each` para `os`, `billing` e `execucao`, com nomes
  `tc3-os-*`, `tc3-billing-*` e `tc3-execucao-*`. Os `moved` blocks migram
  endereços Terraform, mas não copiam imagens nem renomeiam o repositório físico;
  a troca de `tc3-app-*` exige cópia/retag manual, plan e aprovação antes de
  apply.
- HML usa `t3.medium` SPOT com `min=2`, `desired=3`, `max=3`; a ordem é
  `min <= desired <= max`. O addon EBS CSI usa IRSA e `AmazonEBSCSIDriverPolicy`
  quando IAM é gerenciado; Academy não cria OIDC/IRSA e esse bloqueio deve ser
  resolvido por spike aprovado, nunca por credencial estática ou acesso público.
- `gp3` é criptografado e usa `WaitForFirstConsumer`.

## Gate G1–G3

Após #314, executar `scripts/capacity-gate.sh g1`, revisar requests de todos os
pods e registrar cada nó abaixo de 70%. `g2 <node>` apenas imprime o plano de
drain; execução exige `--execute-drain` e `CONFIRM_DRAIN=I_UNDERSTAND`.
`g3 [selector] [broker-pod]` valida o seletor e métricas, imprime o checklist e
aceita `--load-command` sem executar a carga. Registrar heap, números, resultado
e eventual degrau aplicado.

## Fora de escopo

Deployments, chart/imagem Kafka, regras de edge, bancos, NetworkPolicy,
ResourceQuota, instalação Kafka, load test e qualquer apply/destroy de produção.
