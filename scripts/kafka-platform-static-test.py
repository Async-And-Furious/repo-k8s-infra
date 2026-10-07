from pathlib import Path

values = Path("kafka-values.yaml").read_text()
terraform = Path("main.tf").read_text()
outputs = Path("outputs.tf").read_text()

for expected in ("storageClass: gp3", "size: 20Gi", "enabled: true", "protocol: SASL_PLAINTEXT", "existingSecret: kafka-sasl", "partitions: 3", "replicationFactor: 3"):
    assert expected in values, expected
for expected in ("chart            = \"kafka\"", "version          = \"32.4.3\"", "helm_release\" \"kafka", "kubernetes_storage_class_v1\" \"gp3", "aws_eks_addon\" \"ebs_csi_driver"):
    assert expected in terraform, expected
for expected in ("kafka_bootstrap_servers", "kafka_secret_name", "kafka_topics"):
    assert expected in outputs, expected
print("Kafka platform static contract passed")
