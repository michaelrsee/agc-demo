# initial setup

# Deploy an AKS cluster with workload identity configured

Deploy the AKS cluster via the aks.bicep file.


# Register required resource providers on Azure.
        az provider register --namespace Microsoft.ContainerService
        az provider register --namespace Microsoft.Network
        az provider register --namespace Microsoft.NetworkFunction
        az provider register --namespace Microsoft.ServiceNetworking

        az provider show --namespace Microsoft.ContainerService
        az provider show --namespace Microsoft.Network
        az provider show --namespace Microsoft.NetworkFunction
        az provider show --namespace Microsoft.ServiceNetworking

# Install Azure CLI extensions.
        az extension add --name alb


# Obtain information about the ALB, the ALB frontend, ALB identity, and the federated credentials
AKS_NAME="aks-agc-eastus-001" #cluster name
RESOURCE_GROUP="rg-agc-eastus-002" #cluster resource group
ALB="alb1" #alb resource name
IDENTITY_RESOURCE_NAME='azure-alb-identity' # alb controller identity


SUB_ID=$(az account show --query id -o tsv) #subscriptionid    

ALB_SUBNET_ID="/subscriptions/$SUB_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/virtualNetworks/vnet-aks-eastus-001/subnets/AppGWForConSubnet" #subnet resource id of your ALB subnet

NODE_GROUP=$(az aks show --resource-group $RESOURCE_GROUP --name $AKS_NAME --query "nodeResourceGroup" -o tsv) #infrastructure resource group of your cluster

NODE_GROUP_ID="subscriptions/$SUB_ID/resourceGroups/$NODE_GROUP"  # remove the slash in front of subscriptions

AKS_OIDC_ISSUER="$(az aks show -n "$AKS_NAME" -g "$RESOURCE_GROUP" --query "oidcIssuerProfile.issuerUrl" -o tsv)" # oidc issuer url of your cluster

az identity create --resource-group $RESOURCE_GROUP --name $IDENTITY_RESOURCE_NAME
ALB_PRINCIPAL_ID="$(az identity show -g $RESOURCE_GROUP -n $IDENTITY_RESOURCE_NAME --query principalId -o tsv)"

echo "Waiting 60 seconds to allow for replication of the identity..."
sleep 60

az role assignment create --assignee-object-id $ALB_PRINCIPAL_ID --scope $NODE_GROUP_ID --role "Contributor"

az role assignment create --assignee-object-id $ALB_PRINCIPAL_ID --scope $NODE_GROUP_ID --role "AppGw for Containers Configuration Manager"

az role assignment create --assignee-object-id $ALB_PRINCIPAL_ID --scope $ALB_SUBNET_ID --role "Network Contributor"

az aks get-credentials --resource-group rg-agc-eastus-002 --name aks-agc-eastus-001 --admin 

az identity federated-credential create --name $IDENTITY_RESOURCE_NAME \
     --identity-name "azure-alb-identity" \
     --resource-group $RESOURCE_GROUP \
     --issuer "$AKS_OIDC_ISSUER" \
     --subject "system:serviceaccount:azure-alb-system:alb-controller-sa"

ALB_WL_ID=$(az identity show -g $RESOURCE_GROUP -n azure-alb-identity --query clientId -o tsv)

helm upgrade  \
  --install alb-controller oci://mcr.microsoft.com/application-lb/charts/alb-controller \
  --namespace azure-alb-system --create-namespace \
  --version 0.6.3 \
  --set albController.namespace=azure-alb-system \
  --set albController.podIdentity.clientID=$ALB_WL_ID

kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: $ALB-infra
EOF

kubectl apply -f - <<EOF
apiVersion: alb.networking.azure.io/v1
kind: ApplicationLoadBalancer
metadata:
  name: $ALB
  namespace: $ALB-infra
spec:
  associations:
  - $ALB_SUBNET_ID
EOF

kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1beta1
kind: Gateway
metadata:
  name: gateway-01
  namespace: $ALB-infra
  annotations:
    alb.networking.azure.io/alb-namespace: $ALB-infra
    alb.networking.azure.io/alb-name: $ALB
spec:
  gatewayClassName: azure-alb-external
  listeners:
  - name: http
    port: 80
    protocol: HTTP
    allowedRoutes:
      namespaces:
        from: Selector
        selector:
          matchLabels:
            shared-gateway-access: "true"
EOF

kubectl get applicationloadbalancer $ALB -n $ALB-infra -o yaml 

kubectl get gateway gateway-01 -n $ALB-infra -o yaml

fqdn=$(kubectl get gateway gateway-01 -n $ALB-infra -o jsonpath='{.status.addresses[0].value}')

echo $fqdn

# Deploy calculator application from phoenix repo. 

helm repo add phoenix 'https://raw.githubusercontent.com/denniszielke/phoenix/master/'
helm repo update
helm search repo phoenix 

AZURE_CONTAINER_REGISTRY_NAME=phoenix
KUBERNETES_NAMESPACE=calculator
BUILD_BUILDNUMBER=latest
AZURE_CONTAINER_REGISTRY_URL=denniszielke

kubectl create namespace $KUBERNETES_NAMESPACE
kubectl label namespace $KUBERNETES_NAMESPACE shared-gateway-access=true 

helm upgrade calculator $AZURE_CONTAINER_REGISTRY_NAME/multicalculator --namespace $KUBERNETES_NAMESPACE --install --create-namespace --set replicaCount=2 --set image.frontendTag=$BUILD_BUILDNUMBER --set image.backendTag=$BUILD_BUILDNUMBER --set image.repository=$AZURE_CONTAINER_REGISTRY_URL --set gateway.enabled=true --set gateway.name=gateway-01 --set gateway.namespace=$ALB-infra --set slot=blue

curl http://$fqdn/ping