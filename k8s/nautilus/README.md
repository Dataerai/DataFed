# DataFed Nautilus NRP Deployment

This directory contains Kubernetes manifests for deploying DataFed on the Nautilus National Research Platform (NRP).

## Overview

DataFed is a federated data management system that consists of several microservices:
- **datafed-web**: Web interface and API gateway
- **datafed-core**: Core business logic and orchestration
- **datafed-foxx**: Database service layer (ArangoDB Foxx services)
- **arango**: ArangoDB database

## Prerequisites

1. Access to a Nautilus NRP namespace
2. kubectl configured to access your Nautilus cluster
3. Container images built and pushed to a container registry accessible by Nautilus
4. TLS certificates for your domain (optional, can use Let's Encrypt)

## Nautilus Resource Constraints

This deployment is optimized for Nautilus NRP constraints:
- Maximum 2 GPUs per pod (not used by DataFed)
- Maximum 32 GB RAM per pod
- Maximum 16 CPU cores per pod
- Maximum 6 hours runtime for single pods
- Maximum 2 weeks runtime for deployments

## Storage Configuration

The deployment uses Nautilus Ceph storage:
- **rook-cephfs**: For shared storage (logs, keys)
- **rook-ceph-block**: For database and application data

Storage allocations:
- ArangoDB: 50Gi (block storage)
- Logs: 10Gi (shared filesystem)
- Keys: 1Gi (shared filesystem)
- Foxx temp: 5Gi (block storage)

## Deployment Steps

### 1. Configure Secrets and Environment

Edit the following files with your specific configuration:

**secret.yaml:**
```bash
# Replace placeholders with actual values
DATAFED_GLOBUS_APP_SECRET: "your_globus_app_secret"
DATAFED_GLOBUS_APP_ID: "your_globus_app_id"
DATAFED_ZEROMQ_SESSION_SECRET: "your_session_secret"
DATAFED_ZEROMQ_SYSTEM_SECRET: "your_system_secret"
DATAFED_DATABASE_PASSWORD: "your_database_password"
```

**configmap.yaml:**
```bash
# Update domain configuration
DATAFED_DOMAIN: "your-domain.com"
```

**ingress.yaml:**
```bash
# Update domain in ingress rules
- host: your-domain.com
- host: arango.your-domain.com
```

### 2. Build and Push Container Images

Ensure your DataFed container images are available in a registry accessible by Nautilus:

```bash
# Build images (from DataFed root directory)
docker build -f web/docker/Dockerfile -t your-registry/datafed-web:latest .
docker build -f core/docker/Dockerfile -t your-registry/datafed-core:latest .
docker build -f docker/Dockerfile.foxx -t your-registry/datafed-foxx:latest .

# Push to registry
docker push your-registry/datafed-web:latest
docker push your-registry/datafed-core:latest
docker push your-registry/datafed-foxx:latest
```

Update deployment manifests with your image URLs.

### 3. Deploy to Nautilus

Apply the manifests in order:

```bash
# Create namespace
kubectl apply -f namespace.yaml

# Create storage
kubectl apply -f persistent-volumes.yaml

# Create configuration
kubectl apply -f configmap.yaml
kubectl apply -f secret.yaml

# Deploy database first
kubectl apply -f arango-deployment.yaml

# Wait for ArangoDB to be ready
kubectl wait --for=condition=ready pod -l app=arango -n datafed --timeout=300s

# Deploy Foxx services
kubectl apply -f datafed-foxx-deployment.yaml

# Wait for Foxx to be ready
kubectl wait --for=condition=ready pod -l app=datafed-foxx -n datafed --timeout=300s

# Deploy core services
kubectl apply -f datafed-core-deployment.yaml

# Wait for core to be ready
kubectl wait --for=condition=ready pod -l app=datafed-core -n datafed --timeout=300s

# Deploy web interface
kubectl apply -f datafed-web-deployment.yaml

# Configure networking
kubectl apply -f network-policy.yaml
kubectl apply -f ingress.yaml
```

### 4. Verify Deployment

Check that all services are running:

```bash
kubectl get pods -n datafed
kubectl get services -n datafed
kubectl get ingress -n datafed
```

Access the web interface at `https://your-domain.com`

## SSL/TLS Configuration

### Option 1: Let's Encrypt (Recommended)

The ingress is configured to use cert-manager with Let's Encrypt. Ensure cert-manager is installed in your cluster and the cluster issuer exists.

### Option 2: Custom Certificates

If using custom certificates, create a TLS secret:

```bash
kubectl create secret tls datafed-tls --cert=path/to/cert.pem --key=path/to/key.pem -n datafed
```

## Monitoring and Logging

Monitor your deployment:

```bash
# View logs
kubectl logs -f deployment/datafed-web -n datafed
kubectl logs -f deployment/datafed-core -n datafed
kubectl logs -f deployment/datafed-foxx -n datafed
kubectl logs -f deployment/arango -n datafed

# Check resource usage
kubectl top pods -n datafed
```

## Scaling Considerations

For production deployments on Nautilus:

1. **Database**: ArangoDB can be clustered for high availability
2. **Core Services**: Can run multiple replicas with load balancing
3. **Web Interface**: Easily scalable with multiple replicas
4. **Storage**: Use larger PVC sizes for production workloads

## Troubleshooting

### Common Issues

1. **Pod Stuck in Pending**: Check resource requests and node availability
2. **ImagePullBackOff**: Verify image URLs and registry access
3. **Database Connection Issues**: Check network policies and service discovery
4. **Certificate Issues**: Verify cert-manager configuration and DNS

### Useful Commands

```bash
# Describe resources for detailed error messages
kubectl describe pod <pod-name> -n datafed

# Check events
kubectl get events -n datafed --sort-by='.lastTimestamp'

# Access pod shell for debugging
kubectl exec -it <pod-name> -n datafed -- /bin/bash

# Check service connectivity
kubectl run debug --image=nicolaka/netshoot -it --rm -n datafed -- /bin/bash
```

## Security Considerations

1. **Network Policies**: Restrict inter-pod communication
2. **Secrets Management**: Use external secret management for production
3. **RBAC**: Configure appropriate service accounts and roles
4. **Image Security**: Scan container images for vulnerabilities
5. **TLS**: Ensure all communication is encrypted

## Cleanup

To remove the entire deployment:

```bash
kubectl delete namespace datafed
```

This will remove all resources including persistent volumes and data.

## Support

For issues specific to:
- **DataFed**: Refer to the main DataFed documentation
- **Nautilus NRP**: Contact NRP support or check their documentation
- **Kubernetes**: Check Kubernetes documentation and community resources