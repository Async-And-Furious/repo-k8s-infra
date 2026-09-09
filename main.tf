provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "tc3"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

module "vpc" {
  source = "./modules/vpc"

  environment = var.environment
}

module "eks" {
  source = "./modules/eks"

  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  cluster_endpoint_public_access       = var.cluster_endpoint_public_access
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs
  aws_academy                          = var.aws_academy
  manage_iam                           = var.manage_iam
  lab_role_arn                         = var.lab_role_arn
  eks_cluster_role_arn                 = var.eks_cluster_role_arn
  eks_node_role_arn                    = var.eks_node_role_arn
  load_balancer_controller_role_arn    = var.load_balancer_controller_role_arn
}

module "ecr" {
  source = "./modules/ecr"

  environment  = var.environment
  force_delete = var.aws_academy && var.environment == "hml"
}

module "internal_alb" {
  source = "./modules/alb"

  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.aws_region]
    }
  }
}

resource "helm_release" "aws_load_balancer_controller" {
  name             = "aws-load-balancer-controller"
  namespace        = "kube-system"
  create_namespace = false
  repository       = "https://aws.github.io/eks-charts"
  chart            = "aws-load-balancer-controller"
  version          = "1.8.2"
  # The chart owns the TargetGroupBinding CRD; keep it installed in both environments.
  skip_crds = false

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  dynamic "set" {
    for_each = var.aws_academy ? [] : [module.eks.load_balancer_controller_role_arn]

    content {
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = set.value
    }
  }
}

resource "helm_release" "metrics_server" {
  name             = "metrics-server"
  namespace        = "kube-system"
  create_namespace = false
  repository       = "https://kubernetes-sigs.github.io/metrics-server/"
  chart            = "metrics-server"
  version          = "3.12.2"
}

# New Relic Kubernetes integration (issue #163). Minimal footprint on purpose:
# only the infrastructure agent, log forwarding and kube-state-metrics are
# enabled. nri-metadata-injection (a cluster-wide mutating admission webhook)
# and nri-kube-events/newrelic-prometheus-agent/pixie are left disabled until
# the basics are validated end-to-end and node capacity headroom is confirmed.
resource "helm_release" "newrelic_bundle" {
  name             = "newrelic-bundle"
  namespace        = "newrelic"
  create_namespace = true
  repository       = "https://helm-charts.newrelic.com"
  chart            = "nri-bundle"
  version          = "8.0.24"

  set {
    name  = "global.cluster"
    value = module.eks.cluster_name
  }

  set_sensitive {
    name  = "global.licenseKey"
    value = var.new_relic_license_key
  }

  set {
    name  = "global.lowDataMode"
    value = "true"
  }

  set {
    name  = "newrelic-infrastructure.enabled"
    value = "true"
  }

  set {
    name  = "newrelic-logging.enabled"
    value = "true"
  }

  set {
    name  = "kube-state-metrics.enabled"
    value = "true"
  }

  set {
    name  = "nri-metadata-injection.enabled"
    value = "false"
  }
}
