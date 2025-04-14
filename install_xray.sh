#!/bin/bash

# Inspired by: https://github.com/Gozargah/Marzban-scripts

RELEASE_TAG="latest"  # Исправлена ошибка с пробелами вокруг знака равенства

# Function to display colorized messages
colorized_echo() {
    local color=$1
    local message=$2
    case "$color" in
        red) echo -e "\e[31m[ERROR]\e[0m $message" ;;
        green) echo -e "\e[32m[SUCCESS]\e[0m $message" ;;
        yellow) echo -e "\e[33m[WARNING]\e[0m $message" ;;
        blue) echo -e "\e[34m[INFO]\e[0m $message" ;;
        *) echo "$message" ;;
    esac
}

# Function to download and extract Xray-core
download_and_extract_xray() {
    # Check if INSTALL_DIR is provided as an argument
    if [ -n "$1" ]; then
        INSTALL_DIR="$1"
        colorized_echo blue "Using provided installation directory: $INSTALL_DIR"
    else
        # Prompt for installation directory
        read -p "Enter the directory to install Xray-core (leave empty for default '~/marzban-nginx-docker/xray'): " INSTALL_DIR
        INSTALL_DIR=${INSTALL_DIR:-~/marzban-nginx-docker/xray}
    fi

    colorized_echo blue "Downloading and extracting Xray-core..."

    # Determine the architecture
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)
            ARCH_SUFFIX="64"
            ;;
        aarch64 | arm64)
            ARCH_SUFFIX="arm64"
            ;;
        *)
            colorized_echo red "Architecture '$ARCH' is not supported. Please download Xray-core manually."
            exit 1
            ;;
    esac

    DOWNLOAD_URL="https://github.com/XTLS/Xray-core/releases/$RELEASE_TAG/download/Xray-linux-$ARCH_SUFFIX.zip"

    # Create the directory if it doesn't exist
    mkdir -p "$INSTALL_DIR"

    # Temporary directory for downloading
    TMP_DIR=$(mktemp -d)
    ZIP_FILE="$TMP_DIR/Xray-linux-$ARCH_SUFFIX.zip"

    # Download Xray-core
    colorized_echo blue "Downloading Xray-core from $DOWNLOAD_URL"
    if ! curl -L -o "$ZIP_FILE" "$DOWNLOAD_URL"; then
        colorized_echo red "Download failed! Please check your network or try again."
        rm -rf "$TMP_DIR"
        exit 1
    fi

    # Extract Xray-core to the specified directory
    colorized_echo blue "Extracting Xray-core to $INSTALL_DIR..."
    unzip -q "$ZIP_FILE" -d "$INSTALL_DIR"

    # Clean up
    rm -rf "$TMP_DIR"
    colorized_echo blue "Xray-core downloaded and extracted successfully to $INSTALL_DIR"
}

# Check if argument is provided
if [ -n "$1" ]; then
    download_and_extract_xray "$1"
else
    download_and_extract_xray
fi
