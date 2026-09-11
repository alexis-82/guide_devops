#!/bin/bash

# Stop all running containers
echo "Stopping all containers..."
docker stop $(docker ps -q)

# Remove all containers
echo "Removing all containers..."
docker rm $(docker ps -a -q)

# Remove all images
echo "Removing all images..."
docker rmi -f $(docker images -a -q)

# Remove all volumes
echo "Removing all volumes..."
docker volume prune -f

# Remove all networks
echo "Removing all networks..."
docker network prune -f

echo "Docker cleanup complete."
