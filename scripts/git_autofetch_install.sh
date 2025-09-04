#!/bin/sh

# Color definitions
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "${GREEN}[*] Starting git_autofetch installer...${NC}"

SCRIPTS_DIR=./scripts

install_script() {
    src="$1"
    dst="$2"
    if [ -f "$src" ]; then
        cp "$src" "$dst"
        chmod +x "$dst"
        echo "${GREEN}[*] Installed $src -> $dst${NC}"
    else
        echo "${RED}[!] Source $src missing, skipping install for $dst${NC}"
        exit 1
    fi
}

# === git_autofetch command ===
if [ ! -f /usr/local/bin/git_autofetch.sh ]; then
    install_script $SCRIPTS_DIR/git_autofetch.sh /usr/local/bin/git_autofetch.sh
else
    echo "${YELLOW}[*] git_autofetch.sh command already exists, overwriting${NC}"
    install_script $SCRIPTS_DIR/git_autofetch.sh /usr/local/bin/git_autofetch.sh
fi

# === git-autofetch systemd service ===
SERVICE_FILE="/etc/systemd/system/git-autofetch.service"
if [ ! -f "$SERVICE_FILE" ]; then
    echo "${GREEN}[*] Creating git-autofetch systemd service${NC}"
    cat > "$SERVICE_FILE" <<'EOF'
[Unit]
Description=Auto-fetch Git repositories
After=network.target

[Service]
ExecStart=/usr/local/bin/git_autofetch.sh /root/scripts 5
Restart=always
User=root
WorkingDirectory=/root/scripts

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload systemd and enable the service
    if command -v systemctl >/dev/null 2>&1; then
        systemctl daemon-reload
        systemctl enable git-autofetch.service
        echo "${GREEN}[*] git-autofetch service enabled${NC}"
        
        # Optionally start the service immediately
        echo "${YELLOW}[*] Start the service now? (y/n)${NC}"
        read -r answer
        if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
            systemctl start git-autofetch.service
            echo "${GREEN}[*] git-autofetch service started${NC}"
        fi
    else
        echo "${YELLOW}[*] systemctl not available, service created but not enabled${NC}"
    fi
else
    echo "${YELLOW}[*] git-autofetch service already exists, skipping${NC}"
fi

echo "${GREEN}[*] git_autofetch installation complete.${NC}"
echo "${YELLOW}[*] Check service status with: systemctl status git-autofetch${NC}"
echo "${YELLOW}[*] View logs with: tail -f /var/log/git_autofetch.log${NC}"
