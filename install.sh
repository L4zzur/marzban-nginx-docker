#!/bin/bash
# Inspired by: https://github.com/Gozargah/Marzban-scripts

set -e  # Exit immediately if a command exits with a non-zero status

# Function to display informational messages
echo_info() {
    echo -e "\e[32m[INFO]\e[0m $1"
}

# Function to display error messages
echo_error() {
    echo -e "\e[31m[ERROR]\e[0m $1" >&2
}

# Detect the operating system
detect_os() {
    if [ -f /etc/lsb-release ]; then
        OS=$(lsb_release -si)
        elif [ -f /etc/os-release ]; then
        OS=$(awk -F= '/^NAME/{print $2}' /etc/os-release | tr -d '"')
        elif [ -f /etc/redhat-release ]; then
        OS=$(cat /etc/redhat-release | awk '{print $1}')
        elif [ -f /etc/arch-release ]; then
        OS="Arch"
    else
        colorized_echo red "Unsupported operating system"
        exit 1
    fi
}

# Function to update the package manager
detect_and_update_package_manager() {
    colorized_echo blue "Updating package manager"
    if [[ "$OS" == "Ubuntu"* ]] || [[ "$OS" == "Debian"* ]]; then
        PKG_MANAGER="apt-get"
        $PKG_MANAGER update
        elif [[ "$OS" == "CentOS"* ]] || [[ "$OS" == "AlmaLinux"* ]]; then
        PKG_MANAGER="yum"
        $PKG_MANAGER update -y
        $PKG_MANAGER install -y epel-release
        elif [ "$OS" == "Fedora"* ]; then
        PKG_MANAGER="dnf"
        $PKG_MANAGER update
        elif [ "$OS" == "Arch" ]; then
        PKG_MANAGER="pacman"
        $PKG_MANAGER -Sy
        elif [[ "$OS" == "openSUSE"* ]]; then
        PKG_MANAGER="zypper"
        $PKG_MANAGER refresh
    else
        colorized_echo red "Unsupported operating system"
        exit 1
    fi
}

# Function to install a package
install_package () {
    if [ -z $OS ]; then
        detect_os
    fi

    if [ -z $PKG_MANAGER ]; then
        detect_and_update_package_manager
    fi
    
    PACKAGE=$1
    colorized_echo blue "Installing $PACKAGE"
    if [[ "$OS" == "Ubuntu"* ]] || [[ "$OS" == "Debian"* ]]; then
        $PKG_MANAGER -y install "$PACKAGE"
        elif [[ "$OS" == "CentOS"* ]] || [[ "$OS" == "AlmaLinux"* ]]; then
        $PKG_MANAGER install -y "$PACKAGE"
        elif [ "$OS" == "Fedora"* ]; then
        $PKG_MANAGER install -y "$PACKAGE"
        elif [ "$OS" == "Arch" ]; then
        $PKG_MANAGER -S --noconfirm "$PACKAGE"
    else
        colorized_echo red "Unsupported operating system"
        exit 1
    fi
}

# Function to install Docker
install_docker() {
    echo_info "Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    echo_info "Docker installed successfully."
}

# Function to check for required dependencies
check_dependencies() {
    if ! command -v jq >/dev/null 2>&1; then
        echo_info "jq not found. Installing..."
        install_package jq
    fi
    if ! command -v curl >/dev/null 2>&1; then
        echo_info "curl not found. Installing..."
        install_package curl
    fi
    if ! command -v docker >/dev/null 2>&1; then
        echo_info "Docker not found. Installing..."
        install_docker
    fi
    if ! command -v unzip >/dev/null 2>&1; then
        echo_info "unzip not found. Installing..."
        install_package unzip
    fi
    if ! command -v wget >/dev/null 2>&1; then
        echo_info "wget not found. Installing..."
        install_package wget
    fi
    if ! command -v colorized_echo >/dev/null 2>&1; then
        echo_info "colorized_echo not found. Installing..."
        install_package colorized_echo
    fi
}

# Function to get user input
get_user_input() {
    read -p "Enter your email for acme.sh (e.g., my@example.com): " ACME_EMAIL
    read -p "Enter your Cloudflare API Key: " CF_API_KEY
    read -p "Enter your Cloudflare Email: " CF_EMAIL
    read -p "Enter your domain (e.g., example.com): " DOMAIN

    # Prompt for subdomains
    read -p "Enter your 'panel' subdomain (e.g., panel): " PANEL_SUBDOMAIN
    PANEL_SUBDOMAIN=${PANEL_SUBDOMAIN:-panel}  # Default to 'panel' if empty

    read -p "Enter your 'sub' subdomain (e.g., sub): " SUB_SUBDOMAIN
    SUB_SUBDOMAIN=${SUB_SUBDOMAIN:-sub}        # Default to 'sub' if empty

    # Prompt for location path
    read -p "Enter the Nginx location path for subscription (e.g., /user/): " LOCATION_PATH
    LOCATION_PATH=${LOCATION_PATH:-/user/}     # Default to '/user/' if empty

    # Process LOCATION_PATH to derive XRAY_SUBSCRIPTION_PATH without slashes
    # Remove leading and trailing slashes
    XRAY_SUBSCRIPTION_PATH="${LOCATION_PATH#/}"
    XRAY_SUBSCRIPTION_PATH="${XRAY_SUBSCRIPTION_PATH%/}"

    # Prompt for Support and Instruction URLs
    read -p "Enter the Support URL (e.g., https://t.me/your_support): " SUPPORT_URL
    read -p "Enter the Instruction URL (e.g., https://yourdomain.com/instruction): " INSTRUCTION_URL

    # Prompt for SUDO_USERNAME and SUDO_PASSWORD
    read -p "Enter desired SUDO_USERNAME (default: admin): " SUDO_USERNAME
    SUDO_USERNAME=${SUDO_USERNAME:-admin}

    read -sp "Enter desired SUDO_PASSWORD: " SUDO_PASSWORD
    echo
}

# Function to clone the repository
clone_repository() {
    echo_info "Cloning marzban-nginx-docker repository into ~/services..."
    cd ~
    if [ -d "services" ]; then
        echo_info "Directory 'services' already exists. Skipping clone."
    else
        git clone https://github.com/L4zzur/marzban-nginx-docker services
    fi
    cd ~/services
}

# Function to detect Docker Compose
detect_compose() {
    # Check if docker compose command exists
    if docker compose >/dev/null 2>&1; then
        COMPOSE='docker compose'
        elif docker-compose >/dev/null 2>&1; then
        COMPOSE='docker-compose'
    else
        colorized_echo red "docker compose not found"
        exit 1
    fi
}

# Function to install acme.sh
install_acme_sh() {
    echo_info "Installing acme.sh..."
    if [ -d "$HOME/.acme.sh" ]; then
        echo_info "acme.sh is already installed. Skipping installation."
    else
        curl https://get.acme.sh | sh -s email="$ACME_EMAIL"
    fi
}

# Function to set up account.conf with Cloudflare credentials
setup_account_conf() {
    echo_info "Setting up ~/.acme.sh/account.conf with Cloudflare API Key and Email..."
    CONFIG_FILE="$HOME/.acme.sh/account.conf"

    if [ -f "$CONFIG_FILE" ]; then
        # Update CF_Key if exists, else append
        if grep -q "^export CF_Key=" "$CONFIG_FILE"; then
            sed -i "s/^export CF_Key=.*/export CF_Key=\"$CF_API_KEY\"/" "$CONFIG_FILE"
            echo_info "Updated CF_Key in account.conf."
        else
            echo "export CF_Key=\"$CF_API_KEY\"" >> "$CONFIG_FILE"
            echo_info "Added CF_Key to account.conf."
        fi

        # Update CF_Email if exists, else append
        if grep -q "^export CF_Email=" "$CONFIG_FILE"; then
            sed -i "s/^export CF_Email=.*/export CF_Email=\"$CF_EMAIL\"/" "$CONFIG_FILE"
            echo_info "Updated CF_Email in account.conf."
        else
            echo "export CF_Email=\"$CF_EMAIL\"" >> "$CONFIG_FILE"
            echo_info "Added CF_Email to account.conf."
        fi
    else
        # Create the config file with both variables
        cat <<EOF > "$CONFIG_FILE"
CF_Key="$CF_API_KEY"
CF_Email="$CF_EMAIL"
EOF
        echo_info "Created account.conf with CF_Key and CF_Email."
    fi

    chmod 600 "$CONFIG_FILE"
    echo_info "Set permissions for account.conf."
}

# Function to set Let's Encrypt as the default CA
set_default_ca() {
    echo_info "Setting Let's Encrypt as the default CA..."
    ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
}

# Function to issue a wildcard certificate
issue_certificate() {
    echo_info "Issuing wildcard certificate for domain $DOMAIN..."
    ~/.acme.sh/acme.sh --issue --dns dns_cf \
        -d "$DOMAIN" \
        -d "*.$DOMAIN" \
        --key-file ~/services/certs/key.pem \
        --fullchain-file ~/services/certs/fullchain.pem

    if [ -f ~/services/certs/key.pem ] && [ -f ~/services/certs/fullchain.pem ]; then
        echo_info "Certificates successfully created and saved in ~/services/certs/"
    else
        echo_error "Failed to issue certificates. Please check the output above for details."
        exit 1
    fi
}

# Function to download and extract Xray-core
download_and_extract_xray() {
    echo_info "Downloading and extracting Xray-core..."

    # Determine the architecture
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)
            ARCH_SUFFIX="64"
            DOWNLOAD_URL="https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-$ARCH_SUFFIX.zip"
            ;;
        aarch64 | arm64)
            ARCH_SUFFIX="arm64"
            DOWNLOAD_URL="https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-$ARCH_SUFFIX.zip"
            ;;
        *)
            echo_error "Architecture '$ARCH' is not supported. Please download Xray-core manually."
            exit 1
            ;;
    esac

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


# Function to replace various placeholders in configuration files and .env
replace_placeholders() {
    echo_info "Replacing placeholders with provided domain and credentials..."

    # Define the configuration files to modify
    CONFIG_FILES=(
        "marzban/templates/singbox/default.json"
        "marzban/xray_config.json"
    )

    # Replace 'my_domain.com' with the actual domain in specified configuration files
    for file in "${CONFIG_FILES[@]}"; do
        if [ -f "$file" ]; then
            echo_info "Updating $file..."
            sed -i "s/my_domain\.com/$DOMAIN/g" "$file"
            echo_info "Updated $file successfully."
        else
            echo_error "File $file does not exist. Skipping."
        fi
    done

    # Replace 'panel.my_domain.com' and 'sub.my_domain.com' in nginx.conf
    NGINX_CONF="nginx/nginx.conf"
    if [ -f "$NGINX_CONF" ]; then
        echo_info "Updating nginx.conf with domain-specific entries..."
        # Replace 'panel.my_domain.com' with 'panel_subdomain.DOMAIN'
        sed -i "s/panel\.my_domain\.com/${PANEL_SUBDOMAIN}.${DOMAIN}/g" "$NGINX_CONF"

        # Replace 'sub.my_domain.com' with 'sub_subdomain.DOMAIN'
        sed -i "s/sub\.my_domain\.com/${SUB_SUBDOMAIN}.${DOMAIN}/g" "$NGINX_CONF"

        # Replace '/sub/' with the user-provided LOCATION_PATH
        # Ensure that LOCATION_PATH starts and ends with '/'
        LOCATION_PATH="${LOCATION_PATH/#\/*/\/}"
        LOCATION_PATH="${LOCATION_PATH%\/}/"
        sed -i "s|/sub/|$LOCATION_PATH|g" "$NGINX_CONF"

        echo_info "nginx.conf updated successfully."
    else
        echo_error "nginx.conf not found at $NGINX_CONF. Skipping nginx placeholders replacement."
    fi

    # Replace placeholders in .env file
    ENV_FILE="marzban/.env"
    if [ -f "$ENV_FILE" ]; then
        echo_info "Updating .env file with user credentials and subscription paths..."

        # Replace SUDO_USERNAME
        if grep -q "^SUDO_USERNAME=" "$ENV_FILE"; then
            sed -i "s/^SUDO_USERNAME=.*/SUDO_USERNAME=\"$SUDO_USERNAME\"/" "$ENV_FILE"
            echo_info "Updated SUDO_USERNAME in .env."
        else
            echo "SUDO_USERNAME=\"$SUDO_USERNAME\"" >> "$ENV_FILE"
            echo_info "Added SUDO_USERNAME to .env."
        fi

        # Replace SUDO_PASSWORD
        if grep -q "^SUDO_PASSWORD=" "$ENV_FILE"; then
            sed -i "s/^SUDO_PASSWORD=.*/SUDO_PASSWORD=\"$SUDO_PASSWORD\"/" "$ENV_FILE"
            echo_info "Updated SUDO_PASSWORD in .env."
        else
            echo "SUDO_PASSWORD=\"$SUDO_PASSWORD\"" >> "$ENV_FILE"
            echo_info "Added SUDO_PASSWORD to .env."
        fi

        # Replace XRAY_SUBSCRIPTION_URL_PREFIX
        XRAY_SUBSCRIPTION_URL_PREFIX="https://${SUB_SUBDOMAIN}.${DOMAIN}"
        if grep -q "^XRAY_SUBSCRIPTION_URL_PREFIX=" "$ENV_FILE"; then
            sed -i "s|^XRAY_SUBSCRIPTION_URL_PREFIX=.*|XRAY_SUBSCRIPTION_URL_PREFIX=\"$XRAY_SUBSCRIPTION_URL_PREFIX\"|" "$ENV_FILE"
            echo_info "Updated XRAY_SUBSCRIPTION_URL_PREFIX in .env."
        else
            echo "XRAY_SUBSCRIPTION_URL_PREFIX=\"$XRAY_SUBSCRIPTION_URL_PREFIX\"" >> "$ENV_FILE"
            echo_info "Added XRAY_SUBSCRIPTION_URL_PREFIX to .env."
        fi

        # Replace XRAY_SUBSCRIPTION_PATH with LOCATION_PATH without slashes
        if grep -q "^XRAY_SUBSCRIPTION_PATH=" "$ENV_FILE"; then
            sed -i "s/^XRAY_SUBSCRIPTION_PATH=.*/XRAY_SUBSCRIPTION_PATH=\"$XRAY_SUBSCRIPTION_PATH\"/" "$ENV_FILE"
            echo_info "Updated XRAY_SUBSCRIPTION_PATH in .env."
        else
            echo "XRAY_SUBSCRIPTION_PATH=\"$XRAY_SUBSCRIPTION_PATH\"" >> "$ENV_FILE"
            echo_info "Added XRAY_SUBSCRIPTION_PATH to .env."
        fi
    else
        echo_error ".env file not found at $ENV_FILE. Skipping .env placeholders replacement."
    fi

    # Insert Support and Instruction URLs into subscription/index.html
    SUBSCRIPTION_HTML="marzban/templates/subscription/index.html"
    if [ -f "$SUBSCRIPTION_HTML" ]; then
        echo_info "Inserting Support and Instruction URLs into $SUBSCRIPTION_HTML..."

        # Replace the first occurrence of a placeholder comment or specific marker with the Support URL
        # Assuming there's a specific comment or identifiable pattern to insert the link
        # For example, replacing '<!-- SUPPORT_LINK -->' with the actual link
        # If not, adjust the sed command accordingly.

        # Insert Support URL
        # Example: Replace the first 'href="https://t.me/"' with the SUPPORT_URL
        sed -i "s|href=\"https://t.me/\"|href=\"$SUPPORT_URL\"|g" "$SUBSCRIPTION_HTML"

        # Insert Instruction URL
        # Example: Replace the first 'href=""' with the INSTRUCTION_URL
        sed -i "s|href=\"\"|href=\"$INSTRUCTION_URL\"|g" "$SUBSCRIPTION_HTML"

        echo_info "Inserted Support and Instruction URLs successfully."
    else
        echo_error "File $SUBSCRIPTION_HTML does not exist. Skipping link insertion."
    fi

    echo_info "All placeholder replacements completed successfully."
}

chmod_scripts() {
    echo_info "Changing permissions for scripts..."
    cd ~/services
    chmod +x *.sh
}

check_dependencies
get_user_input
clone_repository
install_acme_sh
setup_account_conf
set_default_ca
issue_certificate
download_and_extract_xray
replace_placeholders
chmod_scripts
