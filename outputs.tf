output "virtual_machine_instance_ids" {
  description = "Azure Local virtual machine instance resource IDs."
  value = {
    for name, resource in azapi_resource.virtual_machine_instance : name => resource.id
  }
}

output "machine_ids" {
  description = "Hybrid Compute machine resource IDs used as parents for the Azure Local VM instances."
  value = {
    for name, resource in azapi_resource.machine : name => resource.id
  }
}

output "network_interface_ids" {
  description = "Azure Local NIC resource IDs."
  value = {
    for name, resource in azapi_resource.network_interface : name => resource.id
  }
}

output "disk_ids" {
  description = "Azure Local C: and D: virtual hard disk resource IDs."
  value = {
    for name in keys(local.nodes) : name => {
      os_disk   = azapi_resource.os_disk[name].id
      data_disk = azapi_resource.data_disk[name].id
    }
  }
}
