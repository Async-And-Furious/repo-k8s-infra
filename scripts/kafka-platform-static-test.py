from pathlib import Path

values = Path("kafka-values.yaml").read_text()
terraform = Path("main.tf").read_text()
eks_terraform = Path("modules/eks/main.tf").read_text()
outputs = Path("outputs.tf").read_text()

for expected in ("storageClass: gp3", "size: 20Gi", "protocol: SASL_PLAINTEXT", "enabledMechanisms: PLAIN", "- app", "interbroker:\n    user: admin", "controller:\n    user: controller", "existingSecret: kafka-sasl", "extraDeploy:", "helm.sh/hook: post-install,post-upgrade", "--if-not-exists", "partitions 3", "replication-factor 3"):
    assert expected in values, expected
assert "interBrokerUser:" not in values
assert "controllerUser:" not in values
assert "provisioning:" not in values
assert values.count("--topic \"$topic\"") == 1
for topic in ("os.eventos.v1", "os.retry.v1", "os.dlt.v1", "billing.eventos.v1", "billing.retry.v1", "billing.dlt.v1", "execucao.eventos.v1", "execucao.retry.v1", "execucao.dlt.v1"):
    assert topic in values, topic
for expected in ("chart            = \"kafka\"", "version          = \"32.4.3\"", "helm_release\" \"kafka", "kubernetes_storage_class_v1\" \"gp3", "kubernetes_secret_v1\" \"kafka_sasl"):
    assert expected in terraform, expected
assert "aws-ebs-csi-driver = {" in eks_terraform
assert eks_terraform.count("aws-ebs-csi-driver = {") == 1
assert "var.aws_academy ? null : (var.manage_iam ? aws_iam_role.ebs_csi_driver[0].arn : var.ebs_csi_driver_role_arn)" in eks_terraform
for expected in ("kafka_bootstrap_servers", "kafka_secret_name", "kafka_topics"):
    assert expected in outputs, expected
print("Kafka platform static contract passed")
