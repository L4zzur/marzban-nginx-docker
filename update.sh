#!/bin/bash

echo -e "\e[34m[INFO]\e[0m Starting container update process..."

# Pull the latest images
echo -e "\e[34m[INFO]\e[0m Pulling the latest Docker images..."
docker compose pull
if [ $? -ne 0 ]; then
    echo -e "\e[31m[ERROR]\e[0m Failed to pull Docker images!"
    exit 1
fi

# Restart containers with new images and remove orphans
echo -e "\e[34m[INFO]\e[0m Restarting containers with updated images..."
docker compose up -d --remove-orphans
if [ $? -ne 0 ]; then
    echo -e "\e[31m[ERROR]\e[0m Failed to restart containers!"
    exit 1
fi

# Clean up unused images
echo -e "\e[34m[INFO]\e[0m Cleaning up unused Docker images..."
yes | docker image prune
if [ $? -ne 0 ]; then
    echo -e "\e[33m[WARNING]\e[0m Failed to clean up unused images, but update completed."
else
    echo -e "\e[34m[INFO]\e[0m Update completed successfully!"
fi
