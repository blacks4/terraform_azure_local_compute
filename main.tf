locals {
  nodes = var.compute_nodes

  node_tags = {
    for key, node in local.nodes : key => merge(var.tags, try(node.tags, {}))
  }

  disk_properties = {
    blockSizeBytes  = var.vhd_block_size_bytes
    containerId     = var.storage_container_id
    createFromLocal = false
    creationData = {
      createOption = "Empty"
    }
    diskFileFormat      = var.disk_file_format
    dynamic             = var.dynamic_disks
    hyperVGeneration    = var.hyper_v_generation
    logicalSectorBytes  = var.vhd_logical_sector_bytes
    maxShares           = 1
    physicalSectorBytes = var.vhd_physical_sector_bytes
  }

  extended_location = {
    name = var.custom_location_id
    type = "CustomLocation"
  }
}

ephemeral "vault_kv_secret_v2" "admin_password" {
  mount = var.vault_admin_password_kv_mount
  name  = var.vault_admin_password_secret_name
}

resource "azapi_resource" "resource_group" {
  type     = "Microsoft.Resources/resourceGroups@2024-03-01"
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azapi_resource" "network_interface" {
  for_each = local.nodes

  type      = "Microsoft.AzureStackHCI/networkInterfaces@2026-02-01-preview"
  name      = "${each.value.name}-nic01"
  parent_id = azapi_resource.resource_group.id
  location  = var.location
  tags      = local.node_tags[each.key]

  body = {
    extendedLocation = local.extended_location
    properties = {
      bypassSdnPolicies = var.bypass_sdn_policies
      createFromLocal   = false
      dnsSettings = {
        dnsServers = var.dns_servers
      }
      ipConfigurations = [
        {
          name = "ipconfig1"
          properties = merge(
            {
              subnet = {
                id = var.logical_network_id
              }
            },
            try(each.value.private_ip, null) == null ? {} : {
              privateIPAddress = each.value.private_ip
            }
          )
        }
      ]
    }
  }
}

resource "azapi_resource" "os_disk" {
  for_each = local.nodes

  type      = "Microsoft.AzureStackHCI/virtualHardDisks@2026-02-01-preview"
  name      = "${each.value.name}-osdisk"
  parent_id = azapi_resource.resource_group.id
  location  = var.location
  tags      = local.node_tags[each.key]

  body = {
    extendedLocation = local.extended_location
    properties = merge(local.disk_properties, {
      diskSizeGB = each.value.os_disk_size_gb
    })
  }
}

resource "azapi_resource" "data_disk" {
  for_each = local.nodes

  type      = "Microsoft.AzureStackHCI/virtualHardDisks@2026-02-01-preview"
  name      = "${each.value.name}-datadisk01"
  parent_id = azapi_resource.resource_group.id
  location  = var.location
  tags      = local.node_tags[each.key]

  body = {
    extendedLocation = local.extended_location
    properties = merge(local.disk_properties, {
      diskSizeGB = each.value.data_disk_size_gb
    })
  }
}

resource "azapi_resource" "machine" {
  for_each = local.nodes

  type      = "Microsoft.HybridCompute/machines@2025-09-16-preview"
  name      = each.value.name
  parent_id = azapi_resource.resource_group.id
  location  = var.location
  tags      = local.node_tags[each.key]

  identity {
    type = "SystemAssigned"
  }

  body = {
    kind = "HCI"
  }
}

resource "azapi_resource" "virtual_machine_instance" {
  for_each = local.nodes

  type      = "Microsoft.AzureStackHCI/virtualMachineInstances@2026-02-01-preview"
  name      = "default"
  parent_id = azapi_resource.machine[each.key].id

  identity {
    type = "SystemAssigned"
  }

  body = {
    extendedLocation = local.extended_location
    properties = {
      createFromLocal = false
      hardwareProfile = {
        memoryMB   = each.value.memory_mb
        processors = each.value.processors
        vmSize     = try(each.value.vm_size, var.default_vm_size)
      }
      networkProfile = {
        networkInterfaces = [
          {
            id = azapi_resource.network_interface[each.key].id
          }
        ]
      }
      osProfile = {
        adminUsername = var.admin_username
        computerName  = each.value.name
        windowsConfiguration = {
          enableAutomaticUpdates = var.enable_automatic_updates
          provisionVMAgent       = var.provision_vm_agent
          provisionVMConfigAgent = var.provision_vm_config_agent
          timeZone               = var.windows_time_zone
        }
      }
      securityProfile = {
        enableTPM    = var.enable_tpm
        securityType = var.security_type
        uefiSettings = {
          secureBootEnabled = var.secure_boot_enabled
        }
      }
      storageProfile = {
        imageReference = {
          id = try(each.value.image_id, var.image_id)
        }
        osDisk = {
          id     = azapi_resource.os_disk[each.key].id
          osType = var.os_type
        }
        dataDisks = [
          {
            id = azapi_resource.data_disk[each.key].id
          }
        ]
        vmConfigStoragePathId = var.storage_container_id
      }
    }
  }

  sensitive_body = {
    properties = {
      osProfile = {
        adminPassword = tostring(ephemeral.vault_kv_secret_v2.admin_password.data[var.vault_admin_password_key])
      }
    }
  }

  sensitive_body_version = {
    "properties.osProfile.adminPassword" = "1"
  }
}
