#!/bin/bash

echo "\e[34m[INFO]\e[0m Stopping containers..."

docker compose down
if [ $? -ne 0 ]; then
    echo "\e[31m[ERROR]\e[0m Failed to stop containers!"
    exit 1
fi

echo "\e[34m[INFO]\e[0m Containers stopped successfully!"