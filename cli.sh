#!/bin/bash

command=$1

docker compose -f compose.yaml exec -e CLI_PROG_NAME="marzban cli" marzban marzban-cli "$command"
