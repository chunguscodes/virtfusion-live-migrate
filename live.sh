#!/bin/bash

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 OPERATION [SOURCE_HYPERVISOR_ID] DESTINATION_HYPERVISOR_ID [SERVER_ID]"
    echo "OPERATION: single_vm | all_vms"
    echo "Optional SERVER_ID for single_vm operation."
    exit 1
fi

OPERATION=$1

function migrate_server {
    SERVER_ID=$1
    DST_HV_ID=$2
    MIGRATION_RESPONSE=$(vfcli-ctrl server:migrate-live start --server=$SERVER_ID --dst=$DST_HV_ID --json)
    SUCCESS=$(echo "$MIGRATION_RESPONSE" | jq -r '.success')
    ERRORS=$(echo "$MIGRATION_RESPONSE" | jq -r '.errors[]?')

    if [[ "$SUCCESS" == "true" ]]; then
        echo "Migration of server $SERVER_ID was successful!"
    else
        echo "Migration failed for server $SERVER_ID."
        echo "Error: $ERRORS"
        echo "Attempting to cancel the migration in 3 seconds..."
        sleep 3
        vfcli-ctrl server:migrate-live cancel --server=$SERVER_ID
        exit 1
    fi
}

if [[ $OPERATION == "single_vm" ]]; then
    if [[ $# -lt 3 ]]; then
        echo "For single_vm operation, DESTINATION_HYPERVISOR_ID and SERVER_ID are required."
        exit 1
    fi
    DST_HV_ID=$2
    SERVER_ID=$3
    echo "Migrating single server with ID: $SERVER_ID"
    migrate_server $SERVER_ID $DST_HV_ID
elif [[ $OPERATION == "all_vms" ]]; then
    if [[ $# -lt 3 ]]; then
        echo "For all_vms operation, SOURCE_HYPERVISOR_ID and DESTINATION_HYPERVISOR_ID are required."
        exit 1
    fi
    SRC_HV_ID=$2
    DST_HV_ID=$3
    SERVER_LIST_JSON=$(vfcli-ctrl server:migrate-live servers --src=$SRC_HV_ID --json)
    if [[ -z "$SERVER_LIST_JSON" ]]; then
        echo "Failed to retrieve the server list."
                exit 1
    fi
    SERVER_IDS=$(echo "$SERVER_LIST_JSON" | jq -r '.servers[].id')
    TOTAL_SERVERS=$(echo "$SERVER_IDS" | wc -w)
    MIGRATED_COUNT=0
    for SERVER_ID in $SERVER_IDS; do
        MIGRATED_COUNT=$((MIGRATED_COUNT + 1))
        echo "Migrating server with ID: $SERVER_ID ($MIGRATED_COUNT/$TOTAL_SERVERS)"
        migrate_server $SERVER_ID $DST_HV_ID
        echo "Migrated servers: $MIGRATED_COUNT / $TOTAL_SERVERS"
    done
else
    echo "Invalid OPERATION. Please use single_vm or all_vms."
    exit 1
fi

