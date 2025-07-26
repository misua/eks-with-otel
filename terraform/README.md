# EKS with OpenTelemetry - Terraform Infrastructure

This Terraform configuration creates the same infrastructure as the `setup-infrastructure.sh` script but using Infrastructure as Code (IaC) principles for better management, reproducibility, and version control.

## 🏗️ Infrastructure Components

This Terraform configuration deploys:

- **EKS Cluster** with managed node groups
- **VPC** with public and private subnets
- **Prometheus/Grafana** monitoring stack
- **Grafana Tempo** for distributed tracing
- **ArgoCD** for GitOps deployment
- **EBS CSI Driver** for persistent storage
- **Kubernetes namespaces** for organization

## 📋 Prerequisites

1. **AWS CLI** configured with appropriate permissions
2. **Terraform** >= 1.0 installed
3. **kubectl** installed
4. **Helm** >= 3.0 installed

### Required AWS Permissions

Your AWS credentials need the following permissions:
- EKS cluster management
- EC2 and VPC management
- IAM role and policy management
- EBS volume management

## 🚀 Quick Start

### 1. Clone and Navigate

```bash
cd terraform
```

### 2. Configure Variables

```bash
# Copy the example variables file
cp terraform.tfvars.example terraform.tfvars

# Edit the variables to match your requirements
nano terraform.tfvars
```

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Plan the Deployment

```bash
terraform plan
```

### 5. Apply the Configuration

```bash
terraform apply
```

### 6. Configure kubectl

```bash
# Use the output command to configure kubectl
aws eks update-kubeconfig --region us-west-2 --name eks-otel-crud-dev
```

## 📊 Accessing Services

After deployment, use these commands to access your services:

### Grafana Dashboard
```bash
kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80
# Access: http://localhost:3000
# Username: admin
# Password: (from terraform.tfvars)
```

### ArgoCD UI
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Access: https://localhost:8080
# Username: admin
# Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```

### Tempo Tracing
```bash
kubectl port-forward svc/tempo -n tracing 3100:3100
# Access: http://localhost:3100
```

## 🗂️ File Structure

```
terraform/
├── main.tf                    # Main Terraform configuration
├── variables.tf               # Variable definitions
├── outputs.tf                 # Output definitions
├── versions.tf                # Provider version constraints
├── terraform.tfvars.example   # Example variables file
├── README.md                  # This file
└── values/                    # Helm chart values
    ├── prometheus-values.yaml # Prometheus/Grafana configuration
    ├── tempo-values.yaml      # Tempo configuration
    └── argocd-values.yaml     # ArgoCD configuration
```

## ⚙️ Configuration Options

### Key Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `aws_region` | AWS region | `us-west-2` |
| `cluster_name` | EKS cluster name | `eks-otel-crud` |
| `environment` | Environment name | `dev` |
| `node_instance_types` | EC2 instance types | `["t3.medium"]` |
| `grafana_admin_password` | Grafana admin password | `admin123` |
| `storage_class` | Storage class for PVs | `gp2` |

### Customizing Helm Charts

To customize the Helm chart configurations, edit the files in the `values/` directory:

- `prometheus-values.yaml` - Prometheus and Grafana settings
- `tempo-values.yaml` - Tempo tracing configuration
- `argocd-values.yaml` - ArgoCD GitOps settings

## 🔄 Updating Infrastructure

To update your infrastructure:

```bash
# Plan the changes
terraform plan

# Apply the changes
terraform apply
```

## 🗑️ Destroying Infrastructure

To completely remove all infrastructure:

```bash
# Destroy all resources
terraform destroy
```

**⚠️ Warning**: This will permanently delete all resources and data!

## 📈 Monitoring and Observability

### Prometheus Metrics
- Cluster metrics via kube-state-metrics
- Node metrics via node-exporter
- Application metrics via ServiceMonitor CRDs

### Grafana Dashboards
- Pre-configured Kubernetes dashboards
- Custom dashboard support
- Tempo integration for trace visualization

### Distributed Tracing
- OTLP protocol support (HTTP: 4318, gRPC: 4317)
- Jaeger protocol compatibility
- Local filesystem storage for development

## 🔧 Troubleshooting

### Common Issues

1. **Storage Class Issues**
   - Ensure `gp2` storage class exists in your cluster
   - Check EBS CSI driver installation

2. **Network Connectivity**
   - Verify VPC and subnet configuration
   - Check security group rules

3. **Helm Chart Failures**
   - Check Helm chart versions in `variables.tf`
   - Verify values files syntax

### Debugging Commands

```bash
# Check cluster status
kubectl get nodes

# Check pod status
kubectl get pods --all-namespaces

# Check Helm releases
helm list --all-namespaces

# View Terraform state
terraform show
```

## 🔐 Security Considerations

- **Secrets Management**: Consider using AWS Secrets Manager for sensitive data
- **Network Security**: Review security group rules and network policies
- **RBAC**: Configure appropriate Kubernetes RBAC policies
- **Encryption**: Enable encryption at rest for EBS volumes

## 🚀 Production Readiness

For production deployments, consider:

1. **Remote State Backend**: Configure S3 backend in `versions.tf`
2. **Multi-Environment**: Use Terraform workspaces or separate configurations
3. **Monitoring**: Set up proper alerting and monitoring
4. **Backup**: Implement backup strategies for persistent data
5. **High Availability**: Configure multi-AZ deployments

## 📚 Additional Resources

- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [EKS Module Documentation](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest)
- [Prometheus Operator Documentation](https://prometheus-operator.dev/)
- [Grafana Tempo Documentation](https://grafana.com/docs/tempo/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)

## 🤝 Contributing

When making changes:
1. Update variable descriptions and defaults
2. Test with `terraform plan`
3. Update this README if needed
4. Follow Terraform best practices

## 📄 License

This configuration is provided as-is for educational and development purposes.
