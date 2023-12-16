import subprocess
import json
import sys
import time
import argparse

def run_command(command):
    result = subprocess.run(command, shell=True, text=True, capture_output=True)
    return result.stdout.strip()

def command_exists(command):
    return subprocess.call(f"type {command}", shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE) == 0

def prompt_user():
    while True:
        user_input = input("Migration failed. Press Y to retry or N to cancel the migration: ").strip().upper()
        if user_input in ['Y', 'N']:
            return user_input
        else:
            print("Invalid input. Please press Y or N.")

def migrate_server(server_id, dst_hv_id, offline, speed):
    migration_command = f"vfcli-ctrl server:migrate-live start --server={server_id} --dst={dst_hv_id} {offline} {speed} --json"
    migration_response = run_command(migration_command)
    migration_data = json.loads(migration_response)

    if migration_data.get("success") == True:
        print(f"Migration of server {server_id} was successful!")
    else:
        print(f"Migration failed for server {server_id}.")
        print("Error:", migration_data.get("errors"))

        if migration_data.get("cancellable", True):
            user_choice = prompt_user()
            if user_choice == 'Y':
                print(f"Retrying migration for server {server_id}...")
                migrate_server(server_id, dst_hv_id, offline, speed)

parser = argparse.ArgumentParser(
    epilog='''examples:
      vf-migrate.py -c 5 -o -s 80 --drain-hv SRC_ID DST_ID : Migrate all VMs from SRC_ID to DST_ID, 5 at a time, using offline migration with a speed limit of 80Mbps.
      vf-migrate.py DST_ID SERVER_ID : Migrate a single VM (SERVER_ID) to DST_ID without any concurrency.
      vf-migrate.py -o DST_ID SERVER_ID(s) : Migrate specific VMs to DST_ID, and if a VM is offline at the time of running, it'll migrate offline.
      vf-migrate.py -s 40 DST_ID SERVER_ID(s) : Migrate specific VMs to DST_ID at a limited speed of 40 Mbps.
      vf-migrate.py -c 5 DST_ID SERVER_ID(s) : Migrate specific VMs to DST_ID with concurrency, meaning 5 VMs will migrate simultaneously.''',
    formatter_class=argparse.RawDescriptionHelpFormatter
)

parser.add_argument('-c', '--concurrency', type=int, default=1, help='Set concurrency. Determines how many VMs simultaneously migrate (default is 1).')
parser.add_argument('-o', '--offline', action='store_true', help='Allows migration of offline VMs.')
parser.add_argument('-s', '--speed', type=int, help='Set transfer speed limit in Mbps.')
parser.add_argument('--drain-hv', nargs=2, metavar=('SRC_HV_ID', 'DST_HV_ID'), help='Enable drain mode to migrate all servers from source HV to destination HV')
parser.add_argument('DST_HV_ID', help='Destination hypervisor ID')
parser.add_argument('SRC_HV_ID', nargs='?', help='Source hypervisor ID (optional, required in drain mode)')
parser.add_argument('SERVER_IDS', nargs='*', help='List of server IDs to migrate (optional)')

args = parser.parse_args()

if not command_exists("vfcli-ctrl"):
    print("Error: vfcli-ctrl must be installed.")
    sys.exit(1)

concurrency = args.concurrency
offline = "--force-offline" if args.offline else ""
speed = f"--xfer-speed={args.speed // 8}" if args.speed else ""
drain_hv = args.drain_hv is not None

if drain_hv:
    src_hv_id, dst_hv_id = args.drain_hv
    server_list_json = run_command(f"vfcli-ctrl server:migrate-live servers --src={src_hv_id} --json")

    if not server_list_json:
        print("Failed to retrieve the server list.")
        sys.exit(1)

    server_list_data = json.loads(server_list_json)
    server_ids = [server["id"] for server in server_list_data["servers"]]
    total_servers = len(server_ids)
    migrated_count = 0

    for server_id in server_ids:
        migrated_count += 1
        print(f"Migrating server with ID: {server_id} ({migrated_count}/{total_servers})")
        migrate_server(server_id, dst_hv_id, offline, speed)

        if migrated_count % concurrency == 0:
            time.sleep(1)

else:
    dst_hv_id = args.DST_HV_ID
    if not dst_hv_id or not args.SERVER_IDS:
        parser.print_help()
        sys.exit(1)

    server_ids = args.SERVER_IDS
    total_servers = len(server_ids)
    migrated_count = 0

    for server_id in server_ids:
        migrated_count += 1
        print(f"Migrating server with ID: {server_id} ({migrated_count}/{total_servers})")
        migrate_server(server_id, dst_hv_id, offline, speed)

        if migrated_count % concurrency == 0 or migrated_count == total_servers:
            time.sleep(1)
