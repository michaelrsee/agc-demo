/*** PARAMS ***/

param aksName string = 'aks-agc-eastus-001' // Change to your desired AKS cluster name
param location string = 'eastus' // Set your desired location
param nodeVmSize string = 'Standard_DS2_v2' // Set VM size for AKS nodes
param networkPlugin string = 'azure' // Set network plugin ('azure' or 'kubenet')
param dnsPrefix string = 'aks-agc-eastus-001' // DNS prefix for AKS
param spokeResourceGroupName string = 'rg-agc-eastus-002' // Name of the network spoke resource group



/*** EXISTING RESOURCES ***/

// Spoke Resource Group
resource spokeResourceGroup 'Microsoft.Resources/resourceGroups@2023-07-01' existing = {
  scope: subscription()
  name: spokeResourceGroupName
}

// Spoke Virtual Network
resource spokeVirtualNetwork 'Microsoft.Network/virtualNetworks@2023-06-01' existing = {
  scope: spokeResourceGroup
  name: 'vnet-aks-eastus-001'

  // Spoke Subnet For The Cluster Nodes
  resource snetSystemSubnet 'subnets' existing = {
    name: 'SystemSubnet'
    }
  
  resource snetUserSubnet 'subnets' existing = {
    name: 'UserSubnet'
  }

  resource snetPodSubnet 'subnets' existing = {
    name: 'PodSubnet'
  }
}



/*** RESOURCES ***/

resource aksCluster 'Microsoft.ContainerService/managedClusters@2023-10-01' = {
  name: aksName
  location: location
  properties: {
    kubernetesVersion: '1.28.0' // Specify your desired Kubernetes version
    enableRBAC: true
    dnsPrefix: dnsPrefix
    servicePrincipalProfile:{
      clientId: '27db965f-3d95-416b-ba6a-2ce876722d0e'
      secret: 'GZf8Q~j.~DK0qXaS6EBF.iSh~Z~JUjDBpoAWUb2~'
    } 
    agentPoolProfiles: [
      {
        name: 'npsystem'
        count: 1 // Number of nodes
        vmSize: nodeVmSize
        osType: 'Linux'
        type: 'VirtualMachineScaleSets'
        mode: 'System'
        vnetSubnetID: spokeVirtualNetwork::snetSystemSubnet.id
        orchestratorVersion: '1.28.0'
        enableNodePublicIP: false
        nodeTaints: [
          'CriticalAddonsOnly=true:NoSchedule'
        ]
      }
      {
        name: 'npuser'
        count: 1
        vmSize: nodeVmSize
        osType: 'Linux'
        type: 'VirtualMachineScaleSets'
        mode: 'User'
        vnetSubnetID: spokeVirtualNetwork::snetUserSubnet.id
        orchestratorVersion: '1.28.0'
        enableNodePublicIP: false
      }
    ]
    networkProfile: {
      networkPlugin: networkPlugin
      networkPolicy: 'azure'
      loadBalancerSku: 'standard'
      loadBalancerProfile: null
      serviceCidr: '172.28.0.0/16'
      dnsServiceIP: '172.28.0.10'
      dockerBridgeCidr: '172.29.0.1/16'
    }
    addonProfiles: {
      httpApplicationRouting: {
        enabled: false
      }
    }
    oidcIssuerProfile: {
      enabled: true
    }
    securityProfile: {
      workloadIdentity: {
        enabled: true
      }
    }
  }
}
