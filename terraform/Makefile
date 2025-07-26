# Makefile for EKS with OpenTelemetry Terraform Infrastructure

.PHONY: help init plan apply destroy clean validate fmt check-vars setup-kubectl

# Default target
help: ## Show this help message
	@echo "EKS with OpenTelemetry - Terraform Infrastructure"
	@echo "================================================="
	@echo ""
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

init: ## Initialize Terraform
	@echo "🚀 Initializing Terraform..."
	terraform init

validate: ## Validate Terraform configuration
	@echo "✅ Validating Terraform configuration..."
	terraform validate

fmt: ## Format Terraform files
	@echo "🎨 Formatting Terraform files..."
	terraform fmt -recursive

check-vars: ## Check if terraform.tfvars exists
	@if [ ! -f terraform.tfvars ]; then \
		echo "❌ terraform.tfvars not found!"; \
		echo "💡 Copy terraform.tfvars.example to terraform.tfvars and customize it"; \
		echo "   cp terraform.tfvars.example terraform.tfvars"; \
		exit 1; \
	fi

plan: check-vars ## Plan Terraform deployment
	@echo "📋 Planning Terraform deployment..."
	terraform plan

apply: check-vars ## Apply Terraform configuration
	@echo "🚀 Applying Terraform configuration..."
	@echo "⚠️  This will create AWS resources that may incur costs!"
	@read -p "Continue? (y/N): " confirm && [ "$$confirm" = "y" ]
	terraform apply

setup-kubectl: ## Configure kubectl for the EKS cluster
	@echo "⚙️  Configuring kubectl..."
	@CLUSTER_NAME=$$(terraform output -raw cluster_name 2>/dev/null) && \
	REGION=$$(terraform output -raw aws_region 2>/dev/null || echo "us-west-2") && \
	aws eks update-kubeconfig --region $$REGION --name $$CLUSTER_NAME && \
	echo "✅ kubectl configured for cluster: $$CLUSTER_NAME"

status: ## Show cluster and service status
	@echo "📊 Cluster and Service Status"
	@echo "============================="
	@echo ""
	@echo "🏗️  Infrastructure Status:"
	@kubectl get nodes 2>/dev/null || echo "❌ kubectl not configured or cluster not accessible"
	@echo ""
	@echo "📦 Monitoring Pods:"
	@kubectl get pods -n monitoring 2>/dev/null || echo "❌ Monitoring namespace not found"
	@echo ""
	@echo "🔍 Tracing Pods:"
	@kubectl get pods -n tracing 2>/dev/null || echo "❌ Tracing namespace not found"
	@echo ""
	@echo "🚀 ArgoCD Pods:"
	@kubectl get pods -n argocd 2>/dev/null || echo "❌ ArgoCD namespace not found"

access-info: ## Show service access information
	@echo "🌐 Service Access Information"
	@echo "============================="
	@echo ""
	@echo "📊 Grafana Dashboard:"
	@echo "   kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80"
	@echo "   URL: http://localhost:3000"
	@echo "   Username: admin"
	@echo "   Password: (from terraform.tfvars)"
	@echo ""
	@echo "🚀 ArgoCD UI:"
	@echo "   kubectl port-forward svc/argocd-server -n argocd 8080:443"
	@echo "   URL: https://localhost:8080"
	@echo "   Username: admin"
	@echo "   Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
	@echo ""
	@echo "🔍 Tempo Tracing:"
	@echo "   kubectl port-forward svc/tempo -n tracing 3100:3100"
	@echo "   URL: http://localhost:3100"

destroy: ## Destroy all infrastructure
	@echo "🗑️  Destroying Terraform infrastructure..."
	@echo "⚠️  This will permanently delete ALL resources and data!"
	@echo "⚠️  This action cannot be undone!"
	@read -p "Are you absolutely sure? Type 'yes' to confirm: " confirm && [ "$$confirm" = "yes" ]
	terraform destroy

clean: ## Clean Terraform files
	@echo "🧹 Cleaning Terraform files..."
	rm -rf .terraform/
	rm -f .terraform.lock.hcl
	rm -f terraform.tfstate*
	rm -f *.tfplan

setup: init check-vars plan ## Complete setup: init, check vars, and plan
	@echo "✅ Setup complete! Run 'make apply' to deploy infrastructure."

quick-start: setup apply setup-kubectl status ## Quick start: setup and deploy everything
	@echo "🎉 Quick start complete!"
	@echo ""
	@make access-info

# Development targets
dev-apply: ## Apply with auto-approve (for development only)
	@echo "⚠️  Development mode: Auto-approving Terraform apply"
	terraform apply -auto-approve

dev-destroy: ## Destroy with auto-approve (for development only)
	@echo "⚠️  Development mode: Auto-approving Terraform destroy"
	terraform destroy -auto-approve
