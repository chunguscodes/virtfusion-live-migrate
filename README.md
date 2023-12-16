# virtfusion-live-migrate

### Prerequisites

- **Python 3:** The script utilizes `python3`. If script is run on VirtFusion master, this is already available and will work out of the box.
- **VirtFusion CLI:** The VirtFusion CLI tool `vfcli-ctrl` should be available.

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
- `python3 vf-migrate.py -c 5 -o -s 80 --drain-hv SRC_ID DST_ID` : Migrate all VMs from SRC_ID to DST_ID, 5 at a time, using offline migration with a speed limit of 80Mbps.
- `python3 vf-migrate.py DST_ID SERVER_ID` : Migrate a single VM (`SERVER_ID`) to `DST_ID` without any concurrency.
- `python3 vf-migrate.py -o DST_ID SERVER_ID(s)` : Migrate specific VMs to `DST_ID`, and if a VM is offline at the time of running, it'll migrate offline.
- `python3 vf-migrate.py -s 40 DST_ID SERVER_ID(s)` : Migrate specific VMs to `DST_ID` at a limited speed of 40 Mbps.
- `python3 vf-migrate.py -c 5 DST_ID SERVER_ID(s)` : Migrate specific VMs to `DST_ID` with concurrency, meaning 5 VMs will migrate simultaneously.

#### SERVER_ID(s) would be formatted like this: python3 vf-migrate.py DST_ID VMID1 VMID2 VMID3.

### Handling Migration Failures

In the event of a migration failure, the script will:
- Display an error message indicating which VM (by ID) encountered an issue and present the error message.
- If the migration can be cancelled, it will offer a Y or N option to either proceed or cancel the migration in question.
- If the migration cannot be cancelled, it will report the error and proceed with the next migration.

### Disclaimer

Please ensure to test the script in a non-production environment. I am not responsible for any potential data loss or disruptions caused directly or indirectly by the usage of the script.
