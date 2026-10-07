from pathlib import Path

values = Path("kafka-values.yaml").read_text()
terraform = Path("main.tf").read_text()
outputs = Path("outputs.tf").read_text()

for expected in ("storageClass: gp3", "size: 20Gi", "protocol: SASL_PLAINTEXT", "enabledMechanisms: PLAIN", "- app", "interBrokerUser: admin", "controllerUser: controller", "existingSecret: kafka-sasl", "extraDeploy:", "helm.sh/hook: post-install,post-upgrade", "--if-not-exists", "partitions 3", "replication-factor 3"):
    assert expected in values, expected
assert "provisioning:" not in values
assert values.count("--topic \"$topic\"") == 1
for topic in ("os.eventos.v1", "os.retry.v1", "os.dlt.v1", "billing.eventos.v1", "billing.retry.v1", "billing.dlt.v1", "execucao.eventos.v1", "execucao.retry.v1", "execucao.dlt.v1"):
    assert topic in values, topic
for expected in ("chart            = \"kafka\"", "version          = \"32.4.3\"", "helm_release\" \"kafka", "kubernetes_storage_class_v1\" \"gp3", "kubernetes_secret_v1\" \"kafka_sasl", "aws_eks_addon\" \"ebs_csi_driver"):
    assert expected in terraform, expected
for expected in ("kafka_bootstrap_servers", "kafka_secret_name", "kafka_topics"):
    assert expected in outputs, expected
print("Kafka platform static contract passed")
