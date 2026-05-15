# Azure Local Compute Instances

This Terraform configuration creates Azure Local virtual machine instances using the AzAPI provider.

Azure Local VM instances are not normal Azure IaaS VMs, so this code uses `azapi_resource` for:

- `Microsoft.AzureStackHCI/networkInterfaces`
- `Microsoft.AzureStackHCI/virtualHardDisks`
- `Microsoft.AzureStackHCI/virtualMachineInstances`
- `Microsoft.HybridCompute/machines`

The top-level provider configuration lives in `terraform.tf`. The Azure Local resources live in `main.tf`, input variables in `variables.tf`, outputs in `outputs.tf`, and example values in `terraform.tfvars`.

## Terraform Cloud Authentication

This configuration is intended to run in HCP Terraform/Terraform Cloud without Azure CLI authentication.

The preferred approach is Terraform Cloud dynamic provider credentials for Azure, backed by an Azure application registration with federated identity credentials. The module can auto-detect the current authenticated subscription via `data.azapi_client_config.current`, and `subscription_id` can be set only when you want to override it explicitly.

Configure the Terraform Cloud workspace or a global variable set with these Terraform variables:

```text
subscription_id = "<subscription-id>"
tenant_id       = "<tenant-id>"
```

Also configure the Terraform Cloud dynamic provider credentials environment variables required by your workspace. At minimum, the default configuration uses:

```text
TFC_AZURE_PROVIDER_AUTH = true
TFC_AZURE_RUN_CLIENT_ID = "<application-client-id>"
```

For the default single Azure dynamic credentials setup, do not set provider `client_id`, `use_oidc`, or OIDC token values in this configuration.

As a fallback, you can use a static service principal secret in Terraform Cloud environment variables instead of OIDC:

```text
ARM_SUBSCRIPTION_ID = "<subscription-id>"
ARM_TENANT_ID       = "<tenant-id>"
ARM_CLIENT_ID       = "<application-client-id>"
ARM_CLIENT_SECRET   = "<client-secret>"
```

When using the static service principal fallback, do not set `TFC_AZURE_PROVIDER_AUTH`.

The identity running Terraform needs permission to create and manage the target resource group and the Azure Local ARM resources. If provider registration is enabled, it also needs permission to register required resource providers such as `Microsoft.AzureStackHCI`, `Microsoft.HybridCompute`, and `Microsoft.ExtendedLocation`.

In `terraform.tfvars.example`, `subscription_id` and `tenant_id` are shown as commented lines because many Terraform Cloud setups source those from workspace/global variables or environment variables. If you are running locally, set them in your `.tfvars` file or provide them another supported way. If `subscription_id` is not set, the current authenticated subscription is used automatically.

The example now accepts short names for `custom_location_id`, `storage_container_id`, `logical_network_id`, and `image_id` (for example `lnet-prod` or `windows-server-2022`). The module assembles the full ARM resource IDs internally using `subscription_id`, `resource_group_name`, and the provider path for each resource type.

## Admin Password

Do not store the Windows local admin password in `terraform.tfvars` or Terraform Cloud variables.

This configuration reads the password from a HashiCorp Vault KV v2 secret using the Vault provider's ephemeral `vault_kv_secret_v2` resource. The password value is only referenced inside AzAPI `sensitive_body`, which is a write-only argument. This is intentional so the password is not persisted in Terraform plan or state.

Configure these Terraform variables in the Terraform Cloud workspace or a variable set:

```text
vault_admin_password_kv_mount    = "secret"
vault_admin_password_secret_name = "azure-local/windows-admin"
vault_admin_password_key         = "admin_password"
```

The Vault secret should exist in KV v2 and contain a key matching `vault_admin_password_key`, for example:

```json
{
  "admin_password": "<strong-password>"
}
```

Configure Vault provider authentication in Terraform Cloud environment variables, for example:

```text
VAULT_ADDR      = "https://vault.example.com"
VAULT_NAMESPACE = "<namespace-if-used>"
VAULT_TOKEN     = "<vault-token>"
```

Mark `VAULT_TOKEN` as sensitive. If using HCP Vault or Vault Enterprise without namespaces, omit `VAULT_NAMESPACE`.

The password is sent only when Terraform creates a new Azure Local VM instance resource. The write-only password version is hardcoded to `1`, so changing the password value in Vault does not cause Terraform to resend or update the password for already-created nodes.

If you change the password in Vault and then add a new cluster or new node resources, those new resources use the current Vault password during creation. Existing nodes are left alone. Operating system password lifecycle after initial build is expected to be managed outside Terraform, for example with Ansible.

## Configure Nodes

Global/shared values are kept at the top of `terraform.tfvars`. Per-node compute settings live under `compute_nodes`.

Top-level resource selectors are names, not full ARM IDs. Example:

```hcl
custom_location_id   = "azure-local-cl"
storage_container_id = "default"
logical_network_id   = "lnet-prod"
image_id             = "windows-server-2022"
```

The example file also includes optional variables that already have defaults, but they are shown as commented one-liners so users can quickly enable overrides only when needed. For example:

```hcl
# security_type = "TrustedLaunch" # default for security_type is "TrustedLaunch"
```

Each node key is the VM name. Each entry can set private IP, CPU count, memory, up to three optional data disks, and tags:

```hcl
compute_nodes = {
  "win-app-01" = {
    private_ip        = "10.0.20.11"
    processors        = 4
    memory_mb         = 8192
    data_disk_size_gb = 256
    db_disk_size_gb   = 0
    log_disk_size_gb  = 0
    tags = {
      role               = "app"
      notes              = "Primary application node"
      service_now_ticket = "CHG0000001"
    }
  }
}
```

Global tags are merged with each node's `tags`. If the same tag key appears in both places, the node-specific value wins.

## Deploy

For Terraform Cloud runs, configure the workspace variables and queue a plan from Terraform Cloud.

Initialize Terraform:

```bash
terraform init
```

Validate the configuration:

```bash
terraform validate
```

Plan and apply:

```bash
terraform plan
terraform apply
```

## Notes

The Azure Local VM instance extension resource does not expose `tags` in the AzAPI schema currently used here. Per-node tags are applied to the Hybrid Compute machine parent, NIC, and optional data/db/log disk resources.
