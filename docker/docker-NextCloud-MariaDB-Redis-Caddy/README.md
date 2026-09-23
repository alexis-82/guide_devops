# Nextcloud con Docker

Guida completa per installare Docker CE minimale e Nextcloud (con MariaDB, Redis e Caddy come reverse proxy HTTPS) su una VM con Ubuntu o Debian.

---

## 1. Installazione Docker CE minimale

### 1.1 Pulizia preventiva

```bash
sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null
sudo apt autoremove -y
```

### 1.2 Dipendenze

```bash
sudo apt update
sudo apt install -y ca-certificates curl gnupg
```

### 1.3 Chiave GPG e repo ufficiale Docker

```bash
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

### 1.4 Installazione pacchetti

```bash
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
```

### 1.5 User nel gruppo docker

```bash
sudo usermod -aG docker $USER
```

**Importante:** disconnettiti dalla SSH e riconnettiti per applicare il nuovo gruppo. Verifica con:

```bash
id
docker run --rm hello-world
```

### 1.6 Log rotation (opzionale ma consigliato)

Crea `/etc/docker/daemon.json`:

```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

Poi:

```bash
sudo systemctl restart docker
```

---

## 2. Configurazione rete Cloud

### 2.1 Iptables sulla VM

Le VM hanno regole iptables restrittive che bloccano tutto tranne SSH. Apri le porte necessarie:

```bash
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 80 -j ACCEPT
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 443 -j ACCEPT
sudo netfilter-persistent save
```

### 2.2 Security List OCI

Fare il port forwarding Cloud → Networking → VCN → Security List, aggiungi ingress rules per:
- TCP 80 da `0.0.0.0/0`
- TCP 443 da `0.0.0.0/0`

---

## 3. Struttura progetto Nextcloud

```bash
mkdir -p ~/nextcloud && cd ~/nextcloud
mkdir -p data db redis caddy/data caddy/config
```

---

## 4. File `.env`

```bash
cat > .env <<'EOF'
MYSQL_ROOT_PASSWORD=cambia_questa_password_root
MYSQL_PASSWORD=cambia_questa_password_nc
MYSQL_DATABASE=nextcloud
MYSQL_USER=nextcloud

NEXTCLOUD_ADMIN_USER=username
NEXTCLOUD_ADMIN_PASSWORD=cambia_questa_admin

NEXTCLOUD_TRUSTED_DOMAINS=dominio.it oppure cloud.dominio.it
EOF

chmod 600 .env
```

---

## 5. `docker-compose.yml`

```yaml
services:
  db:
    image: mariadb:11
    container_name: nc-db
    restart: unless-stopped
    command: --transaction-isolation=READ-COMMITTED --log-bin=binlog --binlog-format=ROW
    volumes:
      - ./db:/var/lib/mysql
    environment:
      - MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
      - MYSQL_PASSWORD=${MYSQL_PASSWORD}
      - MYSQL_DATABASE=${MYSQL_DATABASE}
      - MYSQL_USER=${MYSQL_USER}
    networks:
      - nc-net

  redis:
    image: redis:7-alpine
    container_name: nc-redis
    restart: unless-stopped
    volumes:
      - ./redis:/data
    networks:
      - nc-net

  app:
    image: nextcloud:stable
    container_name: nc-app
    restart: unless-stopped
    volumes:
      - ./data:/var/www/html
    environment:
      - MYSQL_HOST=db
      - MYSQL_DATABASE=${MYSQL_DATABASE}
      - MYSQL_USER=${MYSQL_USER}
      - MYSQL_PASSWORD=${MYSQL_PASSWORD}
      - REDIS_HOST=redis
      - NEXTCLOUD_ADMIN_USER=${NEXTCLOUD_ADMIN_USER}
      - NEXTCLOUD_ADMIN_PASSWORD=${NEXTCLOUD_ADMIN_PASSWORD}
      - NEXTCLOUD_TRUSTED_DOMAINS=${NEXTCLOUD_TRUSTED_DOMAINS}
    depends_on:
      - db
      - redis
    networks:
      - nc-net

  caddy:
    image: caddy:2-alpine
    container_name: nc-caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./caddy/Caddyfile:/etc/caddy/Caddyfile
      - ./caddy/data:/data
      - ./caddy/config:/config
    networks:
      - nc-net

networks:
  nc-net:
    driver: bridge
```

---

## 6. Configurazione Caddy

Crea `caddy/Caddyfile`:

```
cloud.dminio.it {
    reverse_proxy app:80

    header Strict-Transport-Security "max-age=31536000;"

    # Redirect richiesti da Nextcloud per CalDAV/CardDAV
    redir /.well-known/carddav /remote.php/dav 301
    redir /.well-known/caldav /remote.php/dav 301
}
```

**Prerequisito:** il record DNS di `cloud.dominio.it` deve puntare all'IP pubblico della VM. Caddy si prende il certificato Let's Encrypt automaticamente al primo avvio.

---

## 7. Avvio dello stack

```bash
cd ~/nextcloud
docker compose up -d
docker compose logs -f app
```

La prima partenza impiega 1-2 minuti per lo script di install di Nextcloud.

---

## 8. Configurazione post-install (fondamentale con proxy HTTPS)

Senza questi parametri Nextcloud, dietro un reverse proxy HTTPS, ha problemi al login (rimane su "accesso in corso" e serve un refresh manuale).

### 8.1 Parametri overwrite per il proxy

```bash
docker compose exec -u www-data app php occ config:system:set overwritehost --value="cloud.dominio.it"
docker compose exec -u www-data app php occ config:system:set overwriteprotocol --value="https"
docker compose exec -u www-data app php occ config:system:set overwrite.cli.url --value="https://cloud.dominio.it"
```

### 8.2 Trusted proxies

Trova la subnet della rete Docker:

```bash
docker network inspect nextcloud_nc-net | grep Subnet
```

Poi (adatta la subnet a quella che ti mostra):

```bash
docker compose exec -u www-data app php occ config:system:set trusted_proxies 0 --value="172.18.0.0/16"
```

### 8.3 Sistemazioni varie

```bash
docker compose exec -u www-data app php occ config:system:set default_phone_region --value="IT"
docker compose exec -u www-data app php occ maintenance:repair --include-expensive
```

### 8.4 Restart

```bash
docker compose restart app
```

### 8.5 Verifica

```bash
docker compose exec -u www-data app php occ config:list system | grep -E "overwrite|trusted"
```

---

## 9. Cron per i job in background

Nextcloud gira meglio con cron reale invece di AJAX.

```bash
(crontab -l 2>/dev/null; echo "*/5 * * * * docker compose -f $HOME/nextcloud/docker-compose.yml exec -T -u www-data app php cron.php") | crontab -
```

Poi da Nextcloud → Impostazioni → Amministrazione → Impostazioni di base → seleziona **Cron**.

---

## 10. Comandi utili di gestione

```bash
# Stato container
docker compose ps

# Log in tempo reale
docker compose logs -f app

# Restart singolo servizio
docker compose restart app

# Stop tutto
docker compose down

# Update immagini
docker compose pull
docker compose up -d

# Accesso a occ (CLI Nextcloud)
docker compose exec -u www-data app php occ <comando>

# Modalità manutenzione
docker compose exec -u www-data app php occ maintenance:mode --on
docker compose exec -u www-data app php occ maintenance:mode --off
```

---

## 11. Backup

I dati sono tutti in bind mount sotto `~/nextcloud/`, quindi backup semplice via `rsync` o `rclone`.

Esempio con `rsync` verso storage esterno:

```bash
# Metti in maintenance prima del backup del DB
docker compose exec -u www-data app php occ maintenance:mode --on

rsync -avz --delete ~/nextcloud/ user@backup-host:/path/backup/nextcloud/

docker compose exec -u www-data app php occ maintenance:mode --off
```

---

## Note

- Le richieste `service-account.json`, `gcp.json` e simili nei log sono bot scanner, si possono ignorare.
- Se cambi dominio, aggiorna sia `trusted_domains` sia `overwritehost` / `overwrite.cli.url` sia il `Caddyfile`.
- L'immagine `nextcloud:stable` è multi-arch e gira nativa su aarch64 (ARM).
