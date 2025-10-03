#!/bin/bash

# DataFed Nautilus NRP Deployment Script
# This script deploys DataFed to the Nautilus National Research Platform

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="datafed"
TIMEOUT="300s"

echo -e "${GREEN}🚀 Starting DataFed deployment to Nautilus NRP${NC}"

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl is not installed or not in PATH${NC}"
    exit 1
fi

# Check if we can connect to the cluster
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}❌ Cannot connect to Kubernetes cluster${NC}"
    echo "Please ensure kubectl is configured for Nautilus NRP"
    exit 1
fi

echo -e "${GREEN}✅ Connected to Kubernetes cluster${NC}"

# Function to wait for deployment
wait_for_deployment() {
    local app_name=$1
    echo -e "${YELLOW}⏳ Waiting for $app_name to be ready...${NC}"
    kubectl wait --for=condition=ready pod -l app=$app_name -n $NAMESPACE --timeout=$TIMEOUT
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ $app_name is ready${NC}"
    else
        echo -e "${RED}❌ $app_name failed to become ready within $TIMEOUT${NC}"
        kubectl get pods -l app=$app_name -n $NAMESPACE
        kubectl logs -l app=$app_name -n $NAMESPACE --tail=20
        exit 1
    fi
}

# Function to check if secret is properly configured
check_secrets() {
    echo -e "${YELLOW}🔍 Checking secret configuration...${NC}"

    # Check if secret exists and has required keys
    if kubectl get secret datafed-secrets -n $NAMESPACE &> /dev/null; then
        local secret_keys=$(kubectl get secret datafed-secrets -n $NAMESPACE -o jsonpath='{.data}' | jq -r 'keys[]' 2>/dev/null || echo "")

        required_keys=("DATAFED_GLOBUS_APP_SECRET" "DATAFED_GLOBUS_APP_ID" "DATAFED_ZEROMQ_SESSION_SECRET" "DATAFED_ZEROMQ_SYSTEM_SECRET" "DATAFED_DATABASE_PASSWORD")

        for key in "${required_keys[@]}"; do
            if [[ ! $secret_keys =~ $key ]]; then
                echo -e "${RED}❌ Missing required secret key: $key${NC}"
                echo "Please update secret.yaml with proper values"
                exit 1
            fi
        done
        echo -e "${GREEN}✅ Secret configuration looks good${NC}"
    fi
}

# Check configuration
echo -e "${YELLOW}🔧 Checking configuration...${NC}"

if [ ! -f "secret.yaml" ]; then
    echo -e "${RED}❌ secret.yaml not found${NC}"
    exit 1
fi

if [ ! -f "configmap.yaml" ]; then
    echo -e "${RED}❌ configmap.yaml not found${NC}"
    exit 1
fi

# Check if placeholder values are still in secret.yaml
if grep -q "YOUR_" secret.yaml; then
    echo -e "${RED}❌ Please update secret.yaml with actual values (found placeholder values)${NC}"
    exit 1
fi

# Check if placeholder values are still in configmap.yaml
if grep -q "your-domain.com" configmap.yaml; then
    echo -e "${YELLOW}⚠️  Warning: Found placeholder domain in configmap.yaml${NC}"
    echo "Please update DATAFED_DOMAIN with your actual domain"
fi

echo -e "${GREEN}✅ Configuration files found${NC}"

# Deploy step by step
echo -e "${GREEN}📦 Step 1: Creating namespace${NC}"
kubectl apply -f namespace.yaml

echo -e "${GREEN}📦 Step 2: Creating storage${NC}"
kubectl apply -f persistent-volumes.yaml

echo -e "${GREEN}📦 Step 3: Creating configuration${NC}"
kubectl apply -f configmap.yaml
kubectl apply -f secret.yaml

check_secrets

echo -e "${GREEN}📦 Step 4: Deploying ArangoDB${NC}"
kubectl apply -f arango-deployment.yaml
wait_for_deployment "arango"

echo -e "${GREEN}📦 Step 5: Deploying Foxx services${NC}"
kubectl apply -f datafed-foxx-deployment.yaml
wait_for_deployment "datafed-foxx"

echo -e "${GREEN}📦 Step 6: Deploying Core services${NC}"
kubectl apply -f datafed-core-deployment.yaml
wait_for_deployment "datafed-core"

echo -e "${GREEN}📦 Step 7: Deploying Web interface${NC}"
kubectl apply -f datafed-web-deployment.yaml
wait_for_deployment "datafed-web"

echo -e "${GREEN}📦 Step 8: Configuring networking${NC}"
kubectl apply -f network-policy.yaml
kubectl apply -f ingress.yaml

# Final status check
echo -e "${GREEN}🎉 Deployment completed successfully!${NC}"
echo ""
echo -e "${YELLOW}📊 Deployment Status:${NC}"
kubectl get pods -n $NAMESPACE
echo ""
kubectl get services -n $NAMESPACE
echo ""
kubectl get ingress -n $NAMESPACE

echo ""
echo -e "${GREEN}🌐 Access Information:${NC}"
DOMAIN=$(kubectl get configmap datafed-config -n $NAMESPACE -o jsonpath='{.data.DATAFED_DOMAIN}')
echo "DataFed Web Interface: https://$DOMAIN"
echo "ArangoDB Admin: https://arango.$DOMAIN"

echo ""
echo -e "${YELLOW}📝 Next Steps:${NC}"
echo "1. Ensure DNS is pointing to your Nautilus ingress"
echo "2. Wait for TLS certificates to be issued (if using Let's Encrypt)"
echo "3. Access the web interface and complete DataFed setup"
echo ""
echo -e "${GREEN}🎊 Happy DataFed-ing on Nautilus NRP!${NC}"