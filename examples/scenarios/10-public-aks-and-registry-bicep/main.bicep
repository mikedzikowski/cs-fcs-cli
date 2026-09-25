// ###########################################################################
// SCENARIO: Publicly reachable AKS cluster and container registry, in Bicep
//
// AKS with a public API server, RBAC disabled, local admin accounts enabled,
// no network policy, no Azure Monitor, and an SSH-enabled node pool. Paired
// with an ACR that permits anonymous pull and admin-user auth.
//
// Attack path this models:
//   internet -> public API server with RBAC off -> cluster admin
//            -> ACR admin user credentials in cluster -> poison base images
//
// DO NOT DEPLOY.
// ###########################################################################

targetScope = 'resourceGroup'

param location string = resourceGroup().location

// Container registry allowing anonymous pull and the shared admin user
resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: 'scenariopublicacr'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    // Shared admin credential instead of per-identity RBAC
    adminUserEnabled: true
    // Anyone on the internet can pull every image
    anonymousPullEnabled: true
    publicNetworkAccess: 'Enabled'
    dataEndpointEnabled: false
    networkRuleBypassOptions: 'AzureServices'
    policies: {
      // Tags stay mutable, so a pulled digest is not reproducible
      quarantinePolicy: {
        status: 'disabled'
      }
      trustPolicy: {
        type: 'Notary'
        status: 'disabled'
      }
      retentionPolicy: {
        status: 'disabled'
        days: 0
      }
    }
  }
}

// AKS cluster with the control plane on the public internet and RBAC off
resource aks 'Microsoft.ContainerService/managedClusters@2023-10-01' = {
  name: 'scenario-public-aks'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    dnsPrefix: 'scenariopublicaks'
    // Kubernetes RBAC disabled entirely
    enableRBAC: false
    // Local admin kubeconfig accounts remain usable
    disableLocalAccounts: false
    agentPoolProfiles: [
      {
        name: 'nodepool1'
        count: 2
        vmSize: 'Standard_DS2_v2'
        mode: 'System'
        osType: 'Linux'
        // Nodes get public IPs and host-level SSH stays enabled
        enableNodePublicIP: true
        osDiskType: 'Managed'
        enableAutoScaling: false
      }
    ]
    linuxProfile: {
      adminUsername: 'azureuser'
      ssh: {
        publicKeys: [
          {
            keyData: 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQEXAMPLEKEYNOTREAL scenario@demo'
          }
        ]
      }
    }
    apiServerAccessProfile: {
      // Private cluster off and no authorized IP ranges, so the API server is
      // reachable from anywhere on the internet
      enablePrivateCluster: false
      authorizedIPRanges: []
    }
    networkProfile: {
      networkPlugin: 'kubenet'
      // No network policy engine, so pods can talk to everything
      loadBalancerSku: 'standard'
      outboundType: 'loadBalancer'
    }
    addonProfiles: {
      // Container monitoring and policy add-ons disabled
      omsagent: {
        enabled: false
      }
      azurepolicy: {
        enabled: false
      }
    }
  }
}

// Container instance exposing a privileged workload on a public IP
resource aci 'Microsoft.ContainerInstance/containerGroups@2023-05-01' = {
  name: 'scenario-public-aci'
  location: location
  properties: {
    osType: 'Linux'
    restartPolicy: 'Always'
    // Public IP with no authentication in front of it
    ipAddress: {
      type: 'Public'
      ports: [
        {
          protocol: 'TCP'
          port: 80
        }
        {
          protocol: 'TCP'
          port: 22
        }
      ]
    }
    containers: [
      {
        name: 'app'
        properties: {
          // Mutable latest tag pulled from a public registry
          image: 'nginx:latest'
          ports: [
            {
              port: 80
            }
          ]
          resources: {
            requests: {
              cpu: 1
              memoryInGB: 1
            }
          }
          environmentVariables: [
            {
              name: 'DB_PASSWORD'
              value: 'Password123!'
            }
            {
              name: 'ACR_PASSWORD'
              value: 'Password123!'
            }
          ]
        }
      }
    ]
  }
}

output acrLoginServer string = acr.properties.loginServer
