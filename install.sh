#!/bin/bash
# Inspired by: https://github.com/Gozargah/Marzban-scripts

set -e  # Exit immediately if a command exits with a non-zero status

# Configuration variables
GITHUB_REPO="https://github.com/L4zzur/marzban-nginx-docker"
XRAY_DOWNLOAD_URL_BASE="https://github.com/XTLS/Xray-core/releases/latest/download"
ACME_SH_INSTALL_URL="https://get.acme.sh"
DEFAULT_CA_SERVER="letsencrypt"
DOCKER_INSTALL_URL="https://get.docker.com"
DEFAULT_REPO_DIR="marzban-nginx-docker"
DEFAULT_PANEL_SUBDOMAIN="panel"
DEFAULT_SUB_SUBDOMAIN="sub"
DEFAULT_LOCATION_PATH="user"
DEFAULT_DASHBOARD_PATH="dashboard"
DEFAULT_VPN_NAME="Template VPN"
DEFAULT_ADMIN_USERNAME="admin"

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
    colorized_echo blue "Installing Docker..."
    curl -fsSL "$DOCKER_INSTALL_URL" | sh
    
    # Add current user to docker group
    colorized_echo blue "Adding current user to docker group..."
    sudo groupadd -f docker
    sudo usermod -aG docker $USER
    
    colorized_echo blue "Docker installed successfully."
    colorized_echo yellow "IMPORTANT: You need to log out and log back in for the Docker group changes to take effect."
    colorized_echo yellow "Please restart your session now and then run this script again."
    exit 0
}

# Function to check if the user is in the Docker group
check_docker_group() {
    if ! groups | grep -q docker; then
        colorized_echo yellow "Your user is not in the Docker group. Please restart your session and run this script again."
        exit 0
    fi
}

# Function to check for required dependencies
check_dependencies() {
    if ! command -v jq >/dev/null 2>&1; then
        colorized_echo blue "jq not found. Installing..."
        install_package jq
    fi
    if ! command -v curl >/dev/null 2>&1; then
        colorized_echo blue "curl not found. Installing..."
        install_package curl
    fi
    if ! command -v docker >/dev/null 2>&1; then
        colorized_echo blue "Docker not found. Installing..."
        install_docker
    fi
    if ! command -v unzip >/dev/null 2>&1; then
        colorized_echo blue "unzip not found. Installing..."
        install_package unzip
    fi
    if ! command -v wget >/dev/null 2>&1; then
        colorized_echo blue "wget not found. Installing..."
        install_package wget
    fi
}

# Function to get user input for domain and path configuration
get_user_input() {
    read -p "Enter your email for acme.sh (e.g., my@example.com): " ACME_EMAIL
    read -p "Enter your Cloudflare Email (press Enter to use the same as acme.sh email): " CF_EMAIL
    CF_EMAIL=${CF_EMAIL:-$ACME_EMAIL}  # Use ACME_EMAIL if CF_EMAIL is empty
    read -p "Enter your Cloudflare API Key: " CF_API_KEY
    read -p "Enter your domain (e.g., example.com): " DOMAIN

    # Make sure domain doesn't have "http://" or "https://" prefix
    DOMAIN=$(echo "$DOMAIN" | sed 's#^https?://##')
    # Remove trailing slash if present
    DOMAIN=${DOMAIN%/}

    # Prompt for subdomains
    read -p "Enter your 'panel' subdomain (leave empty for default '$DEFAULT_PANEL_SUBDOMAIN'): " PANEL_SUBDOMAIN
    PANEL_SUBDOMAIN=${PANEL_SUBDOMAIN:-$DEFAULT_PANEL_SUBDOMAIN}  # Default to 'panel' if empty

    read -p "Enter your 'sub' subdomain (default: '$DEFAULT_SUB_SUBDOMAIN'): " SUB_SUBDOMAIN
    SUB_SUBDOMAIN=${SUB_SUBDOMAIN:-$DEFAULT_SUB_SUBDOMAIN}        # Default to 'sub' if empty

    # Prompt for paths without slashes
    read -p "Enter the location path for subscription without slashes (default: '$DEFAULT_LOCATION_PATH'): " LOCATION_PATH
    LOCATION_PATH=${LOCATION_PATH:-$DEFAULT_LOCATION_PATH}     # Default to 'user' if empty

    read -p "Enter the location path for dashboard without slashes (default: '$DEFAULT_DASHBOARD_PATH'): " DASHBOARD_PATH
    DASHBOARD_PATH=${DASHBOARD_PATH:-$DEFAULT_DASHBOARD_PATH}     # Default to 'dashboard' if empty

    # Set XRAY_SUBSCRIPTION_PATH to the same value as LOCATION_PATH
    XRAY_SUBSCRIPTION_PATH="$LOCATION_PATH"

    # Prompt for VPN name to replace 'Template VPN'
    read -p "Enter the name of your VPN service (default: '$DEFAULT_VPN_NAME'): " VPN_NAME
    VPN_NAME=${VPN_NAME:-$DEFAULT_VPN_NAME}  # Default to 'Template VPN' if empty

    # Prompt for optional Support and Instruction URLs
    read -p "Enter the Support URL (optional, press Enter to skip): " SUPPORT_URL
    read -p "Enter the Instruction URL (optional, press Enter to skip): " INSTRUCTION_URL

    echo

    # Display summary of inputs for confirmation
    colorized_echo blue "Summary of your inputs:"
    colorized_echo blue "Domain: $DOMAIN"
    colorized_echo blue "Panel Subdomain: $PANEL_SUBDOMAIN.$DOMAIN"
    colorized_echo blue "Subscription Subdomain: $SUB_SUBDOMAIN.$DOMAIN"
    colorized_echo blue "Subscription Path: $LOCATION_PATH (without slashes)"
    colorized_echo blue "Dashboard Path: $DASHBOARD_PATH"
    colorized_echo blue "VPN Name: $VPN_NAME"

    # Ask for confirmation
    read -p "Is this information correct? (y/n): " confirm
    if [[ $confirm != "y" && $confirm != "Y" ]]; then
        colorized_echo yellow "Setup cancelled. Please run the script again."
        exit 1
    fi
}

# Function to clone the repository
clone_repository() {
    read -p "Enter the name of the directory to clone into (leave empty for default '$DEFAULT_REPO_DIR'): " REPO_DIR
    REPO_DIR=${REPO_DIR:-$DEFAULT_REPO_DIR}  # Default to 'services' if empty
    
    colorized_echo blue "Cloning marzban-nginx-docker repository into ~/$REPO_DIR..."
    cd ~
    if [ -d "$REPO_DIR" ]; then
        colorized_echo blue "Directory '$REPO_DIR' already exists. Skipping clone."
    else
        git clone "$GITHUB_REPO" "$REPO_DIR"
    fi
    cd ~/"$REPO_DIR"
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
    colorized_echo blue "Installing acme.sh..."
    if [ -d "$HOME/.acme.sh" ]; then
        colorized_echo blue "acme.sh is already installed. Skipping installation."
    else
        curl "$ACME_SH_INSTALL_URL" | sh -s email="$ACME_EMAIL"
    fi
}

# Function to set up account.conf with Cloudflare credentials
setup_account_conf() {
    colorized_echo blue "Setting up ~/.acme.sh/account.conf with Cloudflare API Key and Email..."
    CONFIG_FILE="$HOME/.acme.sh/account.conf"

    # Read current values if file exists
    if [ -f "$CONFIG_FILE" ]; then
        CURRENT_CF_KEY=$(grep '^CF_Key=' "$CONFIG_FILE" | head -n1 | cut -d'=' -f2- | tr -d '"')
        CURRENT_CF_EMAIL=$(grep '^CF_Email=' "$CONFIG_FILE" | head -n1 | cut -d'=' -f2- | tr -d '"')
    else
        CURRENT_CF_KEY=""
        CURRENT_CF_EMAIL=""
    fi

    # Ask if user wants to update existing values
    if [ -n "$CURRENT_CF_KEY" ] || [ -n "$CURRENT_CF_EMAIL" ]; then
        colorized_echo yellow "Cloudflare credentials already exist in account.conf:"
        [ -n "$CURRENT_CF_EMAIL" ] && echo "  CF_Email: $CURRENT_CF_EMAIL"
        [ -n "$CURRENT_CF_KEY" ] && echo "  CF_Key: $CURRENT_CF_KEY"
        read -p "Do you want to update them? (y/N): " update_cf
        if [[ ! "$update_cf" =~ ^[Yy]$ ]]; then
            colorized_echo blue "Keeping existing Cloudflare credentials."
            return
        fi
    fi

    # Remove old lines
    sed -i '/^CF_Key=/d' "$CONFIG_FILE" 2>/dev/null || true
    sed -i '/^CF_Email=/d' "$CONFIG_FILE" 2>/dev/null || true

    # Write new values
    echo "CF_Key=\"$CF_API_KEY\"" >> "$CONFIG_FILE"
    echo "CF_Email=\"$CF_EMAIL\"" >> "$CONFIG_FILE"

    chmod 600 "$CONFIG_FILE"
    colorized_echo blue "Cloudflare credentials updated in account.conf."
}



# Function to set Let's Encrypt as the default CA
set_default_ca() {
    colorized_echo blue "Setting Let's Encrypt as the default CA..."
    ~/.acme.sh/acme.sh --set-default-ca --server "$DEFAULT_CA_SERVER"
}

# Function to issue a wildcard certificate
issue_certificate() {
    colorized_echo blue "Issuing wildcard certificate for domain $DOMAIN..."
    
    # Create certs directory if it doesn't exist
    mkdir -p ~/"$REPO_DIR"/certs
    
    ~/.acme.sh/acme.sh --issue --dns dns_cf \
        -d "$DOMAIN" \
        -d "*.$DOMAIN" \
        --key-file ~/"$REPO_DIR"/certs/key.pem \
        --fullchain-file ~/"$REPO_DIR"/certs/fullchain.pem \
        --force

    if [ -f ~/"$REPO_DIR"/certs/key.pem ] && [ -f ~/"$REPO_DIR"/certs/fullchain.pem ]; then
        colorized_echo blue "Certificates successfully created and saved in ~/$REPO_DIR/certs/"
    else
        colorized_echo red "Failed to issue certificates. Please check the output above for details."
        exit 1
    fi
}


# Function to download and extract Xray-core
download_and_extract_xray() {
    colorized_echo blue "Downloading and extracting Xray-core..."

    # Create xray directory if it doesn't exist
    mkdir -p ~/"$REPO_DIR"/xray

    # Determine the architecture
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)
            ARCH_SUFFIX="64"
            DOWNLOAD_URL="$XRAY_DOWNLOAD_URL_BASE/Xray-linux-$ARCH_SUFFIX.zip"
            ;;
        aarch64 | arm64)
            ARCH_SUFFIX="arm64"
            DOWNLOAD_URL="$XRAY_DOWNLOAD_URL_BASE/Xray-linux-$ARCH_SUFFIX.zip"
            ;;
        *)
            colorized_echo red "Architecture '$ARCH' is not supported. Please download Xray-core manually."
            exit 1
            ;;
    esac

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
    colorized_echo blue "Extracting Xray-core to ~/$REPO_DIR/xray..."
    unzip -q "$ZIP_FILE" -d ~/"$REPO_DIR"/xray/

    # Clean up
    rm -rf "$TMP_DIR"
    colorized_echo blue "Xray-core downloaded and extracted successfully to ~/$REPO_DIR/xray"
    
    # Verify installation
    if [ -f ~/"$REPO_DIR"/xray/xray ]; then
        colorized_echo green "Xray-core installed successfully in ~/$REPO_DIR/xray/"
    else
        colorized_echo red "Failed to install Xray-core. Please check the output above for details."
        exit 1
    fi
}


# Function to replace various placeholders in all configuration files
replace_placeholders() {
    colorized_echo blue "Replacing placeholders with provided domain and credentials..."

    # Ensure we're in the repository directory
    cd ~/"$REPO_DIR"

    # 1. Replace panel subdomain
    colorized_echo blue "Replacing 'panel.my_domain.com' with '${PANEL_SUBDOMAIN}.${DOMAIN}' in all files..."
    find . -type f -not -path "*/\.*" -exec grep -l "panel\.my_domain\.com" {} \; | while read -r file; do
        colorized_echo blue "Updating panel subdomain in $file..."
        sed -i "s/panel\.my_domain\.com/${PANEL_SUBDOMAIN}.${DOMAIN}/g" "$file"
    done

    # 2. Replace sub subdomain
    colorized_echo blue "Replacing 'sub.my_domain.com' with '${SUB_SUBDOMAIN}.${DOMAIN}' in all files..."
    find . -type f -not -path "*/\.*" -exec grep -l "sub\.my_domain\.com" {} \; | while read -r file; do
        colorized_echo blue "Updating sub subdomain in $file..."
        sed -i "s/sub\.my_domain\.com/${SUB_SUBDOMAIN}.${DOMAIN}/g" "$file"
    done

    # 3. Replace domain in all relevant files
    colorized_echo blue "Replacing 'my_domain.com' with '$DOMAIN' in all files..."
    find . -type f -not -path "*/\.*" -exec grep -l "my_domain\.com" {} \; | while read -r file; do
        colorized_echo blue "Updating domain in $file..."
        sed -i "s/my_domain\.com/$DOMAIN/g" "$file"
    done

    # 4. Update .env file with specific settings
    ENV_FILE="marzban/.env"
    if [ -f "$ENV_FILE" ]; then
        colorized_echo blue "Updating .env file with subscription paths..."

        # Replace DASHBOARD_PATH (with slashes)
        if grep -q "^DASHBOARD_PATH" "$ENV_FILE"; then
            sed -i "s|^DASHBOARD_PATH=.*|DASHBOARD_PATH=\"/${DASHBOARD_PATH}/\"|" "$ENV_FILE"
        else
            echo "DASHBOARD_PATH=\"/${DASHBOARD_PATH}/\"" >> "$ENV_FILE"
        fi

        # Replace XRAY_SUBSCRIPTION_URL_PREFIX
        XRAY_SUBSCRIPTION_URL_PREFIX="https://${SUB_SUBDOMAIN}.${DOMAIN}"
        if grep -q "^XRAY_SUBSCRIPTION_URL_PREFIX" "$ENV_FILE"; then
            sed -i "s|^XRAY_SUBSCRIPTION_URL_PREFIX=.*|XRAY_SUBSCRIPTION_URL_PREFIX=\"$XRAY_SUBSCRIPTION_URL_PREFIX\"|" "$ENV_FILE"
        else
            echo "XRAY_SUBSCRIPTION_URL_PREFIX=\"$XRAY_SUBSCRIPTION_URL_PREFIX\"" >> "$ENV_FILE"
        fi

        # Replace XRAY_SUBSCRIPTION_PATH
        if grep -q "^XRAY_SUBSCRIPTION_PATH" "$ENV_FILE"; then
            sed -i "s/^XRAY_SUBSCRIPTION_PATH=.*/XRAY_SUBSCRIPTION_PATH=\"$XRAY_SUBSCRIPTION_PATH\"/" "$ENV_FILE"
        else
            echo "XRAY_SUBSCRIPTION_PATH=\"$XRAY_SUBSCRIPTION_PATH\"" >> "$ENV_FILE"
        fi
    else
        colorized_echo red ".env file not found at $ENV_FILE. Skipping .env placeholders replacement."
    fi

    # 5. Update location path in nginx site config
    NGINX_SITE="nginx/sites-enabled/sub.my_domain.com.conf"
    NEW_NGINX_SITE="nginx/sites-enabled/${SUB_SUBDOMAIN}.${DOMAIN}.conf"
    if [ -f "$NGINX_SITE" ]; then
        colorized_echo blue "Updating location path in $NGINX_SITE..."
        sed -i "s|location /user/|location /${LOCATION_PATH}/|g" "$NGINX_SITE"
        
        # Rename the file if domain changed
        if [ "$NGINX_SITE" != "$NEW_NGINX_SITE" ]; then
            colorized_echo blue "Renaming $NGINX_SITE to $NEW_NGINX_SITE..."
            mv "$NGINX_SITE" "$NEW_NGINX_SITE"
        fi
    else
        # Check if the file already exists with the new name
        if [ -f "$NEW_NGINX_SITE" ]; then
            colorized_echo blue "Updating location path in $NEW_NGINX_SITE..."
            sed -i "s|location /user/|location /${LOCATION_PATH}/|g" "$NEW_NGINX_SITE"
        else
            colorized_echo red "Nginx site config not found. Skipping location path update."
        fi
    fi

    # 6. Handle subscription template HTML file
    SUBSCRIPTION_HTML="marzban/templates/subscription/index.html"
    if [ -f "$SUBSCRIPTION_HTML" ]; then
        colorized_echo blue "Updating subscription template in $SUBSCRIPTION_HTML..."

        # Replace Template VPN with custom VPN name
        sed -i "s/Template VPN/$VPN_NAME/g" "$SUBSCRIPTION_HTML"

        # Handle optional Support URL
        if [ -z "$SUPPORT_URL" ] || [ "$SUPPORT_URL" = "" ]; then
            # Remove the Support URL block
            colorized_echo blue "Removing Support URL block from template..."
            # Look for the line with the support link and remove the whole <li> tag
            sed -i '/<li>.*href="https:\/\/t.me\/".*/{:a;N;/<\/li>/!ba;d;}' "$SUBSCRIPTION_HTML"
        else
            # Insert Support URL
            sed -i "s|href=\"https://t.me/\"|href=\"$SUPPORT_URL\"|" "$SUBSCRIPTION_HTML"
        fi

        # Handle optional Instruction URL
        if [ -z "$INSTRUCTION_URL" ] || [ "$INSTRUCTION_URL" = "" ]; then
            # Remove the Instruction URL block
            colorized_echo blue "Removing Instruction URL block from template..."
            # Look for the line with empty href and remove the whole <li> tag
            sed -i '/<li>.*href="".*/{:a;N;/<\/li>/!ba;d;}' "$SUBSCRIPTION_HTML"
        else
            # Insert Instruction URL
            sed -i "s|href=\"\"|href=\"$INSTRUCTION_URL\"|" "$SUBSCRIPTION_HTML"
        fi
    else
        colorized_echo red "File $SUBSCRIPTION_HTML does not exist. Skipping subscription template updates."
    fi

    # 7. Update site configuration files names if they exist
    colorized_echo blue "Checking for files that need renaming..."
    
    # Check for panel.my_domain.com.conf
    OLD_PANEL_CONF="nginx/sites-enabled/panel.my_domain.com.conf"
    NEW_PANEL_CONF="nginx/sites-enabled/${PANEL_SUBDOMAIN}.${DOMAIN}.conf"
    if [ -f "$OLD_PANEL_CONF" ] && [ "$OLD_PANEL_CONF" != "$NEW_PANEL_CONF" ]; then
        colorized_echo blue "Renaming $OLD_PANEL_CONF to $NEW_PANEL_CONF..."
        mv "$OLD_PANEL_CONF" "$NEW_PANEL_CONF"
    fi
    
    # Check for my_domain.com.conf
    OLD_DOMAIN_CONF="nginx/sites-enabled/my_domain.com.conf"
    NEW_DOMAIN_CONF="nginx/sites-enabled/${DOMAIN}.conf"
    if [ -f "$OLD_DOMAIN_CONF" ] && [ "$OLD_DOMAIN_CONF" != "$NEW_DOMAIN_CONF" ]; then
        colorized_echo blue "Renaming $OLD_DOMAIN_CONF to $NEW_DOMAIN_CONF..."
        mv "$OLD_DOMAIN_CONF" "$NEW_DOMAIN_CONF"
    fi

    colorized_echo blue "All placeholder replacements completed successfully."
}

# Function to ensure Docker daemon access
ensure_docker_access() {
    colorized_echo blue "Ensuring access to Docker daemon..."
    
    # Check if user is in docker group
    if ! groups | grep -q docker; then
        colorized_echo yellow "Current user is not in the docker group. Adding..."
        
        # Create docker group if it doesn't exist
        sudo groupadd -f docker
        
        # Add current user to docker group
        sudo usermod -aG docker $USER
        
        colorized_echo blue "User added to docker group. You may need to log out and log back in for changes to take effect."
        colorized_echo blue "Alternatively, we can try to apply the changes now..."
        
        # Try to apply group changes without logging out
        newgrp docker << EOF
            # Continue script execution after newgrp
            cd ~/"$REPO_DIR"
            docker compose up -d
            sleep 10
            create_admin_user_internal
            exit
EOF
        
        # Exit script after newgrp completes
        colorized_echo green "Installation completed successfully!"
        colorized_echo green "Your Marzban panel is available at: https://${PANEL_SUBDOMAIN}.${DOMAIN}/${DASHBOARD_PATH}"
        colorized_echo green "Login with the admin credentials you provided."
        exit 0
    fi
    
    # Check if docker.sock is accessible
    if [ ! -w /var/run/docker.sock ]; then
        colorized_echo yellow "Cannot write to /var/run/docker.sock. Adjusting permissions..."
        
        # Option 1: Temporary fix (not recommended for production)
        sudo chmod 666 /var/run/docker.sock
        
        # Option 2: Better approach - ensure socket has correct group ownership
        # sudo chown root:docker /var/run/docker.sock
    fi
}

# Function to create admin user using marzban-cli
create_admin_user() {
    colorized_echo blue "Creating admin user..."
    
    # Start the services
    colorized_echo blue "Starting services..."
    cd ~/"$REPO_DIR"
    docker compose up -d
    
    # Wait for services to be ready
    colorized_echo blue "Waiting for services to be ready..."
    sleep 10
    
    # Prompt for admin username and password
    read -p "Enter admin username (leave empty for default '$DEFAULT_ADMIN_USERNAME'): " ADMIN_USERNAME
    ADMIN_USERNAME=${ADMIN_USERNAME:-$DEFAULT_ADMIN_USERNAME}
    
    # read -sp "Enter admin password: " ADMIN_PASSWORD
    # echo
    # read -sp "Confirm admin password: " ADMIN_PASSWORD_CONFIRM
    # echo
    
    # # Check if passwords match
    # if [ "$ADMIN_PASSWORD" != "$ADMIN_PASSWORD_CONFIRM" ]; then
    #     colorized_echo red "Passwords do not match. Please try again."
    #     create_admin_user
    #     return
    # fi
    
    # Create admin user
    colorized_echo blue "Creating admin user '$ADMIN_USERNAME'..."
    if docker compose exec marzban marzban-cli admin create --username "$ADMIN_USERNAME" --sudo; then
        colorized_echo green "Admin user '$ADMIN_USERNAME' created successfully."
    else
        colorized_echo red "Failed to create admin user. Please check the output above for details."
    fi
}

# Function to change permissions for scripts
chmod_scripts() {
    colorized_echo blue "Changing permissions for scripts..."
    cd ~/"$REPO_DIR"
    chmod +x *.sh
}

# Main script execution
check_dependencies
check_docker_group
get_user_input
clone_repository
install_acme_sh
setup_account_conf
set_default_ca
issue_certificate
download_and_extract_xray
replace_placeholders
chmod_scripts
create_admin_user

colorized_echo green "Installation completed successfully!"
colorized_echo green "Your Marzban panel is available at: https://${PANEL_SUBDOMAIN}.${DOMAIN}/${DASHBOARD_PATH}"
colorized_echo green "Login with the admin credentials you provided."
