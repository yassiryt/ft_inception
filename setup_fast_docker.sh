#!/bin/bash

# This script moves your rootless Docker storage from the slow NFS home directory
# to the local /goinfre drive on 1337 cluster Ubuntu machines.
# This prevents extreme slowness caused by the 'vfs' storage driver and NFS latency.

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

if [ -z "$USER" ]; then
    echo -e "${RED}USER environment variable is not set.${NC}"
    exit 1
fi

GOINFRE_DIR="/goinfre/$USER"
DOCKER_HOME="$HOME/.local/share/docker"
DOCKER_GOINFRE="$GOINFRE_DIR/.docker"

echo "Checking environment..."

if [ ! -d "$GOINFRE_DIR" ]; then
    echo -e "${RED}Error: $GOINFRE_DIR does not exist. Are you on a cluster machine?${NC}"
    echo "If you are on an iMac, the path might be /sgoinfre/goinfre/Perso/$USER"
    exit 1
fi

# Stop rootless docker if it's running
echo "Stopping Docker if running..."
systemctl --user stop docker || true

# Move existing docker data or create new dir
if [ -L "$DOCKER_HOME" ]; then
    echo -e "${GREEN}Docker is already symlinked to goinfre!${NC}"
else
    echo "Relocating Docker storage to $GOINFRE_DIR..."
    
    mkdir -p "$DOCKER_GOINFRE"
    
    if [ -d "$DOCKER_HOME" ] && [ ! -L "$DOCKER_HOME" ]; then
        echo "Moving existing Docker data (this might take a minute)..."
        rsync -aP "$DOCKER_HOME/" "$DOCKER_GOINFRE/"
        rm -rf "$DOCKER_HOME"
    fi
    
    mkdir -p "$(dirname "$DOCKER_HOME")"
    ln -s "$DOCKER_GOINFRE" "$DOCKER_HOME"
    
    echo -e "${GREEN}Successfully symlinked $DOCKER_HOME to $DOCKER_GOINFRE${NC}"
fi

# Restart docker
echo "Starting Docker..."
systemctl --user start docker || true

echo -e "${GREEN}Done! Docker is now running off the fast local disk.${NC}"
