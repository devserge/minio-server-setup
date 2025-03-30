# MinIO Server Setup Script

A comprehensive, interactive script for setting up a MinIO server with Nginx reverse proxy and SSL certificates.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Features

- 🚀 One-command installation
- 🔒 Automatic SSL certificate management (Let's Encrypt or self-signed)
- 🔄 Nginx reverse proxy configuration
- 🔐 Secure credential management
- 🛡️ Firewall configuration
- 📝 Comprehensive logging and error handling
- 🎯 Interactive setup with user-friendly prompts

## Quick Start

```bash
# Download the script
curl -O https://raw.githubusercontent.com/devserge/minio-server-setup/main/minio-server-setup.sh

# Make it executable
chmod +x minio-server-setup.sh

# Run the script
sudo ./minio-server-setup.sh
```

## Requirements

- Ubuntu 20.04 or later
- Root privileges (sudo)
- Public domain (for Let's Encrypt certificates)

## What's included?

- MinIO Server installation
- Nginx reverse proxy setup
- SSL certificate management (Let's Encrypt or self-signed)
- Firewall configuration
- MinIO client installation (optional)
- Automatic service management
- Comprehensive error handling

## Configuration Options

The script will prompt you for:
- Domain name
- SSL certificate type (Let's Encrypt or self-signed)
- MinIO admin credentials
- Data storage location
- Optional MinIO client installation

## Security Features

- Secure credential validation
- Proper file permissions
- SSL/TLS configuration
- Firewall rules
- Service isolation

## Maintenance

### Checking Service Status
```bash
# Check MinIO status
sudo systemctl status minio

# Check Nginx status
sudo systemctl status nginx
```

### Viewing Logs
```bash
# MinIO logs
sudo journalctl -u minio

# Nginx logs
sudo journalctl -u nginx
```

### Certificate Renewal
If using Let's Encrypt, certificates will auto-renew every 90 days.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Author

- **Serge Huijsen** - [devserge](https://github.com/devserge)
  - CEO of CodeIQ
  - GitHub: https://github.com/devserge
