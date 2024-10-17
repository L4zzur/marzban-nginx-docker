#!/bin/bash

docker compose -f compose.yaml exec -e CLI_PROG_NAME="marzban cli" marzban marzban-cli "$@"
