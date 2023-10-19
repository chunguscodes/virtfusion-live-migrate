# virtfusion-live-migrate

## Prerequisites

- **jq:** The script utilizes `jq` for JSON processing.
- **VirtFusion CLI:** The VirtFusion CLI tool `vfcli-ctrl` should be available. Please note Live Migration is only currently available on the VirtFusion TESTING branch.

### Required Parameters

If migrating a single VM, or multiple specific VMs with or without concurrency: 

- `DST_ID SERVER_ID(s)`: This will set the destination hypervisor ID, and the IDs of the server(s) you are migrating.

If draining a hypervisor, with or without concurrency.

- `SRC_ID DST_ID`: This will set the source hypervisor ID you are migrating from, to the destination hypervisor you are migrating to.

### Options
- `-c <number>`: Set concurrency. Determines how many VMs simultaneously migrate.
- `-o`: Allows migration of offline VMs.
- `-s <speed in Mbps>`: Set transfer speed limit in Mbps.
- `--drain-hv`: Migrate all VMs from `SRC_ID`.

### Examples
- `./migrate.sh SRC_ID DST_ID --drain-hv -c 5 -o -s 80`: Migrate all VMs from `SRC_ID` to `DST_ID`, 5 at a time, using offline migration with a speed limit of 80Mbps.
- `./migrate.sh DST_ID SERVER_ID`: Migrate a single VM (`SERVER_ID`) to `DST_ID` without any concurrency.
- `./migrate.sh DST_ID SERVER_ID(s) -o`: Migrate specific VMs to `DST_ID`, and if a VM is offline at the time of running, it'll migrate offline.
- `./migrate.sh DST_ID SERVER_ID(s) -s 40`: Migrate specific VMs to `DST_ID` at a limited speed of 40 Mbps.
- `./migrate.sh DST_ID SERVER_ID(s) -c 5`: Migrate specific VMs to `DST_ID` with concurrency, meaning 5 VMs will migrate simultaneously.

## Handling Migration Failures

In the event of a migration failure, the script will:
- Display an error message indicating which VM (by ID) encountered an issue and present the error message.
- Attempt to cancel the ongoing migration after a 3-second delay.
- Terminate further execution, preventing additional migrations from initiating.

## Disclaimer

Please ensure to test the script thoroughly in a non-production environment to validate functionality and avoid unintended service disruptions. I am not responsible for any potential data loss or disruptions caused directly or indirectly by the usage of the script.
