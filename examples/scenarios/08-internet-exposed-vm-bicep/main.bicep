// ###########################################################################
// SCENARIO: Internet-exposed VM on Azure, expressed in Bicep
//
// Public IP bound straight to the NIC, an NSG allowing RDP/SSH/WinRM from the
// Internet service tag, password authentication with a literal password, no
// disk encryption set, boot diagnostics off, and the VM's managed identity
// granted Owner on the subscription.
//
// Attack path this models:
//   internet -> NSG allows :3389 from Internet -> password spray
//            -> VM identity holds Owner -> subscription takeover
//
// DO NOT DEPLOY.
// ###########################################################################

targetScope = 'resourceGroup'

param location string = resourceGroup().location

@description('Literal default password instead of a @secure() param')
param adminPassword string = 'Password123!'

var vmName = 'scenario-exposed-vm'

resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: 'scenario-exposed-vnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'scenario-exposed-subnet'
        properties: {
          addressPrefix: '10.0.1.0/24'
        }
      }
    ]
  }
}

// Static public IP directly on the VM. No bastion, no load balancer.
resource publicIp 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: 'scenario-exposed-pip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// NSG exposing every remote-management port to the internet
resource nsg 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: 'scenario-exposed-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowRDPFromInternet'
        properties: {
          priority: 100
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
        name: 'AllowSSHFromInternet'
        properties: {
          priority: 110
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
        name: 'AllowWinRMFromInternet'
        properties: {
          priority: 120
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '5985'
            '5986'
          ]
          sourceAddressPrefix: '0.0.0.0/0'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowEverythingElseInbound'
        properties: {
          priority: 130
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: 'scenario-exposed-nic'
  location: location
  properties: {
    // IP forwarding lets the host route deeper into the VNet
    enableIPForwarding: true
    networkSecurityGroup: {
      id: nsg.id
    }
    ipConfigurations: [
      {
        name: 'internal'
        properties: {
          subnet: {
            id: vnet.properties.subnets[0].id
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
  }
}

// The exposed VM: password auth on, unencrypted disk, no boot diagnostics
resource vm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vmName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v3'
    }
    osProfile: {
      computerName: vmName
      adminUsername: 'azureuser'
      adminPassword: adminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
      customData: base64('#!/bin/bash\nsed -i "s/^#\\?PermitRootLogin.*/PermitRootLogin yes/" /etc/ssh/sshd_config\ncurl -sSL http://example.com/agent.sh | bash\n')
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
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: false
      }
    }
  }
}

// The VM's identity granted Owner at subscription scope
resource ownerAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(vm.id, 'Owner')
  properties: {
    // Owner role definition ID
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '8e3af657-a8ff-443c-a75c-2fe8c4bcb635')
    principalId: vm.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output publicIpAddress string = publicIp.properties.ipAddress
