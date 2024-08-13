#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: tteck (tteckster)
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE

source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies (Patience)"
$STD apt-get install -y curl
$STD apt-get install -y sudo
$STD apt-get install -y mc
$STD apt-get install -y exiftool
$STD apt-get install -y ffmpeg
$STD apt-get install -y libheif1
$STD apt-get install -y libpng-dev
$STD apt-get install -y libjpeg-dev
$STD apt-get install -y libtiff-dev
$STD apt-get install -y imagemagick
$STD apt-get install -y darktable
$STD apt-get install -y rawtherapee
$STD apt-get install -y libvips42
$STD apt-get install -y cifs-utils  # Install CIFS utils for mounting SMB shares

echo 'export PATH=/usr/local:$PATH' >>~/.bashrc
export PATH=/usr/local:$PATH
msg_ok "Installed Dependencies"

# SMB Share Details
SMB_SERVER="192.168.1.100"    # Replace with your SMB server IP
SMB_SHARE="sharedphotos"      # Replace with your SMB share name

# Step 1: Create SMB Credentials File
msg_info "Creating SMB Credentials File"
cat <<EOF >/etc/smbcredentials
username=smbuser            # Replace with your SMB username
password=smbpassword        # Replace with your SMB password
EOF

# Secure the credentials file
chmod 600 /etc/smbcredentials
msg_ok "Created and Secured SMB Credentials File"

# Step 2: Mount the SMB Share
msg_info "Mounting SMB Share"
mkdir -p /opt/photoprism/photos/originals
echo "//$SMB_SERVER/$SMB_SHARE /opt/photoprism/photos/originals cifs credentials=/etc/smbcredentials,iocharset=utf8,vers=3.0 0 0" >> /etc/fstab
mount -a
msg_ok "Mounted SMB Share"

# Step 3: Install PhotoPrism
msg_info "Installing PhotoPrism (Patience)"
mkdir -p /opt/photoprism/{cache,config,photos/import,storage,temp}
wget -q -cO - https://dl.photoprism.app/pkg/linux/amd64.tar.gz | tar -xz -C /opt/photoprism --strip-components=1
if [[ ${PCT_OSTYPE} == "ubuntu" ]]; then 
  wget -q -cO - https://dl.photoprism.app/dist/libheif/libheif-jammy-amd64-v1.17.1.tar.gz | tar -xzf - -C /usr/local --strip-components=1
else
  wget -q -cO - https://dl.photoprism.app/dist/libheif/libheif-bookworm-amd64-v1.17.1.tar.gz | tar -xzf - -C /usr/local --strip-components=1
fi
ldconfig
cat <<EOF >/opt/photoprism/config/.env
PHOTOPRISM_AUTH_MODE='password'
PHOTOPRISM_ADMIN_PASSWORD='changeme'  # Replace with a strong password
PHOTOPRISM_HTTP_HOST='0.0.0.0'
PHOTOPRISM_HTTP_PORT='2342'
PHOTOPRISM_SITE_CAPTION='https://tteck.github.io/Proxmox/'
PHOTOPRISM_STORAGE_PATH='/opt/photoprism/storage'
PHOTOPRISM_ORIGINALS_PATH='/opt/photoprism/photos/originals'
PHOTOPRISM_IMPORT_PATH='/opt/photoprism/photos/import'
EOF
ln -sf /opt/photoprism/bin/photoprism /usr/local/bin/photoprism
msg_ok "Installed PhotoPrism"

# Step 4: Create and Enable PhotoPrism Service
msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/photoprism.service
[Unit]
Description=PhotoPrism service
After=network.target

[Service]
Type=forking
User=root
WorkingDirectory=/opt/photoprism
EnvironmentFile=/opt/photoprism/config/.env
ExecStart=/opt/photoprism/bin/photoprism up -d
ExecStop=/opt/photoprism/bin/photoprism down

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now photoprism
msg_ok "Created Service"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
