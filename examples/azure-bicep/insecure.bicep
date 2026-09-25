// Platform: Azure Bicep
// Purpose: Intentionally insecure Azure resources to demonstrate FCS CLI
//          IaC detections. DO NOT DEPLOY.

@description('Deployment location')
param location string = resourceGroup().location

@description('Plaintext admin password default - Secret Management finding')
param adminPassword string = 'Password123!'

// Storage account: HTTP allowed, TLS 1.0, public blob access, open firewall
// Categories: Encryption, Access Control, Networking and Firewall
resource insecureStorage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'fcsdemobicepsa'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: false
    minimumTlsVersion: 'TLS1_0'
    allowBlobPublicAccess: true
    allowSharedKeyAccess: true
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
    encryption: {
      services: {
        blob: {
          enabled: false
        }
        file: {
          enabled: false
        }
      }
    }
  }
}

resource publicContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: '${insecureStorage.name}/default/fcs-demo-public'
  properties: {
    publicAccess: 'Container'
  }
}

// NSG: SSH/RDP open to the Internet
// Category: Networking and Firewall
resource wideOpenNsg 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: 'fcs-demo-bicep-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowSSHFromInternet'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowRDPFromInternet'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowAllInbound'
        properties: {
          priority: 120
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '0.0.0.0/0'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

// Linux VM: password auth enabled, hardcoded password, unencrypted disk
// Categories: Access Control, Secret Management, Encryption
resource insecureVm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: 'fcs-demo-bicep-vm'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v3'
    }
    osProfile: {
      computerName: 'fcsdemovm'
      adminUsername: 'azureuser'
      adminPassword: adminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
  }
}

// SQL Server: weak password, public access, TLS 1.0, firewall open to all
// Categories: Access Control, Encryption, Networking and Firewall
resource sqlServer 'Microsoft.Sql/servers@2023-05-01-preview' = {
  name: 'fcs-demo-bicep-sql'
  location: location
  properties: {
    administratorLogin: 'sqladmin'
    administratorLoginPassword: adminPassword
    minimalTlsVersion: '1.0'
    publicNetworkAccess: 'Enabled'
  }
}

resource sqlAllowAll 'Microsoft.Sql/servers/firewallRules@2023-05-01-preview' = {
  parent: sqlServer
  name: 'AllowAllIPs'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '255.255.255.255'
  }
}

// Key Vault: no purge protection, no soft delete, open network ACLs
// Categories: Backup, Access Control
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: 'fcs-demo-bicep-kv'
  location: location
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableSoftDelete: false
    enablePurgeProtection: false
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
  }
}

// App Service: HTTPS not enforced, old TLS, remote debugging, FTP allowed
// Categories: Encryption, Insecure Configurations
resource webApp 'Microsoft.Web/sites@2023-01-01' = {
  name: 'fcs-demo-bicep-web'
  location: location
  properties: {
    httpsOnly: false
    siteConfig: {
      minTlsVersion: '1.0'
      ftpsState: 'AllAllowed'
      remoteDebuggingEnabled: true
      http20Enabled: false
      appSettings: [
        {
          name: 'DB_CONNECTION_STRING'
          value: 'Server=tcp:fcsdemo.database.windows.net;User ID=sqladmin;Password=Password123!;'
        }
      ]
    }
  }
}

output storageAccountName string = insecureStorage.name
