data "azapi_client_config" "current" {}

locals {
  nodes = var.compute_nodes

  effective_subscription_id = coalesce(var.subscription_id, data.azapi_client_config.current.subscription_id)
  resource_group_id         = "/subscriptions/${local.effective_subscription_id}/resourceGroups/${var.resource_group_name}"

  custom_location_resource_id   = "/subscriptions/${local.effective_subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.ExtendedLocation/customLocations/${var.custom_location_id}"
  storage_container_resource_id = "/subscriptions/${local.effective_subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.AzureStackHCI/storageContainers/${var.storage_container_id}"
  logical_network_resource_id   = "/subscriptions/${local.effective_subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.AzureStackHCI/logicalNetworks/${var.logical_network_id}"
  image_resource_id             = "/subscriptions/${local.effective_subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.AzureStackHCI/marketplaceGalleryImages/${var.image_id}"
  cluster_name_suffix_raw       = join("-", regexall("[a-z0-9-]+", lower(var.custom_location_id)))
  cluster_name_suffix           = local.cluster_name_suffix_raw

  node_tags = {
    for vm_name, node in local.nodes : vm_name => merge(var.tags, try(node.tags, {}))
  }

  extended_location = {
    name = local.custom_location_resource_id
    type = "CustomLocation"
  }

  windows_configuration = {
    enableAutomaticUpdates = var.enable_automatic_updates
    provisionVMAgent       = var.provision_vm_agent
    provisionVMConfigAgent = var.provision_vm_config_agent
    timeZone               = var.windows_time_zone
  }
}

ephemeral "vault_kv_secret_v2" "admin_password" {
  mount = var.vault_admin_password_kv_mount
  name  = var.vault_admin_password_secret_name
}

resource "azapi_resource" "machine" {
  for_each = local.nodes

  type      = "Microsoft.HybridCompute/machines@2024-07-10"
  name      = "${each.key}-${local.cluster_name_suffix}"
  parent_id = local.resource_group_id
  location  = var.location
  tags      = local.node_tags[each.key]

  identity {
    type = "SystemAssigned"
  }

  body = {
    kind = "HCI"
  }
}

resource "azapi_resource" "network_interface" {
  for_each = local.nodes

  type                      = "Microsoft.AzureStackHCI/networkInterfaces@2024-01-01"
  name                      = "${each.key}-${local.cluster_name_suffix}-nic"
  parent_id                 = local.resource_group_id
  location                  = var.location
  schema_validation_enabled = false
  tags                      = local.node_tags[each.key]

  body = {
    extendedLocation = local.extended_location
    properties = {
      ipConfigurations = [
        {
          name = "ipconfig1"
          properties = merge(
            {
              subnet = {
                id = local.logical_network_resource_id
              }
            },
            try(trimspace(each.value.private_ip), "") == "" ? {} : {
              privateIPAddress = trimspace(each.value.private_ip)
            }
          )
        }
      ]
    }
  }
}

resource "azapi_resource" "data_disk" {
  for_each = {
    for vm_name, node in local.nodes : vm_name => node
    if try(node.data_disk_size_gb, 0) > 0
  }

  type                      = "Microsoft.AzureStackHCI/virtualHardDisks@2024-01-01"
  name                      = "${each.key}-${local.cluster_name_suffix}-datadisk"
  parent_id                 = local.resource_group_id
  location                  = var.location
  schema_validation_enabled = false
  tags                      = local.node_tags[each.key]

  body = {
    extendedLocation = local.extended_location
    properties = {
      containerId      = local.storage_container_resource_id
      diskSizeGB       = each.value.data_disk_size_gb
      dynamic          = var.dynamic_disks
      hyperVGeneration = var.hyper_v_generation
    }
  }
}

resource "azapi_resource" "db_disk" {
  for_each = {
    for vm_name, node in local.nodes : vm_name => node
    if try(node.db_disk_size_gb, 0) > 0
  }

  type                      = "Microsoft.AzureStackHCI/virtualHardDisks@2024-01-01"
  name                      = "${each.key}-${local.cluster_name_suffix}-dbdisk"
  parent_id                 = local.resource_group_id
  location                  = var.location
  schema_validation_enabled = false
  tags                      = local.node_tags[each.key]

  body = {
    extendedLocation = local.extended_location
    properties = {
      containerId      = local.storage_container_resource_id
      diskSizeGB       = each.value.db_disk_size_gb
      dynamic          = var.dynamic_disks
      hyperVGeneration = var.hyper_v_generation
    }
  }
}

resource "azapi_resource" "log_disk" {
  for_each = {
    for vm_name, node in local.nodes : vm_name => node
    if try(node.log_disk_size_gb, 0) > 0
  }

  type                      = "Microsoft.AzureStackHCI/virtualHardDisks@2024-01-01"
  name                      = "${each.key}-${local.cluster_name_suffix}-logdisk"
  parent_id                 = local.resource_group_id
  location                  = var.location
  schema_validation_enabled = false
  tags                      = local.node_tags[each.key]

  body = {
    extendedLocation = local.extended_location
    properties = {
      containerId      = local.storage_container_resource_id
      diskSizeGB       = each.value.log_disk_size_gb
      dynamic          = var.dynamic_disks
      hyperVGeneration = var.hyper_v_generation
    }
  }
}

resource "azapi_resource" "virtual_machine_instance" {
  for_each = local.nodes

  type                      = "Microsoft.AzureStackHCI/virtualMachineInstances@2024-01-01"
  name                      = "default"
  parent_id                 = azapi_resource.machine[each.key].id
  schema_validation_enabled = false

  identity {
    type = "SystemAssigned"
  }

  body = {
    extendedLocation = local.extended_location
    properties = {
      hardwareProfile = {
        vmSize     = try(each.value.vm_size, var.default_vm_size)
        processors = each.value.processors
        memoryMB   = each.value.memory_mb
      }
      osProfile = {
        adminUsername        = var.admin_username
        computerName         = each.key
        windowsConfiguration = local.windows_configuration
      }
      storageProfile = merge(
        {
          imageReference = {
            id = local.image_resource_id
          }
          osDisk = {
            osType = var.os_type
          }
          vmConfigStoragePathId = local.storage_container_resource_id
        },
        length(concat(
          try([{ id = azapi_resource.data_disk[each.key].id }], []),
          try([{ id = azapi_resource.db_disk[each.key].id }], []),
          try([{ id = azapi_resource.log_disk[each.key].id }], [])
          )) > 0 ? {
          dataDisks = concat(
            try([{ id = azapi_resource.data_disk[each.key].id }], []),
            try([{ id = azapi_resource.db_disk[each.key].id }], []),
            try([{ id = azapi_resource.log_disk[each.key].id }], [])
          )
        } : {}
      )
      networkProfile = {
        networkInterfaces = [
          {
            id = azapi_resource.network_interface[each.key].id
          }
        ]
      }
      securityProfile = {
        enableTPM    = var.enable_tpm
        securityType = var.security_type
        uefiSettings = {
          secureBootEnabled = var.secure_boot_enabled
        }
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
