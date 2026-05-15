variable "resource_group_name" {
  description = "Name of the Azure resource group that will contain the Azure Local VM resources."
  type        = string
}

variable "location" {
  description = "Azure region for the Azure Local Arc resources."
  type        = string
}

variable "subscription_id" {
  description = "Optional Azure subscription ID override used by the AzAPI provider and ARM ID assembly. When null, the current authenticated subscription is used."
  type        = string
  default     = null
}

variable "tenant_id" {
  description = "Optional Microsoft Entra tenant ID override used by the AzAPI provider."
  type        = string
  default     = null
}

variable "custom_location_id" {
  description = "Name of the Azure Arc custom location associated with the Azure Local instance. The full resource ID is assembled internally."
  type        = string
}

variable "storage_container_id" {
  description = "Name of the Azure Local storage container used for VM configuration and VHDs. The full resource ID is assembled internally."
  type        = string
}

variable "logical_network_id" {
  description = "Name of the Azure Local logical network or subnet to attach to each NIC. The full resource ID is assembled internally."
  type        = string
}

variable "image_id" {
  description = "Name of the Azure Local marketplace gallery image used to create the VM. The full resource ID is assembled internally."
  type        = string
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
  description = "Map of Azure Local compute nodes keyed by VM name. Each entry configures optional private IP, CPU, RAM, and up to three optional data disks."
  type = map(object({
    private_ip        = optional(string)
    processors        = number
    memory_mb         = number
    data_disk_size_gb = optional(number, 0)
    db_disk_size_gb   = optional(number, 0)
    log_disk_size_gb  = optional(number, 0)
    vm_size           = optional(string)
    tags              = optional(map(string), {})
  }))

  validation {
    condition     = length(var.compute_nodes) > 0
    error_message = "compute_nodes must contain at least one node."
  }

  validation {
    condition     = alltrue([for vm_name in keys(var.compute_nodes) : can(regex("^[a-zA-Z0-9][a-zA-Z0-9-_.]{0,53}$", vm_name))])
    error_message = "Each compute_nodes key (VM name) must start with an alphanumeric character, use only letters, numbers, dashes, underscores, or periods, and be 54 characters or less."
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
    condition     = alltrue([for node in values(var.compute_nodes) : try(node.data_disk_size_gb, 0) >= 0])
    error_message = "Each compute node data_disk_size_gb must be 0 or greater."
  }

  validation {
    condition     = alltrue([for node in values(var.compute_nodes) : try(node.db_disk_size_gb, 0) >= 0])
    error_message = "Each compute node db_disk_size_gb must be 0 or greater."
  }

  validation {
    condition     = alltrue([for node in values(var.compute_nodes) : try(node.log_disk_size_gb, 0) >= 0])
    error_message = "Each compute node log_disk_size_gb must be 0 or greater."
  }
}

variable "default_vm_size" {
  description = "Default Azure Local VM size for nodes that do not set vm_size. Use Custom when setting processors and memory explicitly."
  type        = string
  default     = "Custom"
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
