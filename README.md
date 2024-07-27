# virtfusion-live-migrate

### Prerequisites

- **jq:** The script utilizes `jq` for JSON processing.
- **VirtFusion CLI:** The VirtFusion CLI tool `vfcli-ctrl` should be available. Please note this script should only be run on a VirtFusion master server.

### Required Parameters

If migrating a single VM, or multiple specific VMs with or without concurrency: 

- `DST_ID SERVER_ID(s)`: This will set the destination hypervisor ID, and the IDs of the server(s) you are migrating.

If draining a hypervisor, with or without concurrency.

- `SRC_ID DST_ID`: This will set the source hypervisor ID you are migrating from, to the destination hypervisor you are migrating to.

### Options
- `-c <number>`: Sets migration concurrency. This will determine how many VMs will be migrated at a time.
- `-o`: Allows migration of offline VMs.
- `-s <speed in Mbps>`: Set transfer speed limit in Mbps. This is per VM, meaning if you use concurrency of 2, you would use 80Mbps.
- `--drain-hv`: Migrate all VMs from `SRC_ID`.

### Examples
- `./migrate.sh SRC_ID DST_ID --drain-hv -c 5 -o -s 80`: Migrate all VMs from `SRC_ID` to `DST_ID`, 5 at a time, using offline migration with a speed limit of 80Mbps.
- `./migrate.sh DST_ID SERVER_ID`: Migrate a single VM (`SERVER_ID`) to `DST_ID` without any concurrency.
- `./migrate.sh DST_ID SERVER_ID(s) -o`: Migrate specific VMs to `DST_ID`, and if a VM is offline at the time of running, it'll migrate offline.
- `./migrate.sh DST_ID SERVER_ID(s) -s 40`: Migrate specific VMs to `DST_ID` at a limited speed of 40 Mbps per VM migrated.
- `./migrate.sh DST_ID SERVER_ID(s) -c 5`: Migrate specific VMs to `DST_ID` with concurrency, meaning 5 VMs will migrate simultaneously.

#### SERVER_ID(s) would be formatted like this: ./migrate.sh DST_ID VMID1 VMID2 VMID3.

### Handling Migration Failures

In the event of a migration failure, the script will:
- Display an error message indicating which VM (by ID) encountered an issue and present the error message.
- Attempt to cancel the ongoing migration after a 3-second delay.
- Terminate further execution, preventing additional migrations from initiating.

### SIGINT Trap

If you wish to cancel any further migrations past what is currently running, you can use CTRL+C which will stop the script from running any new migrations when the existing one has concluded.

### Disclaimer

Please ensure to test the script in a non-production environment. I am not responsible for any potential data loss or disruptions caused directly or indirectly by the usage of the script.
