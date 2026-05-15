output "virtual_machine_instance_ids" {
  description = "Azure Local virtual machine instance resource IDs."
  value = {
    for vm_name, resource in azapi_resource.virtual_machine_instance : vm_name => resource.id
  }
}

output "machine_ids" {
  description = "Hybrid Compute machine resource IDs used as parents for the Azure Local VM instances."
  value = {
    for vm_name, resource in azapi_resource.machine : vm_name => resource.id
  }
}

output "network_interface_ids" {
  description = "Azure Local NIC resource IDs."
  value = {
    for vm_name, resource in azapi_resource.network_interface : vm_name => resource.id
  }
}

output "disk_ids" {
  description = "Azure Local optional data disk resource IDs."
  value = {
    for vm_name in keys(var.compute_nodes) : vm_name => {
      data_disk = try(azapi_resource.data_disk[vm_name].id, null)
      db_disk   = try(azapi_resource.db_disk[vm_name].id, null)
      log_disk  = try(azapi_resource.log_disk[vm_name].id, null)
    }
  }
}
