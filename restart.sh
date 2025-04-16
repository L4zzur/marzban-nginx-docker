#!/bin/bash

echo -e "\e[34m[INFO]\e[0m Restarting containers..."

echo -e "\e[34m[INFO]\e[0m Stopping running containers..."
docker compose down
if [ $? -ne 0 ]; then
    echo -e "\e[31m[ERROR]\e[0m Failed to stop containers!"
    exit 1
fi

echo -e "\e[34m[INFO]\e[0m Starting containers..."
docker compose up -d
if [ $? -ne 0 ]; then
    echo -e "\e[31m[ERROR]\e[0m Failed to start containers!"
    exit 1
fi

echo -e "\e[34m[INFO]\e[0m Containers restarted successfully!"