// ###########################################################################
// SCENARIO: Azure data services published to the internet, in Bicep
//
// Storage account serving blobs anonymously over plain HTTP, SQL Server with a
// firewall spanning the whole IPv4 space and auditing off, PostgreSQL with SSL
// not enforced, Cosmos DB reachable from any network, and a Key Vault with no
// purge protection and open network ACLs.
//
// Attack path this models:
//   attacker enumerates the storage account -> anonymous container listing
//   -> downloads backups; separately :1433 reachable -> credential spray
//
// DO NOT DEPLOY.
// ###########################################################################

targetScope = 'resourceGroup'

param location string = resourceGroup().location

@description('Literal default password instead of a @secure() param')
param adminPassword string = 'Password123!'

// Storage account: HTTP allowed, TLS 1.0, anonymous blob access, open firewall
resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'scenariopublicdata'
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
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storage
  name: 'default'
  properties: {
    // No soft delete for blobs or containers
    deleteRetentionPolicy: {
      enabled: false
    }
    containerDeleteRetentionPolicy: {
      enabled: false
    }
  }
}

// Container allowing anonymous listing of every blob inside it
resource publicContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'backups'
  properties: {
    publicAccess: 'Container'
  }
}

// SQL Server open to the entire IPv4 internet
resource sqlServer 'Microsoft.Sql/servers@2023-05-01-preview' = {
  name: 'scenario-public-sql'
  location: location
  properties: {
    administratorLogin: 'sqladmin'
    administratorLoginPassword: adminPassword
    minimalTlsVersion: '1.0'
    publicNetworkAccess: 'Enabled'
  }
}

resource sqlAllowTheInternet 'Microsoft.Sql/servers/firewallRules@2023-05-01-preview' = {
  parent: sqlServer
  name: 'AllowTheWholeInternet'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '255.255.255.255'
  }
}

resource sqlDb 'Microsoft.Sql/servers/databases@2023-05-01-preview' = {
  parent: sqlServer
  name: 'scenario-public-db'
  location: location
  sku: {
    name: 'S0'
    tier: 'Standard'
  }
}

// Auditing explicitly disabled, so there is no record of access
resource sqlAudit 'Microsoft.Sql/servers/auditingSettings@2023-05-01-preview' = {
  parent: sqlServer
  name: 'default'
  properties: {
    state: 'Disabled'
  }
}

// PostgreSQL flexible server with public access and no geo-redundant backup
resource postgres 'Microsoft.DBforPostgreSQL/flexibleServers@2023-03-01-preview' = {
  name: 'scenario-public-pg'
  location: location
  sku: {
    name: 'Standard_B1ms'
    tier: 'Burstable'
  }
  properties: {
    version: '14'
    administratorLogin: 'pgadmin'
    administratorLoginPassword: adminPassword
    storage: {
      storageSizeGB: 32
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    network: {
      publicNetworkAccess: 'Enabled'
    }
  }
}

resource postgresAllowAll 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2023-03-01-preview' = {
  parent: postgres
  name: 'AllowAll'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '255.255.255.255'
  }
}

// Cosmos DB reachable from any network, with local auth still enabled
resource cosmos 'Microsoft.DocumentDB/databaseAccounts@2023-11-15' = {
  name: 'scenario-public-cosmos'
  location: location
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    publicNetworkAccess: 'Enabled'
    isVirtualNetworkFilterEnabled: false
    disableLocalAuth: false
    disableKeyBasedMetadataWriteAccess: false
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
      }
    ]
    ipRules: []
  }
}

// Key Vault with no purge protection, no soft delete, and open network ACLs
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: 'scenario-public-kv'
  location: location
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableSoftDelete: false
    enablePurgeProtection: false
    enabledForDeployment: true
    enabledForTemplateDeployment: true
    enabledForDiskEncryption: true
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
  }
}

// Secret written as a literal value in the template
resource dbSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'db-password'
  properties: {
    value: 'Password123!'
  }
}

output storageAccountName string = storage.name
