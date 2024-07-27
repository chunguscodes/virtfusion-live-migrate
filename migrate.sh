#!/bin/bash

check_dependencies() {
    for cmd in jq vfcli-ctrl; do
        if ! command -v $cmd &>/dev/null; then
            echo "$(tput setaf 1)Error: $cmd is not installed. Please install it before running this script.$(tput sgr0)"
            exit 1
        fi
    done
}

display_help() {
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
}

CONCURRENCY=1; OFFLINE=""; SPEED=""; DRAIN_HV=false; POSITIONAL=(); STOP=false; SUCCESS_COUNT=0; FAIL_COUNT=0; FAILED_SERVERS=()

check_dependencies

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
[[ ${#POSITIONAL[@]} -lt 2 ]] && { display_help; exit 1; }

trap 'STOP=true' SIGINT

migrate_server() {
    local SERVER_ID=$1 DST_HV_ID=$2
    local MIGRATION_RESPONSE=$(vfcli-ctrl server:migrate-live start --server=$SERVER_ID --dst=$DST_HV_ID $OFFLINE $SPEED --json)
    local SUCCESS=$(echo "$MIGRATION_RESPONSE" | jq -r '.success')
    local ERRORS=$(echo "$MIGRATION_RESPONSE" | jq -r '.errors[]?')

    [[ "$SUCCESS" == "true" ]] && { echo "Migration of server $SERVER_ID was successful!"; return 0; } || {
        echo "Migration failed for server $SERVER_ID. Error: $ERRORS"
        sleep 3
        vfcli-ctrl server:migrate-live cancel --server=$SERVER_ID
        return 1
    }
}

if $DRAIN_HV; then
    SRC_HV_ID=$1
    DST_HV_ID=$2
    read -p "Are you sure you want to migrate all VMs from hypervisor $SRC_HV_ID to $DST_HV_ID? (yes/no): " confirmation
    [[ "$confirmation" != "yes" ]] && { echo "Migration cancelled by user."; exit 0; }

    SERVER_LIST_JSON=$(vfcli-ctrl server:migrate-live servers --src=$SRC_HV_ID --json)
    [[ -z "$SERVER_LIST_JSON" ]] && { echo "Failed to retrieve the server list."; exit 1; }

    SERVER_IDS=$(echo "$SERVER_LIST_JSON" | jq -r '.servers[].id')
    TOTAL_SERVERS=$(echo "$SERVER_IDS" | wc -w)
    MIGRATED_COUNT=0

    for SERVER_ID in $SERVER_IDS; do
        $STOP && { echo "Stopping further migrations after ongoing migration is complete!"; break; }
        MIGRATED_COUNT=$((MIGRATED_COUNT + 1))
        echo "Migrating server with ID: $SERVER_ID ($MIGRATED_COUNT/$TOTAL_SERVERS)"
        migrate_server $SERVER_ID $DST_HV_ID &
        [[ $? -eq 0 ]] && SUCCESS_COUNT=$((SUCCESS_COUNT + 1)) || { FAIL_COUNT=$((FAIL_COUNT + 1)); FAILED_SERVERS+=("$SERVER_ID"); }
        (( MIGRATED_COUNT % CONCURRENCY == 0 )) && wait
    done
    wait
else
    DST_HV_ID=$1
    SERVER_IDS=("${@:2}")
    TOTAL_SERVERS=${#SERVER_IDS[@]}
    MIGRATED_COUNT=0

    for SERVER_ID in "${SERVER_IDS[@]}"; do
        $STOP && { echo "Stopping further migrations as requested."; break; }
        MIGRATED_COUNT=$((MIGRATED_COUNT + 1))
        echo "Migrating server with ID: $SERVER_ID ($MIGRATED_COUNT/$TOTAL_SERVERS)"
        migrate_server $SERVER_ID $DST_HV_ID &
        [[ $? -eq 0 ]] && SUCCESS_COUNT=$((SUCCESS_COUNT + 1)) || { FAIL_COUNT=$((FAIL_COUNT + 1)); FAILED_SERVERS+=("$SERVER_ID"); }
        (( MIGRATED_COUNT % CONCURRENCY == 0 )) || (( MIGRATED_COUNT == TOTAL_SERVERS )) && wait
    done
    wait
fi

echo "Migration Summary:"
echo "-----------------"
echo "Total servers attempted: $TOTAL_SERVERS"
echo "Successfully migrated: $SUCCESS_COUNT"
echo "Failed migrations: $FAIL_COUNT"
(( FAIL_COUNT > 0 )) && { echo "Failed server IDs:"; for SERVER_ID in "${FAILED_SERVERS[@]}"; do echo "  - $SERVER_ID"; done; }
echo "Migration completed!"
