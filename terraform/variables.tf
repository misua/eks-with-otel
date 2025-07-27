# Variables for EKS with OpenTelemetry Infrastructure

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-west-2"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "eks-otel-crud"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28"
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "private_subnets" {
  description = "Private subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnets" {
  description = "Public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

# EKS Node Group Configuration
variable "node_instance_types" {
  description = "Instance types for EKS node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_group_min_size" {
  description = "Minimum number of nodes in the node group"
  type        = number
  default     = 1
}

variable "node_group_max_size" {
  description = "Maximum number of nodes in the node group"
  type        = number
  default     = 4
}

variable "node_group_desired_size" {
  description = "Desired number of nodes in the node group"
  type        = number
  default     = 2
}

# Storage Configuration
variable "storage_class" {
  description = "Storage class for persistent volumes"
  type        = string
  default     = "gp2"
}

# EKS Addons
variable "ebs_csi_driver_version" {
  description = "Version of the EBS CSI driver addon"
  type        = string
  default     = "v1.24.0-eksbuild.1"
}

# Helm Chart Versions
variable "prometheus_chart_version" {
  description = "Version of the kube-prometheus-stack Helm chart"
  type        = string
  default     = "51.2.0"
}

variable "tempo_chart_version" {
  description = "Version of the Grafana Tempo Helm chart"
  type        = string
  default     = "1.6.2"
}

variable "otel_collector_chart_version" {
  description = "Version of the OpenTelemetry Collector Helm chart"
  type        = string
  default     = "0.88.0"
}

variable "loki_chart_version" {
  description = "Version of the Loki Helm chart"
  type        = string
  default     = "5.41.4"
}

variable "promtail_chart_version" {
  description = "Version of the Promtail Helm chart"
  type        = string
  default     = "6.15.3"
}

variable "argocd_chart_version" {
  description = "Version of the ArgoCD Helm chart"
  type        = string
  default     = "5.46.7"
}

# Application Configuration
variable "grafana_admin_password" {
  description = "Admin password for Grafana"
  type        = string
  default     = "admin123"
  sensitive   = true
}

variable "git_repo_url" {
  description = "Git repository URL for ArgoCD applications"
  type        = string
  default     = "https://github.com/yourusername/eks-otel-crud.git"
}

# Tags
variable "additional_tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}
