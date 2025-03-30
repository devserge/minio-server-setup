#!/bin/bash

# =============================================================================
# MinIO Server Setup Script
# =============================================================================
# Author: Serge Huijsen (CEO of CodeIQ)
# GitHub: https://github.com/devserge
# Version: 1.0.0
# License: MIT
# 
# This script automates the installation and configuration of:
# - MinIO Object Storage Server
# - Nginx as a reverse proxy
# - SSL certificates via Let's Encrypt
# 
# Features:
# - Interactive setup with user-friendly prompts
# - Automatic SSL certificate management (Let's Encrypt or self-signed)
# - Secure configuration with proper file permissions
# - Automatic service management and monitoring
# - Firewall configuration
# - Comprehensive error handling and logging
# 
# Requirements:
# - Ubuntu 20.04 or later
# - Root privileges
# - Public domain (for Let's Encrypt certificates)
# 
# Usage:
#   sudo ./minio-server-setup.sh
# 
# For more information, visit:
#   https://github.com/devserge/minio-server-setup
# 
# Copyright (c) 2025 Serge Huijsen
# =============================================================================

# Colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Clear the terminal
clear

# Show intro
echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                                                                ║${NC}"
echo -e "${BLUE}║${GREEN}               MinIO Server Setup Automation Script              ${BLUE}║${NC}"
echo -e "${BLUE}║                                                                ║${NC}"
echo -e "${BLUE}║${CYAN}                    Created by Serge Huijsen                        ${BLUE}║${NC}"
echo -e "${BLUE}║${CYAN}                     CEO of CodeIQ (devserge)                      ${BLUE}║${NC}"
echo -e "${BLUE}║                                                                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo
echo -e "${CYAN}This script will guide you through setting up:${NC}"
echo -e "  ${YELLOW}•${NC} MinIO Object Storage Server"
echo -e "  ${YELLOW}•${NC} Nginx as a reverse proxy"
echo -e "  ${YELLOW}•${NC} SSL certificates using Let's Encrypt"
echo
echo -e "${PURPLE}Features:${NC}"
echo -e "  ${YELLOW}→${NC} Interactive setup with user-friendly prompts"
echo -e "  ${YELLOW}→${NC} Automatic SSL certificate management"
echo -e "  ${YELLOW}→${NC} Secure configuration with proper permissions"
echo -e "  ${YELLOW}→${NC} Comprehensive error handling and logging"
echo -e "  ${YELLOW}→${NC} Automatic service management"
echo -e "  ${YELLOW}→${NC} Firewall configuration"
echo
echo -e "${PURPLE}Requirements:${NC}"
echo -e "  ${YELLOW}•${NC} Ubuntu 20.04 or later"
echo -e "  ${YELLOW}•${NC} Root privileges"
echo -e "  ${YELLOW}•${NC} Public domain (for Let's Encrypt)"
echo
echo -e "${PURPLE}For more information, visit:${NC}"
echo -e "${CYAN}https://github.com/devserge/minio-server-setup${NC}"
echo
echo -e "${PURPLE}Copyright (c) 2024 Serge Huijsen${NC}"
echo -e "${PURPLE}License: MIT${NC}"
echo
read -p "Press Enter to continue or Ctrl+C to abort..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}ERROR: This script must be run as root or with sudo privileges.${NC}"
  exit 1
fi

# Check for Ubuntu 20.04 or later
if ! grep -q 'Ubuntu' /etc/os-release || [ "$(grep -oP '(?<=VERSION_ID=").*(?=")' /etc/os-release | cut -d. -f1)" -lt 20 ]; then
  echo -e "${YELLOW}WARNING: This script was designed for Ubuntu 20.04 or later.${NC}"
  echo -e "${YELLOW}The script may not work correctly on your system.${NC}"
  read -p "Do you want to continue anyway? (y/n): " continue_anyway
  if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
    echo -e "${RED}Installation aborted.${NC}"
    exit 1
  fi
fi

# Function to get user input with validation
get_input() {
  local prompt="$1"
  local default="$2"
  local var_name="$3"
  local input

  if [ -n "$default" ]; then
    prompt="$prompt [$default]"
  fi

  while true; do
    read -p "$prompt: " input
    input="${input:-$default}"
    
    if [ -n "$input" ]; then
      eval "$var_name='$input'"
      break
    else
      echo -e "${RED}Please provide a valid input.${NC}"
    fi
  done
}

# Function to get password input with validation
get_password() {
  local prompt="$1"
  local var_name="$2"
  local password password_confirm
  
  while true; do
    read -s -p "$prompt: " password
    echo
    if [ -z "$password" ]; then
      echo -e "${RED}Password cannot be empty.${NC}"
      continue
    fi
    
    read -s -p "Confirm password: " password_confirm
    echo
    
    if [ "$password" = "$password_confirm" ]; then
      eval "$var_name='$password'"
      break
    else
      echo -e "${RED}Passwords do not match. Please try again.${NC}"
    fi
  done
}

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Function to check and install packages
install_package() {
  for pkg in "$@"; do
    if ! dpkg -l | grep -q "^ii  $pkg "; then
      echo -e "${YELLOW}Installing $pkg...${NC}"
      apt-get install -y "$pkg" > /dev/null 2>&1
      if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to install $pkg. Please check your internet connection and try again.${NC}"
        exit 1
      fi
      echo -e "${GREEN}✓ $pkg installed${NC}"
    else
      echo -e "${GREEN}✓ $pkg is already installed${NC}"
    fi
  done
}

# Function to get the latest MinIO server .deb package
get_latest_minio_server() {
  echo -e "${BLUE}Fetching the latest MinIO server package...${NC}"
  
  # Get the latest MinIO server package URL
  LATEST_URL=$(curl -s https://dl.min.io/server/minio/release/linux-amd64/ | grep -o 'href="[^"]*\.deb"' | grep -v archive | head -1 | cut -d'"' -f2)
  
  if [ -z "$LATEST_URL" ]; then
    echo -e "${YELLOW}Could not determine the latest version. Trying archive directory...${NC}"
    LATEST_URL=$(curl -s https://dl.min.io/server/minio/release/linux-amd64/archive/ | grep -o 'href="[^"]*\.deb"' | tail -1 | cut -d'"' -f2)
  fi
  
  if [ -z "$LATEST_URL" ]; then
    echo -e "${RED}Failed to find the latest MinIO server package. Using a hardcoded URL.${NC}"
    MINIO_SERVER_URL="https://dl.min.io/server/minio/release/linux-amd64/archive/minio_20250312180418.0.0_amd64.deb"
  else
    if [[ "$LATEST_URL" == /* ]]; then
      MINIO_SERVER_URL="https://dl.min.io$LATEST_URL"
    else
      MINIO_SERVER_URL="https://dl.min.io/server/minio/release/linux-amd64/$LATEST_URL"
    fi
  fi
  
  echo -e "${GREEN}Latest MinIO server package URL: $MINIO_SERVER_URL${NC}"
}

# Function to get the latest MinIO client .deb package
get_latest_minio_client() {
  echo -e "${BLUE}Fetching the latest MinIO client package...${NC}"
  
  # Get the latest MinIO client package URL
  LATEST_URL=$(curl -s https://dl.min.io/client/mc/release/linux-amd64/ | grep -o 'href="[^"]*\.deb"' | grep -v archive | head -1 | cut -d'"' -f2)
  
  if [ -z "$LATEST_URL" ]; then
    echo -e "${YELLOW}Could not determine the latest version. Trying archive directory...${NC}"
    LATEST_URL=$(curl -s https://dl.min.io/client/mc/release/linux-amd64/archive/ | grep -o 'href="[^"]*\.deb"' | tail -1 | cut -d'"' -f2)
  fi
  
  if [ -z "$LATEST_URL" ]; then
    echo -e "${RED}Failed to find the latest MinIO client package. Using a hardcoded URL.${NC}"
    MINIO_CLIENT_URL="https://dl.min.io/client/mc/release/linux-amd64/archive/mcli_20250310022123.0.0_amd64.deb"
  else
    if [[ "$LATEST_URL" == /* ]]; then
      MINIO_CLIENT_URL="https://dl.min.io$LATEST_URL"
    else
      MINIO_CLIENT_URL="https://dl.min.io/client/mc/release/linux-amd64/$LATEST_URL"
    fi
  fi
  
  echo -e "${GREEN}Latest MinIO client package URL: $MINIO_CLIENT_URL${NC}"
}

# Function to check if MinIO server is installed
check_minio_server_installed() {
    if dpkg -l | grep -q "^ii  minio "; then
        return 0
    fi
    return 1
}

# Function to check if MinIO client is installed
check_minio_client_installed() {
    if dpkg -l | grep -q "^ii  mcli "; then
        return 0
    fi
    return 1
}

# Function to check for existing SSL certificates
check_existing_certificates() {
    local domain="$1"
    local cert_dir="$2"
    
    # Check for Let's Encrypt certificates
    if [ -d "/etc/letsencrypt/live/$domain" ]; then
        echo -e "${GREEN}Found existing Let's Encrypt certificates for $domain${NC}"
        return 0
    fi
    
    # Check for existing certificates in MinIO cert directory
    if [ -f "$cert_dir/public.crt" ] && [ -f "$cert_dir/private.key" ]; then
        echo -e "${GREEN}Found existing SSL certificates in $cert_dir${NC}"
        return 0
    fi
    
    return 1
}

# Function to handle SSL certificate setup
setup_ssl_certificates() {
    local domain="$1"
    local email="$2"
    local cert_dir="$3"
    local ssl_type="$4"
    
    if check_existing_certificates "$domain" "$cert_dir"; then
        echo -e "\n${YELLOW}Existing SSL certificates found.${NC}"
        echo -e "1) Use existing certificates"
        echo -e "2) Request new certificates (Note: Let's Encrypt has rate limits)"
        read -p "Choose an option [1-2]: " cert_option
        
        case $cert_option in
            2)
                echo -e "${YELLOW}Proceeding with new certificate request...${NC}"
                ;;
            *)
                echo -e "${GREEN}Using existing certificates...${NC}"
                return 0
                ;;
        esac
    fi
    
    if [ "$ssl_type" = "letsencrypt" ]; then
        # Ensure Nginx is stopped before obtaining certificates
        systemctl stop nginx
        
        echo -e "${YELLOW}Obtaining Let's Encrypt certificate for $domain...${NC}"
        certbot certonly --standalone --agree-tos --email "$email" -d "$domain" --non-interactive
        
        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed to obtain Let's Encrypt certificate. Please check your domain and internet connection.${NC}"
            echo -e "${YELLOW}Falling back to self-signed certificate...${NC}"
            ssl_type="self-signed"
        else
            echo -e "${GREEN}✓ Let's Encrypt certificate obtained${NC}"
            
            # Copy Let's Encrypt certificates to MinIO cert directory
            cp /etc/letsencrypt/live/"$domain"/fullchain.pem "$cert_dir/public.crt"
            cp /etc/letsencrypt/live/"$domain"/privkey.pem "$cert_dir/private.key"
            
            # Add a cron job to renew Let's Encrypt certificates
            echo -e "${YELLOW}Setting up auto-renewal for Let's Encrypt certificates...${NC}"
            (crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet && systemctl restart nginx && systemctl restart minio") | crontab -
            echo -e "${GREEN}✓ Certificate auto-renewal configured${NC}"
        fi
    fi
    
    if [ "$ssl_type" = "self-signed" ]; then
        echo -e "${YELLOW}Generating self-signed certificate...${NC}"
        
        # Generate parameters for the certificate
        CERT_PARAMS="/C=US/ST=State/L=City/O=Organization/CN=$domain"
        
        # Generate a self-signed certificate
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout "$cert_dir/private.key" -out "$cert_dir/public.crt" \
            -subj "$CERT_PARAMS" > /dev/null 2>&1
        
        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed to generate self-signed certificate.${NC}"
            exit 1
        fi
        echo -e "${GREEN}✓ Self-signed certificate generated${NC}"
    fi
    
    # Set ownership of certificates
    chown minio-user:minio-user "$cert_dir/private.key" "$cert_dir/public.crt"
    chmod 600 "$cert_dir/private.key" "$cert_dir/public.crt"
    echo -e "${GREEN}✓ Certificate permissions set${NC}"
}

# Function to validate MinIO credentials
validate_minio_credentials() {
    local username="$1"
    local password="$2"
    local valid=true
    
    # Check username length (minimum 3 characters)
    if [ ${#username} -lt 3 ]; then
        echo -e "${RED}Error: MinIO admin username must be at least 3 characters long${NC}"
        valid=false
    fi
    
    # Check password length (minimum 8 characters)
    if [ ${#password} -lt 8 ]; then
        echo -e "${RED}Error: MinIO admin password must be at least 8 characters long${NC}"
        valid=false
    fi
    
    # Check for special characters in username
    if [[ "$username" =~ [^a-zA-Z0-9_-] ]]; then
        echo -e "${RED}Error: MinIO admin username can only contain letters, numbers, underscores, and hyphens${NC}"
        valid=false
    fi
    
    # Check for spaces in credentials
    if [[ "$username" =~ [[:space:]] ]] || [[ "$password" =~ [[:space:]] ]]; then
        echo -e "${RED}Error: MinIO credentials cannot contain spaces${NC}"
        valid=false
    fi
    
    if [ "$valid" = false ]; then
        return 1
    fi
    
    return 0
}

# Function to check if a port is in use
check_port_in_use() {
    local port="$1"
    if lsof -i :$port > /dev/null 2>&1; then
        return 0
    fi
    return 1
}

# Function to kill process using a port
kill_port_process() {
    local port="$1"
    local pid=$(lsof -ti :$port)
    if [ ! -z "$pid" ]; then
        echo -e "${YELLOW}Killing process using port $port (PID: $pid)...${NC}"
        kill -9 $pid
        sleep 2
        if check_port_in_use "$port"; then
            echo -e "${RED}Failed to kill process on port $port${NC}"
            return 1
        fi
        echo -e "${GREEN}✓ Process killed${NC}"
    fi
    return 0
}

# Function to clean up existing MinIO installation
cleanup_minio() {
    echo -e "\n${BLUE}=== Cleaning Up Existing MinIO Installation ===${NC}"
    
    # Stop services
    echo -e "${YELLOW}Stopping existing services...${NC}"
    systemctl stop minio nginx
    
    # Kill any processes using MinIO ports
    for port in 9000 9001; do
        if check_port_in_use "$port"; then
            kill_port_process "$port"
        fi
    done
    
    # Remove existing MinIO files
    echo -e "${YELLOW}Removing existing MinIO files...${NC}"
    rm -f /etc/systemd/system/minio.service
    rm -f /lib/systemd/system/minio.service
    rm -f /etc/default/minio
    rm -f /etc/minio/config.env
    rm -rf /etc/minio/certs/*
    
    # Remove MinIO package
    if check_minio_server_installed; then
        echo -e "${YELLOW}Removing MinIO package...${NC}"
        apt-get remove -y minio
        apt-get autoremove -y
    fi
    
    # Remove MinIO client if installed
    if check_minio_client_installed; then
        echo -e "${YELLOW}Removing MinIO client...${NC}"
        apt-get remove -y mcli
        apt-get autoremove -y
    fi
    
    # Clean up Nginx configuration
    echo -e "${YELLOW}Cleaning up Nginx configuration...${NC}"
    rm -f /etc/nginx/sites-enabled/minio
    rm -f /etc/nginx/sites-available/minio
    
    # Reload systemd
    systemctl daemon-reload
    
    echo -e "${GREEN}✓ Cleanup completed${NC}"
}

# Function to check for existing installation
check_existing_installation() {
    local has_existing=false
    
    # Check for MinIO service
    if systemctl list-unit-files | grep -q "minio.service"; then
        has_existing=true
    fi
    
    # Check for MinIO ports in use
    if check_port_in_use 9000 || check_port_in_use 9001; then
        has_existing=true
    fi
    
    # Check for MinIO files
    if [ -f "/etc/default/minio" ] || [ -f "/etc/systemd/system/minio.service" ] || \
       [ -f "/lib/systemd/system/minio.service" ] || [ -d "/etc/minio" ]; then
        has_existing=true
    fi
    
    if [ "$has_existing" = true ]; then
        echo -e "${YELLOW}Existing MinIO installation detected.${NC}"
        echo -e "1) Clean up existing installation and start fresh"
        echo -e "2) Exit script"
        read -p "Choose an option [1-2]: " cleanup_option
        
        case $cleanup_option in
            1)
                cleanup_minio
                return 0
                ;;
            *)
                echo -e "${RED}Installation aborted.${NC}"
                exit 1
                ;;
        esac
    fi
    
    return 0
}

# Collect user inputs for setup
echo -e "\n${BLUE}=== Configuration Settings ===${NC}"

# Get domain name
get_input "Enter your domain name for MinIO (e.g., minio.example.com)" "" DOMAIN_NAME

# User can choose between self-signed certificate and Let's Encrypt
echo -e "\n${CYAN}SSL Certificate Options:${NC}"
echo "1) Let's Encrypt (recommended for production, requires a public domain)"
echo "2) Self-signed certificate (for testing or internal use)"
read -p "Select SSL option [1-2]: " SSL_OPTION

case $SSL_OPTION in
  1)
    SSL_TYPE="letsencrypt"
    echo -e "${GREEN}Let's Encrypt certificate will be used.${NC}"
    echo -e "${YELLOW}NOTE: This requires that your domain is publicly accessible and points to this server.${NC}"
    ;;
  2)
    SSL_TYPE="self-signed"
    echo -e "${GREEN}Self-signed certificate will be generated.${NC}"
    ;;
  *)
    echo -e "${RED}Invalid option. Defaulting to self-signed certificate.${NC}"
    SSL_TYPE="self-signed"
    ;;
esac

# Get email for Let's Encrypt
if [ "$SSL_TYPE" = "letsencrypt" ]; then
  get_input "Enter your email address for Let's Encrypt notifications" "" EMAIL
fi

# Get MinIO credentials
echo -e "\n${CYAN}MinIO Admin Credentials:${NC}"
while true; do
    get_input "Enter MinIO admin username" "minioadmin" MINIO_ROOT_USER
    get_password "Enter MinIO admin password" MINIO_ROOT_PASSWORD
    
    if validate_minio_credentials "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD"; then
        break
    else
        echo -e "${YELLOW}Please try again with valid credentials.${NC}"
    fi
done

# Ask for data directory
get_input "Enter the data directory for MinIO storage" "/mnt/data" DATA_DIR

# Create the data directory if it doesn't exist
if [ ! -d "$DATA_DIR" ]; then
  echo -e "${YELLOW}Data directory $DATA_DIR does not exist. Creating it...${NC}"
  mkdir -p "$DATA_DIR"
  if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to create data directory. Please check permissions and try again.${NC}"
    exit 1
  fi
  echo -e "${GREEN}✓ Data directory created${NC}"
fi

# Update system packages
echo -e "\n${BLUE}=== Updating System Packages ===${NC}"
apt-get update > /dev/null
if [ $? -ne 0 ]; then
  echo -e "${RED}Failed to update package lists. Please check your internet connection and try again.${NC}"
  exit 1
fi
echo -e "${GREEN}✓ Package lists updated${NC}"

# Install required packages
echo -e "\n${BLUE}=== Installing Required Packages ===${NC}"
install_package curl wget gnupg2 software-properties-common apt-transport-https ca-certificates

# Install Nginx
echo -e "\n${BLUE}=== Installing Nginx ===${NC}"
install_package nginx

# Install Certbot if Let's Encrypt is selected
if [ "$SSL_TYPE" = "letsencrypt" ]; then
  echo -e "\n${BLUE}=== Installing Certbot for Let's Encrypt ===${NC}"
  
  # Check if Certbot is already installed via snap
  if command_exists certbot; then
    echo -e "${GREEN}✓ Certbot is already installed${NC}"
  else
    # Install Certbot using snap
    install_package snapd
    snap install core > /dev/null 2>&1
    snap refresh core > /dev/null 2>&1
    snap install --classic certbot > /dev/null 2>&1
    ln -sf /snap/bin/certbot /usr/bin/certbot
    echo -e "${GREEN}✓ Certbot installed${NC}"
  fi
fi

# Download and install MinIO
echo -e "\n${BLUE}=== Installing MinIO Server ===${NC}"
if check_minio_server_installed; then
    echo -e "${GREEN}✓ MinIO server is already installed${NC}"
else
    get_latest_minio_server
    
    echo -e "${YELLOW}Downloading MinIO server...${NC}"
    wget "$MINIO_SERVER_URL" -O minio.deb -q --show-progress
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to download MinIO server. Please check your internet connection and try again.${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ MinIO server downloaded${NC}"
    
    echo -e "${YELLOW}Installing MinIO server...${NC}"
    dpkg -i minio.deb > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to install MinIO server. Please check the package and try again.${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ MinIO server installed${NC}"
    rm minio.deb
fi

# Ask if user wants to install MinIO Client
echo -e "\n${CYAN}MinIO Client Installation:${NC}"
echo -e "${YELLOW}The MinIO Client (mc) is a command-line tool that provides convenient ways to interact with MinIO servers.${NC}"
echo -e "${YELLOW}It's optional but recommended for server management.${NC}"
read -p "Would you like to install the MinIO Client? (y/n): " install_client

if [[ "$install_client" =~ ^[Yy]$ ]]; then
    echo -e "\n${BLUE}=== Installing MinIO Client ===${NC}"
    if check_minio_client_installed; then
        echo -e "${GREEN}✓ MinIO client is already installed${NC}"
    else
        get_latest_minio_client
        
        echo -e "${YELLOW}Downloading MinIO client...${NC}"
        wget "$MINIO_CLIENT_URL" -O mcli.deb -q --show-progress
        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed to download MinIO client. Please check your internet connection and try again.${NC}"
            exit 1
        fi
        echo -e "${GREEN}✓ MinIO client downloaded${NC}"
        
        echo -e "${YELLOW}Installing MinIO client...${NC}"
        dpkg -i mcli.deb > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed to install MinIO client. Please check the package and try again.${NC}"
            exit 1
        fi
        echo -e "${GREEN}✓ MinIO client installed${NC}"
        rm mcli.deb
    fi
else
    echo -e "${YELLOW}Skipping MinIO client installation.${NC}"
    echo -e "${CYAN}Note: You can install the client later using:${NC}"
    echo -e "${PURPLE}wget https://dl.min.io/client/mc/release/linux-amd64/mc && chmod +x mc && sudo mv mc /usr/local/bin/${NC}"
fi

# Create MinIO user and group
echo -e "\n${BLUE}=== Setting Up MinIO User and Group ===${NC}"
if ! grep -q "^minio-user:" /etc/group; then
  groupadd -r minio-user
  echo -e "${GREEN}✓ MinIO group created${NC}"
else
  echo -e "${GREEN}✓ MinIO group already exists${NC}"
fi

if ! id minio-user >/dev/null 2>&1; then
  useradd -M -r -g minio-user minio-user
  echo -e "${GREEN}✓ MinIO user created${NC}"
else
  echo -e "${GREEN}✓ MinIO user already exists${NC}"
fi

# Set ownership of data directory
chown -R minio-user:minio-user "$DATA_DIR"
echo -e "${GREEN}✓ Data directory ownership set${NC}"

# Create MinIO configuration directory
CERT_DIR="/etc/minio/certs"
mkdir -p "$CERT_DIR"
chown -R minio-user:minio-user /etc/minio
echo -e "${GREEN}✓ MinIO configuration directory created${NC}"

# Replace the SSL certificate setup section with the new function call
echo -e "\n${BLUE}=== Setting Up SSL Certificates ===${NC}"
setup_ssl_certificates "$DOMAIN_NAME" "$EMAIL" "$CERT_DIR" "$SSL_TYPE"

# Configure MinIO environment
echo -e "\n${BLUE}=== Configuring MinIO Environment ===${NC}"

echo -e "${YELLOW}Creating MinIO configuration file...${NC}"
cat > /etc/default/minio << EOF
MINIO_VOLUMES="$DATA_DIR"
MINIO_OPTS="--certs-dir $CERT_DIR --console-address :9001"
MINIO_ROOT_USER="$MINIO_ROOT_USER"
MINIO_ROOT_PASSWORD="$MINIO_ROOT_PASSWORD"
EOF
echo -e "${GREEN}✓ MinIO configuration file created${NC}"

# Function to check if Nginx is running
check_nginx_running() {
    if systemctl is-active --quiet nginx; then
        return 0
    fi
    return 1
}

# Function to handle Nginx configuration
handle_nginx_config() {
    echo -e "\n${BLUE}=== Configuring Nginx ===${NC}"
    
    # Check if Nginx is already running
    if check_nginx_running; then
        echo -e "${YELLOW}Nginx is already running. Checking configuration...${NC}"
        
        # Test Nginx configuration
        if nginx -t; then
            echo -e "${GREEN}✓ Nginx configuration is valid${NC}"
            echo -e "${YELLOW}Reloading Nginx configuration...${NC}"
            systemctl reload nginx
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✓ Nginx configuration reloaded successfully${NC}"
                return 0
            else
                echo -e "${RED}Failed to reload Nginx configuration${NC}"
                return 1
            fi
        else
            echo -e "${RED}Invalid Nginx configuration. Please check the configuration files.${NC}"
            return 1
        fi
    else
        # If Nginx is not running, start it
        echo -e "${YELLOW}Starting Nginx...${NC}"
        systemctl enable nginx
        systemctl start nginx
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Nginx started successfully${NC}"
            return 0
        else
            echo -e "${RED}Failed to start Nginx. Checking logs...${NC}"
            journalctl -u nginx -n 50 | cat
            return 1
        fi
    fi
}

# Replace the Nginx configuration section with:
echo -e "\n${BLUE}=== Configuring Nginx ===${NC}"

# Create Nginx configuration
echo -e "${YELLOW}Creating Nginx configuration...${NC}"
cat > /etc/nginx/sites-available/minio << EOF
server {
    listen 80;
    server_name $DOMAIN_NAME;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl;
    server_name $DOMAIN_NAME;

    ssl_certificate $CERT_DIR/public.crt;
    ssl_certificate_key $CERT_DIR/private.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    # MinIO Console
    location / {
        proxy_pass http://localhost:9001;
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-NginX-Proxy true;
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
        proxy_read_timeout 300;
        proxy_buffering off;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # MinIO API
    location /api {
        proxy_pass http://localhost:9000;
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-NginX-Proxy true;
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
        proxy_read_timeout 300;
        proxy_buffering off;
    }
}
EOF

# Enable the site
echo -e "${YELLOW}Enabling Nginx site...${NC}"
ln -sf /etc/nginx/sites-available/minio /etc/nginx/sites-enabled/

# Handle Nginx configuration and service
if ! handle_nginx_config; then
    echo -e "${RED}Failed to configure Nginx. Please check the configuration and try again.${NC}"
    exit 1
fi

# Configure firewall if UFW is installed
if command_exists ufw; then
  echo -e "\n${BLUE}=== Configuring Firewall ===${NC}"
  echo -e "${YELLOW}Opening required ports...${NC}"
  
  ufw allow 22/tcp
  ufw allow 80/tcp
  ufw allow 443/tcp
  ufw allow 9001/tcp
  
  if ! ufw status | grep -q "Status: active"; then
    echo -e "${YELLOW}Enabling firewall...${NC}"
    echo "y" | ufw enable
  fi
  
  echo -e "${GREEN}✓ Firewall configured${NC}"
fi

# Setup complete
echo -e "\n${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${GREEN}                       Setup Complete!                          ${BLUE}║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo
echo -e "${CYAN}Your MinIO server is now set up with the following details:${NC}"
echo -e "${YELLOW}• Domain:${NC} $DOMAIN_NAME"
echo -e "${YELLOW}• MinIO API:${NC} https://$DOMAIN_NAME"
echo -e "${YELLOW}• MinIO Console:${NC} https://$DOMAIN_NAME:9001"
echo -e "${YELLOW}• Admin User:${NC} $MINIO_ROOT_USER"
echo -e "${YELLOW}• Admin Password:${NC} $MINIO_ROOT_PASSWORD"
echo -e "${YELLOW}• Data Directory:${NC} $DATA_DIR"
echo -e "${YELLOW}• Certificate Type:${NC} $SSL_TYPE"
echo

echo -e "${PURPLE}Important Notes:${NC}"
echo -e "  ${YELLOW}•${NC} If you chose Let's Encrypt, certificates will auto-renew every 90 days"
echo -e "  ${YELLOW}•${NC} To check MinIO server status: ${CYAN}systemctl status minio${NC}"
echo -e "  ${YELLOW}•${NC} To check MinIO server logs: ${CYAN}journalctl -u minio${NC}"
echo -e "  ${YELLOW}•${NC} To check Nginx status: ${CYAN}systemctl status nginx${NC}"
echo -e "  ${YELLOW}•${NC} MinIO client is installed - use ${CYAN}mcli${NC} command to manage your server"
echo
echo -e "${GREEN}Thank you for using this setup script!${NC}"
