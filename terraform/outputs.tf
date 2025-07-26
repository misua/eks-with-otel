# Outputs for EKS with OpenTelemetry Infrastructure

output "cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_id
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = module.eks.cluster_arn
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "cluster_iam_role_name" {
  description = "IAM role name associated with EKS cluster"
  value       = module.eks.cluster_iam_role_name
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_primary_security_group_id" {
  description = "Cluster security group that was created by Amazon EKS for the cluster"
  value       = module.eks.cluster_primary_security_group_id
}

output "vpc_id" {
  description = "ID of the VPC where the cluster is deployed"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = module.vpc.public_subnets
}

output "node_groups" {
  description = "EKS node groups"
  value       = module.eks.eks_managed_node_groups
}

output "oidc_provider_arn" {
  description = "The ARN of the OIDC Provider if enabled"
  value       = module.eks.oidc_provider_arn
}

# Application Access Information
output "grafana_access_info" {
  description = "Information for accessing Grafana"
  value = {
    port_forward_command = "kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80"
    username            = "admin"
    password            = var.grafana_admin_password
  }
  sensitive = true
}

output "argocd_access_info" {
  description = "Information for accessing ArgoCD"
  value = {
    port_forward_command = "kubectl port-forward svc/argocd-server -n argocd 8080:443"
    username            = "admin"
    password_command    = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
  }
}

output "tempo_access_info" {
  description = "Information for accessing Tempo"
  value = {
    port_forward_command = "kubectl port-forward svc/tempo -n tracing 3100:3100"
    query_endpoint      = "http://localhost:3100"
  }
}

output "kubectl_config_command" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

# Monitoring and Observability Endpoints
output "monitoring_endpoints" {
  description = "Monitoring and observability service endpoints"
  value = {
    prometheus = {
      service_name = "prometheus-kube-prometheus-prometheus"
      namespace   = "monitoring"
      port        = 9090
    }
    grafana = {
      service_name = "prometheus-grafana"
      namespace   = "monitoring"
      port        = 80
    }
    tempo = {
      service_name = "tempo"
      namespace   = "tracing"
      port        = 3100
    }
    argocd = {
      service_name = "argocd-server"
      namespace   = "argocd"
      port        = 443
    }
  }
}
