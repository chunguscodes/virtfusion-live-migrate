# virtfusion-live-migrate

## Overview

The script allows for two types of migration:

1. **Single VM Migration:** Migrate a specific VM identified by its server ID to a specified destination hypervisor.
   
2. **Bulk VM Migration:** Migrate all VMs from a source hypervisor to a specified destination hypervisor.

## Prerequisites

- **jq:** The script utilizes `jq` for JSON processing. Ensure it's installed and available in your `PATH`.
- **VirtFusion CLI:** The VirtFusion CLI tool `vfcli-ctrl` should be available. Please note Live Migration is only currently available on the VirtFusion TESTING branch.

## Usage

### 1. Single VM Migration

Migrate a specific VM to a designated destination hypervisor.

```sh
./live.sh single_vm [DESTINATION_HYPERVISOR_ID] [SERVER_ID]
```

### 2. Bulk VM Migration

Migrate all VMs from a source hypervisor to a designated destination hypervisor.

```sh
./live.sh all_vms [SOURCE_HYPERVISOR_ID] [DESTINATION_HYPERVISOR_ID]
```

## Parameters Explanation

- **[OPERATION]:** Specifies the operational mode. It can be either `single_vm` for single VM migration or `all_vms` for bulk migration.

- **[SOURCE_HYPERVISOR_ID]:** (Required for `all_vms` operation) The ID of the source hypervisor from which all VMs will be migrated.

- **[DESTINATION_HYPERVISOR_ID]:** The ID of the destination hypervisor to which VM(s) will be migrated.

- **[SERVER_ID]:** (Required for `single_vm` operation) The ID of the specific server (VM) that is intended to be migrated.

## Handling Migration Failures

In the event of a migration failure, the script will:
- Display an error message indicating which VM (by ID) encountered an issue and present the error message.
- Attempt to cancel the ongoing migration after a 3-second delay.
- Terminate further execution, preventing additional migrations from initiating.

## Contributing

Contributions to improve the script are welcomed. Kindly ensure to test your modifications in a non-production environment before submitting a Pull Request.

## Disclaimer

Please ensure to test the script thoroughly in a non-production environment to validate functionality and avoid unintended service disruptions. I am not responsible for any potential data loss or disruptions caused directly or indirectly by the usage of the script.
