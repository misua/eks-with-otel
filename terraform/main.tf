# EKS with OpenTelemetry Infrastructure - Terraform Configuration
# This Terraform configuration creates the same infrastructure as setup-infrastructure.sh
# but using Infrastructure as Code principles for better management and reproducibility

terraform {
  required_version = ">= 1.0"
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "eks-otel-crud"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Data source for EKS cluster (evaluated after cluster creation)
data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_name
  depends_on = [module.eks]
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
  depends_on = [module.eks]
}

# Configure Kubernetes provider
provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

# Configure Helm provider
provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

# Local values for common configurations
locals {
  cluster_name = "${var.cluster_name}-${var.environment}"
  
  common_tags = {
    Project     = "eks-otel-crud"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# VPC Module
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway   = true
  enable_vpn_gateway   = false
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = local.common_tags
}

# EKS Module
module "eks" {
  source = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.cluster_name
  cluster_version = var.kubernetes_version

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = true

  # EKS Managed Node Groups
  eks_managed_node_groups = {
    main = {
      name = "main-node-group"

      instance_types = var.node_instance_types
      capacity_type  = "ON_DEMAND"

      min_size     = var.node_group_min_size
      max_size     = var.node_group_max_size
      desired_size = var.node_group_desired_size

      # Enable EBS CSI driver for persistent volumes
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 50
            volume_type           = "gp3"
            iops                  = 3000
            throughput            = 150
            encrypted             = true
            delete_on_termination = true
          }
        }
      }
    }
  }

  # Cluster access entry
  enable_cluster_creator_admin_permissions = true

  tags = local.common_tags
}

# EBS CSI Driver addon
resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = var.ebs_csi_driver_version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  service_account_role_arn = module.ebs_csi_irsa_role.iam_role_arn

  tags = local.common_tags

  depends_on = [module.eks]
}

# IAM role for EBS CSI driver
module "ebs_csi_irsa_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name             = "${local.cluster_name}-ebs-csi"
  attach_ebs_csi_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = local.common_tags
}

# Kubernetes namespaces
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
    labels = {
      name = "monitoring"
    }
  }

  depends_on = [module.eks]
}

resource "kubernetes_namespace" "tracing" {
  metadata {
    name = "tracing"
    labels = {
      name = "tracing"
    }
  }

  depends_on = [module.eks]
}

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
    labels = {
      name = "argocd"
    }
  }

  depends_on = [module.eks]
}

# Helm Release: Prometheus/Grafana Stack
resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = var.prometheus_chart_version

  values = [
    templatefile("${path.module}/values/prometheus-values.yaml", {
      storage_class = var.storage_class
      grafana_admin_password = var.grafana_admin_password
    })
  ]

  depends_on = [
    module.eks,
    kubernetes_namespace.monitoring,
    aws_eks_addon.ebs_csi
  ]
}

# Helm Release: Grafana Tempo
resource "helm_release" "tempo" {
  name       = "tempo"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "tempo"
  namespace  = kubernetes_namespace.tracing.metadata[0].name
  version    = var.tempo_chart_version

  values = [
    file("${path.module}/values/tempo-values.yaml")
  ]

  depends_on = [
    module.eks,
    kubernetes_namespace.tracing,
    aws_eks_addon.ebs_csi
  ]
}

# Helm Release: OpenTelemetry Collector
resource "helm_release" "otel_collector" {
  name       = "otel-collector"
  repository = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart      = "opentelemetry-collector"
  namespace  = kubernetes_namespace.tracing.metadata[0].name
  version    = var.otel_collector_chart_version

  values = [
    file("${path.module}/../eks-infrastructure/monitoring/otel-collector-values.yaml")
  ]

  depends_on = [
    module.eks,
    kubernetes_namespace.tracing,
    helm_release.tempo,
    helm_release.loki,
    helm_release.promtail,
    helm_release.prometheus,
    aws_eks_addon.ebs_csi
  ]
}

# Helm Release: Loki (Logging Backend)
resource "helm_release" "loki" {
  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = var.loki_chart_version

  values = [
    file("${path.module}/../eks-infrastructure/monitoring/loki-values.yaml")
  ]

  depends_on = [
    module.eks,
    kubernetes_namespace.monitoring,
    aws_eks_addon.ebs_csi
  ]
}

# Helm Release: Promtail (Log Shipping)
resource "helm_release" "promtail" {
  name       = "promtail"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "promtail"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = var.promtail_chart_version

  values = [
    file("${path.module}/../eks-infrastructure/monitoring/promtail-values.yaml")
  ]

  depends_on = [
    module.eks,
    kubernetes_namespace.monitoring,
    helm_release.loki,
    aws_eks_addon.ebs_csi
  ]
}

# Helm Release: ArgoCD
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  version    = var.argocd_chart_version

  values = [
    file("${path.module}/values/argocd-values.yaml")
  ]

  depends_on = [
    module.eks,
    kubernetes_namespace.argocd
  ]
}

# ArgoCD Applications (using kubectl instead of kubernetes_manifest)
resource "null_resource" "argocd_app_infrastructure" {
  provisioner "local-exec" {
    command = <<-EOF
      aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}
      kubectl apply -f - <<YAML
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: eks-infrastructure
  namespace: ${kubernetes_namespace.argocd.metadata[0].name}
spec:
  project: default
  source:
    repoURL: ${var.git_repo_url}
    targetRevision: HEAD
    path: eks-infrastructure
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
YAML
    EOF
  }

  depends_on = [helm_release.argocd, data.aws_eks_cluster.cluster]
}

resource "null_resource" "argocd_app_main" {
  provisioner "local-exec" {
    command = <<-EOF
      aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}
      kubectl apply -f - <<YAML
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: eks-otel-crud-app
  namespace: ${kubernetes_namespace.argocd.metadata[0].name}
spec:
  project: default
  source:
    repoURL: ${var.git_repo_url}
    targetRevision: HEAD
    path: k8s
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
YAML
    EOF
  }

  depends_on = [helm_release.argocd, data.aws_eks_cluster.cluster]
}

resource "null_resource" "argocd_appset" {
  provisioner "local-exec" {
    command = <<-EOF
      aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}
      kubectl apply -f - <<YAML
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: eks-otel-crud-appset
  namespace: ${kubernetes_namespace.argocd.metadata[0].name}
spec:
  generators:
  - git:
      repoURL: ${var.git_repo_url}
      revision: HEAD
      directories:
      - path: environments/*
  template:
    metadata:
      name: '{{path.basename}}'
    spec:
      project: default
      source:
        repoURL: ${var.git_repo_url}
        targetRevision: HEAD
        path: '{{path}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: '{{path.basename}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
YAML
    EOF
  }

  depends_on = [helm_release.argocd, data.aws_eks_cluster.cluster]
}
