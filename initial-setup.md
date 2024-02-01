# initial setup

# Deploy an AKS cluster with workload identity configured

Deploy the AKS cluster via the aks.bicep file.


# Register required resource providers on Azure.
        az provider register --namespace Microsoft.ContainerService
        az provider register --namespace Microsoft.Network
        az provider register --namespace Microsoft.NetworkFunction
        az provider register --namespace Microsoft.ServiceNetworking

# Install Azure CLI extensions.
        az extension add --name alb


# Obtain information about the ALB, the ALB frontend, ALB identity, and the federated credentials
AKS_NAME="aks-agc-eastus-001" #cluster name
RESOURCE_GROUP="rg-agc-eastus-002" #cluster resource group
ALB="alb1" #alb resource name
IDENTITY_RESOURCE_NAME='azure-alb-identity' # alb controller identity


SUB_ID=$(az account show --query id -o tsv) #subscriptionid    

ALB_SUBNET_ID="/subscriptions/$SUB_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/virtualNetworks/$RESOURCE_GROUP-vnet/subnets/ing-4-subnet" #subnet resource id of your ALB subnet

NODE_GROUP=$(az aks show --resource-group $RESOURCE_GROUP --name $AKS_NAME --query "nodeResourceGroup" -o tsv) #infrastructure resource group of your cluster

AKS_OIDC_ISSUER="$(az aks show -n "$AKS_NAME" -g "$RESOURCE_GROUP" --query "oidcIssuerProfile.issuerUrl" -o tsv)" # oidc issuer url of your cluster