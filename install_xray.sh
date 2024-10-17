#!/bin/bash

# Inspired by: https://github.com/Gozargah/Marzban-scripts

RELEASE_TAG = "latest"

download_and_extract_xray() {
    echo_info "Downloading and extracting Xray-core..."

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
            echo_error "Architecture '$ARCH' is not supported. Please download Xray-core manually."
            exit 1
            ;;
    esac

    DOWNLOAD_URL="https://github.com/XTLS/Xray-core/releases/$RELEASE_TAG/download/Xray-linux-$ARCH_SUFFIX.zip"

    # Temporary directory for downloading
    TMP_DIR=$(mktemp -d)
    ZIP_FILE="$TMP_DIR/Xray-linux-$ARCH_SUFFIX.zip"

    # Download Xray-core
    echo_info "Downloading Xray-core from $DOWNLOAD_URL"
    if ! curl -L -o "$ZIP_FILE" "$DOWNLOAD_URL"; then
        echo_error "Download failed! Please check your network or try again."
        rm -rf "$TMP_DIR"
        exit 1
    fi

    # Extract Xray-core to services/xray
    echo_info "Extracting Xray-core to ~/services/xray..."
    unzip -q "$ZIP_FILE" -d ~/services/xray/

    # Clean up
    rm -rf "$TMP_DIR"
    echo_info "Xray-core downloaded and extracted successfully."
}

download_and_extract_xray