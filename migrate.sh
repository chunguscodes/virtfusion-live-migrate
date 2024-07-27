#!/bin/bash

if ! command -v jq &>/dev/null; then
    echo "Error: jq is not installed. Please install it before running this script."
    exit 1
fi

if ! command -v vfcli-ctrl &>/dev/null; then
    echo "Error: vfcli-ctrl is not installed. Please install it before running this script."
    exit 1
fi

CONCURRENCY=1
OFFLINE=""
SPEED=""
DRAIN_HV=false
POSITIONAL=()

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -c) CONCURRENCY="$2"; shift; shift ;;
        -o) OFFLINE="--force-offline"; shift ;;
        -s) SPEED_VALUE_MiBs=$(( $2 / 8 )); SPEED="--xfer-speed=$SPEED_VALUE_MiBs"; shift; shift ;;
        --drain-hv) DRAIN_HV=true; shift ;;
        *) POSITIONAL+=("$1"); shift ;;
    esac
done

set -- "${POSITIONAL[@]}"

if [[ ${#POSITIONAL[@]} -lt 2 ]]; then
    cat <<EOL
    $(tput bold)$(tput setaf 6)Script Usage:$(tput sgr0)
    --------------

    $(tput bold)Command:$(tput sgr0)
      $0 [SOURCE_HYPERVISOR_ID] DESTINATION_HYPERVISOR_ID [SERVER_ID(s)] [-c <number>] [-o] [-s <speed in Mbps>] [--drain-hv]

    $(tput bold)Options:$(tput sgr0)
      $(tput setaf 2)-c <number>$(tput sgr0)          Set concurrency. Determines how many VMs simultaneously migrate.
      $(tput setaf 2)-o$(tput sgr0)                   Allows migration of offline VMs.
      $(tput setaf 2)-s <speed in Mbps>$(tput sgr0)  Set transfer speed limit in Mbps.
      $(tput setaf 2)--drain-hv$(tput sgr0)         Migrate all VMs from SOURCE_HYPERVISOR_ID.

    $(tput bold)Examples:$(tput sgr0)
      $0 SRC_ID DST_ID --drain-hv -c 5 -o -s 80 : Migrate all VMs from SRC_ID to DST_ID, 5 at a time, using offline migration with a speed limit of 80Mbps.
      $0 DST_ID SERVER_ID : Migrate a single VM (SERVER_ID) to DST_ID without any concurrency.
      $0 DST_ID SERVER_ID(s) -o : Migrate specific VMs to DST_ID, and if a VM is offline at the time of running, it'll migrate offline.
      $0 DST_ID SERVER_ID(s) -s 40 : Migrate specific VMs to DST_ID at a limited speed of 40 Mbps.
      $0 DST_ID SERVER_ID(s) -c 5 : Migrate specific VMs to DST_ID with concurrency, meaning 5 VMs will migrate simultaneously.

EOL
    exit 1
fi

function migrate_server {
    SERVER_ID=$1
    DST_HV_ID=$2
    MIGRATION_RESPONSE=$(vfcli-ctrl server:migrate-live start --server=$SERVER_ID --dst=$DST_HV_ID $OFFLINE $SPEED --json)
    SUCCESS=$(echo "$MIGRATION_RESPONSE" | jq -r '.success')
    ERRORS=$(echo "$MIGRATION_RESPONSE" | jq -r '.errors[]?')

    if [[ "$SUCCESS" == "true" ]]; then
        echo "Migration of server $SERVER_ID was successful!"
    else
        echo "Migration failed for server $SERVER_ID."
        echo "Error: $ERRORS"
        sleep 3
        vfcli-ctrl server:migrate-live cancel --server=$SERVER_ID
        exit 1
    fi
}

if $DRAIN_HV; then
    SRC_HV_ID=$1
    DST_HV_ID=$2
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

        migrate_server $SERVER_ID $DST_HV_ID &

        if (( MIGRATED_COUNT % CONCURRENCY == 0 )); then
            wait
        fi
    done

    wait
else
    DST_HV_ID=$1
    SERVER_IDS=("${@:2}")
    TOTAL_SERVERS=${#SERVER_IDS[@]}
    MIGRATED_COUNT=0
    for SERVER_ID in "${SERVER_IDS[@]}"; do
        MIGRATED_COUNT=$((MIGRATED_COUNT + 1))
        echo "Migrating server with ID: $SERVER_ID ($MIGRATED_COUNT/$TOTAL_SERVERS)"

        migrate_server $SERVER_ID $DST_HV_ID &

        if (( MIGRATED_COUNT % CONCURRENCY == 0 )) || (( MIGRATED_COUNT == TOTAL_SERVERS )); then
            wait
        fi
    done

    wait
fi
