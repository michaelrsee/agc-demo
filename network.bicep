param location string = 'eastus' // You can change the location as needed
param vnetName string = 'vnet-aks-eastus-001' // Change the VNet name if you want
param addressPrefix string = '10.0.0.0/16' // The address space for the VNet

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  location: location
  name: vnetName
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [
      {
        name: 'SystemSubnet'
        properties: {
          addressPrefix: '10.0.1.0/24'
        }
      }
      {
        name: 'UserSubnet'
        properties: {
          addressPrefix: '10.0.2.0/24'
        }
      }
      {
        name: 'PodSubnet'
        properties: {
          addressPrefix: '10.0.3.0/24'
        }
      }
      {
        name: 'ApiServerSubnet'
        properties: {
          addressPrefix: '10.0.4.0/24'
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.0.5.0/24'
        }
      }
      {
        name: 'VmSubnet'
        properties: {
          addressPrefix: '10.0.6.0/24'
        }
      }
      {
        name: 'AppGwForConSubnet'
        properties: {
          addressPrefix: '10.0.7.0/24'
        }
      }
    ]
  }
}

output vnetId string = virtualNetwork.id
