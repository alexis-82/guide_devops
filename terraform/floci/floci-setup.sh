#!/usr/bin/env bash
# floci-setup.sh — prepara una VM Debian 12/13 o Ubuntu 22.04/24.04 per Floci
# Installa: Docker CE + compose plugin, AWS CLI v2, Terraform, jq
# Crea ~/floci con compose.yaml (persistenza hybrid + Docker socket) e avvia Floci.
#
# Uso:  sudo ./floci-setup.sh <utente>     (es. sudo ./floci-setup.sh alessio)

set -euo pipefail

TARGET_USER="${1:-${SUDO_USER:-}}"
[[ $EUID -eq 0 ]] || { echo "Esegui con sudo"; exit 1; }
[[ -n "$TARGET_USER" ]] || { echo "Uso: sudo $0 <utente>"; exit 1; }
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"

. /etc/os-release
DISTRO="$ID"                         # debian | ubuntu
CODENAME="$VERSION_CODENAME"
ARCH_DEB="$(dpkg --print-architecture)"   # amd64 | arm64
ARCH_UNAME="$(uname -m)"                   # x86_64 | aarch64
VM_IP="$(hostname -I | awk '{print $1}')"

log() { echo -e "\n\033[1;34m==> $*\033[0m"; }

log "Pacchetti base"
apt-get update
apt-get install -y ca-certificates curl gnupg unzip jq git lsb-release

log "Docker CE (repo ufficiale)"
install -m 0755 -d /etc/apt/keyrings
curl -fsSL "https://download.docker.com/linux/${DISTRO}/gpg" -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=${ARCH_DEB} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/${DISTRO} ${CODENAME} stable" \
  > /etc/apt/sources.list.d/docker.list
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker
usermod -aG docker "$TARGET_USER"

log "AWS CLI v2"
if ! command -v aws >/dev/null; then
  tmp="$(mktemp -d)"
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-${ARCH_UNAME}.zip" -o "$tmp/awscliv2.zip"
  unzip -q "$tmp/awscliv2.zip" -d "$tmp"
  "$tmp/aws/install"
  rm -rf "$tmp"
fi

log "Terraform (repo HashiCorp)"
curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor --yes -o /etc/apt/keyrings/hashicorp.gpg
echo "deb [arch=${ARCH_DEB} signed-by=/etc/apt/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com ${CODENAME} main" \
  > /etc/apt/sources.list.d/hashicorp.list
apt-get update
apt-get install -y terraform

log "Progetto Floci in ${TARGET_HOME}/floci"
install -d -o "$TARGET_USER" -g "$TARGET_USER" "${TARGET_HOME}/floci/data"
cat > "${TARGET_HOME}/floci/compose.yaml" <<EOF
services:
  floci:
    image: floci/floci:latest
    container_name: floci
    restart: unless-stopped
    user: root                      # richiesto per usare il Docker socket
    ports:
      - "4566:4566"                 # API AWS (+ console su /_floci/ui)
    environment:
      FLOCI_STORAGE_MODE: hybrid    # stato salvato su disco ogni 5s
      FLOCI_STORAGE_PERSISTENT_PATH: /app/data
      FLOCI_BASE_URL: http://${VM_IP}:4566
      FLOCI_DEFAULT_REGION: eu-south-1
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock   # EC2/RDS/Lambda = container veri
      - ./data:/app/data
EOF
chown "$TARGET_USER:$TARGET_USER" "${TARGET_HOME}/floci/compose.yaml"

log "Profilo AWS CLI 'floci' (credenziali fittizie)"
install -d -o "$TARGET_USER" -g "$TARGET_USER" "${TARGET_HOME}/.aws"
cat >> "${TARGET_HOME}/.aws/config" <<EOF

[profile floci]
region = eu-south-1
output = json
endpoint_url = http://localhost:4566
EOF
cat >> "${TARGET_HOME}/.aws/credentials" <<EOF

[floci]
aws_access_key_id = test
aws_secret_access_key = test
EOF
chown -R "$TARGET_USER:$TARGET_USER" "${TARGET_HOME}/.aws"
chmod 600 "${TARGET_HOME}/.aws/credentials"

log "Avvio Floci"
cd "${TARGET_HOME}/floci"
docker compose pull
docker compose up -d
sleep 3
curl -fsS http://localhost:4566/_localstack/health >/dev/null && echo "Floci è su." || echo "Controlla: docker compose logs -f"

cat <<EOF

Fatto. Esci e rientra (o 'newgrp docker') per usare docker senza sudo.

  API:      http://${VM_IP}:4566
  Console:  http://${VM_IP}:4566/_floci/ui
  Test:     aws --profile floci s3 mb s3://prova && aws --profile floci s3 ls
  Log:      cd ~/floci && docker compose logs -f

ATTENZIONE: il container ha accesso al Docker socket (= root sulla VM).
Tieni la VM su rete host-only/NAT o LAN, mai esposta su internet.
EOF
