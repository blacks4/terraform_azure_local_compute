variable "resource_group_name" {
  description = "Name of the Azure resource group that will contain the Azure Local VM resources."
  type        = string
}

variable "location" {
  description = "Azure region for the Azure Local Arc resources."
  type        = string
}

variable "subscription_id" {
  description = "Azure subscription ID used by the AzAPI provider."
  type        = string
}

variable "tenant_id" {
  description = "Microsoft Entra tenant ID used by the AzAPI provider."
  type        = string
}

variable "custom_location_id" {
  description = "Resource ID of the Azure Arc custom location associated with the Azure Local instance."
  type        = string
}

variable "storage_container_id" {
  description = "Resource ID of the Azure Local storage container used for VM configuration and VHDs."
  type        = string
}

variable "logical_network_id" {
  description = "Resource ID of the Azure Local logical network or subnet to attach to each NIC."
  type        = string
}

variable "image_id" {
  description = "Resource ID of the Azure Local gallery or marketplace image used to create the VM."
  type        = string
}

variable "dns_servers" {
  description = "DNS servers to assign to each VM NIC."
  type        = list(string)
  default     = []
}

variable "bypass_sdn_policies" {
  description = "Whether to bypass SDN policies on each NIC. Only set true when SDN is supported and you intentionally want to disable SDN policy enforcement for the NIC."
  type        = bool
  default     = false
}

variable "admin_username" {
  description = "Local administrator username for the Windows VMs."
  type        = string
  sensitive   = true
}

variable "vault_address" {
  description = "Vault server address. Can also be set with the VAULT_ADDR environment variable in Terraform Cloud."
  type        = string
  default     = null
}

variable "vault_namespace" {
  description = "Optional Vault Enterprise/HCP Vault namespace. Can also be set with VAULT_NAMESPACE."
  type        = string
  default     = null
}

variable "vault_admin_password_kv_mount" {
  description = "Vault KV v2 mount path that contains the Windows admin password secret."
  type        = string
}

variable "vault_admin_password_secret_name" {
  description = "Vault KV v2 secret name/path that contains the Windows admin password secret."
  type        = string
}

variable "vault_admin_password_key" {
  description = "Key within the Vault KV v2 secret data that contains the Windows admin password."
  type        = string
  default     = "admin_password"
}

variable "os_type" {
  description = "Operating system type for the OS disk."
  type        = string
  default     = "Windows"

  validation {
    condition     = contains(["Windows", "Linux"], var.os_type)
    error_message = "os_type must be Windows or Linux."
  }
}

variable "compute_nodes" {
  description = "Map of Azure Local compute nodes keyed by a stable Terraform identifier. Each entry configures the node name, IP, CPU, RAM, and C:/D: disk sizes."
  type = map(object({
    name              = string
    private_ip        = optional(string)
    image_id          = optional(string)
    processors        = number
    memory_mb         = number
    os_disk_size_gb   = number
    data_disk_size_gb = number
    vm_size           = optional(string)
    tags              = optional(map(string), {})
  }))

  validation {
    condition     = length(var.compute_nodes) > 0
    error_message = "compute_nodes must contain at least one node."
  }

  validation {
    condition     = length(distinct([for node in values(var.compute_nodes) : node.name])) == length(var.compute_nodes)
    error_message = "Each compute_nodes entry must have a unique name."
  }

  validation {
    condition     = alltrue([for node in values(var.compute_nodes) : can(regex("^[a-zA-Z0-9][a-zA-Z0-9-_.]{0,53}$", node.name))])
    error_message = "Each compute node name must start with an alphanumeric character, use only letters, numbers, dashes, underscores, or periods, and be 54 characters or less."
  }

  validation {
    condition     = alltrue([for node in values(var.compute_nodes) : node.processors >= 1])
    error_message = "Each compute node must set processors to at least 1."
  }

  validation {
    condition     = alltrue([for node in values(var.compute_nodes) : node.memory_mb >= 1024])
    error_message = "Each compute node must set memory_mb to at least 1024."
  }

  validation {
    condition     = alltrue([for node in values(var.compute_nodes) : node.os_disk_size_gb >= 32])
    error_message = "Each compute node must set os_disk_size_gb to at least 32."
  }

  validation {
    condition     = alltrue([for node in values(var.compute_nodes) : node.data_disk_size_gb >= 1])
    error_message = "Each compute node must set data_disk_size_gb to at least 1."
  }
}

variable "default_vm_size" {
  description = "Default Azure Local VM size for nodes that do not set vm_size. Use Custom when setting processors and memory explicitly."
  type        = string
  default     = "Custom"
}

variable "disk_file_format" {
  description = "Virtual hard disk file format."
  type        = string
  default     = "vhdx"

  validation {
    condition     = contains(["vhd", "vhdx"], var.disk_file_format)
    error_message = "disk_file_format must be vhd or vhdx."
  }
}

variable "dynamic_disks" {
  description = "Whether to create dynamically expanding virtual hard disks."
  type        = bool
  default     = true
}

variable "hyper_v_generation" {
  description = "Hyper-V generation for the virtual hard disks."
  type        = string
  default     = "V2"

  validation {
    condition     = contains(["V1", "V2", "NA"], var.hyper_v_generation)
    error_message = "hyper_v_generation must be V1, V2, or NA."
  }
}

variable "vhd_block_size_bytes" {
  description = "Virtual hard disk block size in bytes."
  type        = number
  default     = 33554432
}

variable "vhd_logical_sector_bytes" {
  description = "Virtual hard disk logical sector size in bytes."
  type        = number
  default     = 512
}

variable "vhd_physical_sector_bytes" {
  description = "Virtual hard disk physical sector size in bytes."
  type        = number
  default     = 4096
}

variable "enable_automatic_updates" {
  description = "Whether to enable Windows automatic updates."
  type        = bool
  default     = true
}

variable "provision_vm_agent" {
  description = "Whether to trigger Arc for Servers agent onboarding during VM creation."
  type        = bool
  default     = true
}

variable "provision_vm_config_agent" {
  description = "Whether to install the VM Config Agent during VM creation."
  type        = bool
  default     = true
}

variable "windows_time_zone" {
  description = "Windows time zone ID for the VMs."
  type        = string
  default     = "Eastern Standard Time"
}

variable "enable_tpm" {
  description = "Whether to enable TPM for each VM."
  type        = bool
  default     = true
}

variable "secure_boot_enabled" {
  description = "Whether to enable UEFI secure boot for each VM."
  type        = bool
  default     = true
}

variable "security_type" {
  description = "Security type for each VM. Use TrustedLaunch for Windows Server V2 images when supported by your Azure Local environment."
  type        = string
  default     = "TrustedLaunch"

  validation {
    condition     = contains(["TrustedLaunch", "ConfidentialVM"], var.security_type)
    error_message = "security_type must be TrustedLaunch or ConfidentialVM."
  }
}

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default     = {}
}
