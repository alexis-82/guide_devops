# Sito web statico con Nginx + Caddy TLS su AWS EC2 (Docker)

Guida standalone per pubblicare un sito web statico (o SPA React/Vue/Vite già buildata) su un'istanza AWS EC2 con Docker, Nginx come web server e Caddy come reverse proxy HTTPS con certificati Let's Encrypt automatici.

**Scenario:**
- Cloud: AWS EC2
- OS: Ubuntu 22.04/24.04 LTS (AMI ufficiale Canonical) o Amazon Linux 2023
- Istanza: `t3.micro` / `t4g.small` (ARM Graviton) o superiore
- Sito: contenuti statici (HTML/CSS/JS) o build di framework (React/Vue/Svelte/Astro)
- Dominio: `esempio.it` (sostituisci con il tuo)

---

## Indice

- [1. Preparazione istanza EC2](#1-preparazione-istanza-ec2)
   - [1.1 Lancio istanza](#11-lancio-istanza)
   - [1.2 Security Group](#12-security-group)
   - [1.3 Accesso SSH](#13-accesso-ssh)
   - [1.4 Update sistema](#14-update-sistema)
- [2. Installazione Docker](#2-installazione-docker)
   - [2.1 Repo ufficiale Docker (Ubuntu)](#21-repo-ufficiale-docker-ubuntu)
   - [2.2 User nel gruppo docker](#22-user-nel-gruppo-docker)
   - [2.3 (Opzionale) Log rotation Docker](#23-opzionale-log-rotation-docker)
   - [Nota per Amazon Linux 2023](#nota-per-amazon-linux-2023)
- [3. DNS](#3-dns)
   - [3.1 Configura record A](#31-configura-record-a)
   - [3.2 Route 53 (se usi AWS per il DNS)](#32-route-53-se-usi-aws-per-il-dns)
- [4. Struttura progetto](#4-struttura-progetto)
- [5. Contenuto del sito](#5-contenuto-del-sito)
- [6. Configurazione Nginx](#6-configurazione-nginx)
   - [Variante per SPA (React Router, Vue Router, ecc.)](#variante-per-spa-react-router-vue-router-ecc)
- [7. Configurazione Caddy](#7-configurazione-caddy)
   - [Variante con redirect www → root](#variante-con-redirect-www--root)
   - [Variante multi-dominio](#variante-multi-dominio)
- [8. `docker-compose.yml`](#8-docker-composeyml)
- [9. Avvio](#9-avvio)
- [10. Comandi utili](#10-comandi-utili)
- [11. Aggiornare i contenuti](#11-aggiornare-i-contenuti)
- [12. Backup](#12-backup)
   - [Opzione A: backup locale su S3](#opzione-a-backup-locale-su-s3)
   - [Opzione B: EBS Snapshot](#opzione-b-ebs-snapshot)
- [13. Troubleshooting](#13-troubleshooting)
   - [Caddy non prende il certificato](#caddy-non-prende-il-certificato)
   - [502 Bad Gateway](#502-bad-gateway)
   - [404 su route SPA al refresh](#404-su-route-spa-al-refresh)
   - [Il sito è raggiungibile da `curl` sulla VM ma non da internet](#il-sito-è-raggiungibile-da-curl-sulla-vm-ma-non-da-internet)
   - [Timeout SSH dopo un restart](#timeout-ssh-dopo-un-restart)
   - [Certificato scaduto](#certificato-scaduto)
- [14. Considerazioni AWS specifiche](#14-considerazioni-aws-specifiche)
   - [Costi da tenere d'occhio](#costi-da-tenere-docchio)
   - [CloudWatch / metriche](#cloudwatch--metriche)
   - [Alternativa: S3 + CloudFront](#alternativa-s3--cloudfront)
   - [Sicurezza](#sicurezza)
   - [Auto-restart al reboot](#auto-restart-al-reboot)
- [15. Estensioni possibili](#15-estensioni-possibili)
   - [Basic auth](#basic-auth)
   - [Redirect HTTP → HTTPS](#redirect-http--https)
   - [CI/CD con GitHub Actions](#cicd-con-github-actions)
   - [Aggiungere backend Node/Python](#aggiungere-backend-nodepython)
- [Note](#note)

---

## 1. Preparazione istanza EC2

### 1.1 Lancio istanza

Dalla console EC2:

- **AMI:** Ubuntu Server 24.04 LTS (o Amazon Linux 2023 o Debian)
- **Tipo:** `t3.micro` (x86) o `t4g.small` (ARM Graviton, più conveniente)
- **Key pair:** genera o riusa una `.pem` per SSH
- **Storage:** 8-20 GB gp3 (SSD)
- **Elastic IP:** allocane uno e associalo all'istanza — fondamentale per avere un IP pubblico stabile (senza EIP l'IP cambia a ogni stop/start e ti tocca risistemare il DNS ogni volta)

### 1.2 Security Group

Crea/modifica il Security Group associato con queste **inbound rules**:

| Type | Protocol | Port | Source | Description |
|------|----------|------|--------|-------------|
| SSH | TCP | 22 | Il tuo IP (`X.X.X.X/32`) | Accesso amministrativo |
| HTTP | TCP | 80 | `0.0.0.0/0` | Let's Encrypt HTTP-01 + redirect |
| HTTPS | TCP | 443 | `0.0.0.0/0` | Traffico web |

**Non** aprire SSH su `0.0.0.0/0`. Usa il tuo IP fisso o una VPN.

Outbound: lascia default (all traffic allowed).

### 1.3 Accesso SSH

```bash
chmod 400 ~/Downloads/mia-chiave.pem
ssh -i ~/Downloads/mia-chiave.pem ubuntu@ELASTIC_IP
```

Su Amazon Linux l'utente è `ec2-user` invece di `ubuntu`.

### 1.4 Update sistema

```bash
sudo apt update && sudo apt upgrade -y
sudo reboot
```

---

## 2. Installazione Docker

### 2.1 Repo ufficiale Docker (Ubuntu)

```bash
sudo apt install -y ca-certificates curl gnupg

sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
```

### 2.2 User nel gruppo docker

```bash
sudo usermod -aG docker $USER
```

**Disconnettiti e riconnettiti da SSH** per applicare il nuovo gruppo, poi verifica:

```bash
docker run --rm hello-world
```

### 2.3 (Opzionale) Log rotation Docker

`/etc/docker/daemon.json`:

```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

```bash
sudo systemctl restart docker
```

### Nota per Amazon Linux 2023

```bash
sudo dnf install -y docker
sudo systemctl enable --now docker
sudo usermod -aG docker ec2-user
```

Compose plugin:

```bash
sudo mkdir -p /usr/local/lib/docker/cli-plugins
sudo curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$(uname -m)" \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
```

---

## 3. DNS

### 3.1 Configura record A

Nel pannello DNS del tuo dominio (Route 53, Cloudflare, registrar, ecc.) crea:

```
esempio.it       A    ELASTIC_IP
www.esempio.it   A    ELASTIC_IP
```

Verifica propagazione:

```bash
dig esempio.it +short
dig www.esempio.it +short
```

Entrambi devono restituire l'Elastic IP.

### 3.2 Route 53 (se usi AWS per il DNS)

Se il dominio è gestito da Route 53:

- Vai su **Hosted Zone** del dominio
- Crea due record A con l'Elastic IP
- TTL 300 va bene per test

---

## 4. Struttura progetto

```bash
mkdir -p ~/sito && cd ~/sito
mkdir -p html caddy/data caddy/config
```

Struttura risultante:

```
~/sito/
├── docker-compose.yml
├── nginx.conf
├── html/               # contenuti del sito
│   └── index.html
└── caddy/
    ├── Caddyfile
    ├── data/           # certificati Let's Encrypt (persistente)
    └── config/         # config runtime Caddy
```

---

## 5. Contenuto del sito

Metti i file dentro `~/sito/html/`. Per un test rapido:

```bash
cat > ~/sito/html/index.html <<'EOF'
<!DOCTYPE html>
<html lang="it">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Il mio sito</title>
    <style>
        body { font-family: sans-serif; max-width: 720px; margin: 4rem auto; padding: 0 1rem; }
        h1 { color: #333; }
    </style>
</head>
<body>
    <h1>Sito online su AWS 🚀</h1>
    <p>Servito da Nginx dietro Caddy con HTTPS automatico.</p>
</body>
</html>
EOF
```

**Se hai un sito React/Vue/Vite già buildato**, copia `dist/` (o `build/`) dentro `html/`:

```bash
# Dal PC di sviluppo verso EC2
rsync -avz -e "ssh -i ~/Downloads/mia-chiave.pem" \
  ./dist/ ubuntu@ELASTIC_IP:/home/ubuntu/sito/html/
```

---

## 6. Configurazione Nginx

Crea `~/sito/nginx.conf`:

```nginx
server {
    listen 80;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;

    # Sito statico standard
    location / {
        try_files $uri $uri/ =404;
    }

    # Cache aggressiva su asset con hash (build framework)
    location /assets/ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Compressione
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml application/json application/javascript application/xml+rss application/atom+xml image/svg+xml;

    # Security header extra (Caddy ne aggiunge altri)
    add_header X-Content-Type-Options "nosniff" always;

    # Nega accesso a file nascosti
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
}
```

### Variante per SPA (React Router, Vue Router, ecc.)

Sostituisci il blocco `location /`:

```nginx
    location / {
        try_files $uri $uri/ /index.html;
    }
```

---

## 7. Configurazione Caddy

Crea `~/sito/caddy/Caddyfile`:

```
esempio.it, www.esempio.it {
    reverse_proxy web:80

    header {
        Strict-Transport-Security "max-age=31536000;"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "SAMEORIGIN"
        Referrer-Policy "strict-origin-when-cross-origin"
    }

    encode gzip zstd

    log {
        output file /data/access.log {
            roll_size 10mb
            roll_keep 5
        }
        format console
    }
}
```

**Sostituisci `esempio.it` con il tuo dominio.**

### Variante con redirect www → root

```
www.esempio.it {
    redir https://esempio.it{uri} permanent
}

esempio.it {
    reverse_proxy web:80

    header {
        Strict-Transport-Security "max-age=31536000;"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "SAMEORIGIN"
        Referrer-Policy "strict-origin-when-cross-origin"
    }

    encode gzip zstd
}
```

### Variante multi-dominio

```
esempio.it, www.esempio.it {
    reverse_proxy web:80
}

altro-sito.it {
    reverse_proxy altro-container:80
}
```

---

## 8. `docker-compose.yml`

Crea `~/sito/docker-compose.yml`:

```yaml
services:
  web:
    image: nginx:alpine
    container_name: sito-web
    restart: unless-stopped
    volumes:
      - ./html:/usr/share/nginx/html:ro
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
    networks:
      - web-net

  caddy:
    image: caddy:2-alpine
    container_name: sito-caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./caddy/Caddyfile:/etc/caddy/Caddyfile:ro
      - ./caddy/data:/data
      - ./caddy/config:/config
    depends_on:
      - web
    networks:
      - web-net

networks:
  web-net:
    driver: bridge
```

**Note:**
- Nginx non espone porte sull'host: parla solo con Caddy sulla rete interna Docker
- Caddy espone 80 e 443 sull'host (raggiunte tramite Security Group AWS)
- `./caddy/data` persiste i certificati Let's Encrypt (fondamentale per evitare rate limit)
- Le immagini `nginx:alpine` e `caddy:2-alpine` sono multi-arch: girano su `t3.*` (x86) e `t4g.*` (ARM Graviton)

---

## 9. Avvio

```bash
cd ~/sito
docker compose up -d
docker compose logs -f
```

Nei log Caddy cerca:

```
certificate obtained successfully
```

Se compare, il sito è online.

Test da browser: `https://esempio.it`

Test da CLI:

```bash
curl -I https://esempio.it
```

Header attesi:
- `HTTP/2 200`
- `strict-transport-security: max-age=31536000;`
- `server: Caddy`

---

## 10. Comandi utili

```bash
# Stato container
docker compose ps

# Log live (tutti i servizi)
docker compose logs -f

# Solo Caddy
docker compose logs -f caddy

# Restart singolo servizio
docker compose restart web
docker compose restart caddy

# Ricarica Caddyfile senza restart
docker compose exec caddy caddy reload --config /etc/caddy/Caddyfile

# Stop
docker compose down

# Stop + rimozione volumi (ATTENZIONE: cancella certificati)
docker compose down -v

# Update immagini
docker compose pull
docker compose up -d
```

---

## 11. Aggiornare i contenuti

I file sono in bind mount su `~/sito/html/`, basta sostituirli:

```bash
# Da PC di sviluppo con rsync
rsync -avz -e "ssh -i ~/Downloads/mia-chiave.pem" --delete \
  ./dist/ ubuntu@ELASTIC_IP:/home/ubuntu/sito/html/
```

Oppure sulla VM:

```bash
cp -r nuovi-file/* ~/sito/html/
```

Nessun restart necessario: Nginx serve direttamente dai file. Al massimo un hard-refresh del browser per bypassare la cache.

---

## 12. Backup

### Opzione A: backup locale su S3

```bash
# Installa AWS CLI v2 (installer ufficiale: su Ubuntu 24.04 il pacchetto apt `awscli` non c'è più)
# Su Amazon Linux 2023 è già preinstallata
sudo apt install -y unzip
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" -o /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /tmp && sudo /tmp/aws/install
rm -rf /tmp/aws /tmp/awscliv2.zip
aws --version

# Configura credenziali (usa un IAM user con permessi minimi su un bucket dedicato)
aws configure

# Sync
aws s3 sync ~/sito/ s3://mio-bucket-backup/sito/ --exclude "caddy/config/*"
```

Automatizzalo con cron:

```bash
(crontab -l 2>/dev/null; echo '0 3 * * * /usr/local/bin/aws s3 sync /home/ubuntu/sito/ s3://mio-bucket-backup/sito/ --exclude "caddy/config/*" --delete') | crontab -
```

`--delete` rimuove dal bucket i file cancellati in locale: abilita il **versioning** sul bucket se vuoi poter recuperare versioni precedenti. Il path `/usr/local/bin/aws` è quello dell'installer ufficiale (verifica con `which aws`).

### Opzione B: EBS Snapshot

Dalla console EC2 → **Volumes** → seleziona il volume dell'istanza → **Create snapshot**. Automatizzabile con Data Lifecycle Manager (DLM).

I due path critici da salvare:
- `~/sito/html/` — contenuti sito
- `~/sito/caddy/data/` — certificati Let's Encrypt

---

## 13. Troubleshooting

### Caddy non prende il certificato

```bash
docker compose logs caddy | grep -i error
```

Cause tipiche:

- **DNS non propagato:** `dig esempio.it +short` deve tornare l'Elastic IP
- **Porta 80 chiusa nel Security Group:** aggiungi la regola HTTP 80 da `0.0.0.0/0`
- **Elastic IP non associato:** se hai stoppato/startato l'istanza senza EIP, l'IP pubblico è cambiato
- **Rate limit Let's Encrypt:** dopo 5 validazioni fallite per lo stesso hostname in un'ora scatta il blocco temporaneo; inoltre si possono emettere al massimo 5 certificati identici a settimana. Caddy riprova da solo (e ripiega su ZeroSSL), ma mentre fai prove usa lo staging nel blocco globale in cima al Caddyfile:

```
{
    acme_ca https://acme-staging-v02.api.letsencrypt.org/directory
}
```

Poi rimuovi in produzione.

### 502 Bad Gateway

Caddy raggiunge ma Nginx non risponde:

```bash
docker compose exec caddy wget -qO- http://web:80
docker compose ps
docker compose logs web
```

### 404 su route SPA al refresh

Manca `try_files ... /index.html` in `nginx.conf`. Vedi sezione 6 (Variante SPA).

### Il sito è raggiungibile da `curl` sulla VM ma non da internet

Quasi certamente Security Group. Verifica:
- Regola inbound 80 da `0.0.0.0/0`
- Regola inbound 443 da `0.0.0.0/0`
- Il Security Group giusto è associato all'istanza (controlla la tab **Security** dell'istanza)

### Timeout SSH dopo un restart

L'IP pubblico è cambiato. Se non hai un Elastic IP, questo è normale. Alloca un EIP e associalo.

### Certificato scaduto

Caddy rinnova a ~30 giorni dalla scadenza. Se non ce l'ha fatta, controlla i log e verifica che porta 80 sia sempre aperta (Let's Encrypt fa HTTP-01 challenge lì).

---

## 14. Considerazioni AWS specifiche

### Costi da tenere d'occhio

- **Istanza / Free Tier:** dipende da quando hai creato l'account AWS. Account creati **prima del 15 luglio 2025**: 750 ore/mese di `t2.micro`/`t3.micro` gratis per 12 mesi. Account creati **dopo**: piano gratuito a crediti (fino a 200 $, validi al massimo 6 mesi) da spendere anche su istanze come `t3.micro`/`t4g.small`. Fuori dal Free Tier `t4g.small` costa ~12 $/mese on-demand
- **Elastic IP / IPv4 pubblico:** dal 1° febbraio 2024 AWS fa pagare **ogni** indirizzo IPv4 pubblico (0.005 $/ora ≈ 3.6 $/mese), **anche se associato** a un'istanza running. Mettilo in conto fin da subito (nel Free Tier classico sono incluse 750 ore/mese di IPv4 pubblico per i primi 12 mesi)
- **Traffico egress:** primi 100 GB/mese gratis, poi ~0.09 $/GB. Un sito statico normale non arriva mai
- **EBS:** ~0.10 $/GB/mese per gp3

### CloudWatch / metriche

Le metriche base (CPU, network, disk) sono gratis. Per metriche dettagliate (memoria, disk usage interno) serve il CloudWatch Agent. Per un sito statico non serve.

### Alternativa: S3 + CloudFront

Per un sito **puramente statico** senza requisiti di backend, S3 + CloudFront è più semplice e più economico di EC2. Ma perdi il controllo tipo self-hosted, e non puoi girare container. Se pensi in futuro di aggiungere un backend, EC2 con questo setup è più flessibile.

### Sicurezza

- Tieni SSH aperto solo dal tuo IP
- Considera **AWS Systems Manager Session Manager** per accesso senza SSH pubblico (richiede IAM role sull'istanza)
- Abilita **CloudTrail** per audit
- Usa **IMDSv2** obbligatorio (default sulle nuove AMI)

### Auto-restart al reboot

Docker con `restart: unless-stopped` riparte da solo. Verifica che il servizio Docker sia enabled al boot:

```bash
sudo systemctl enable docker
```

---

## 15. Estensioni possibili

### Basic auth

Genera hash:

```bash
docker compose exec caddy caddy hash-password --plaintext 'password'
```

Nel Caddyfile:

```
esempio.it {
    basicauth {
        alessio $2a$14$hash_bcrypt_qui
    }
    reverse_proxy web:80
}
```

### Redirect HTTP → HTTPS

Automatico in Caddy: non serve configurare nulla.

### CI/CD con GitHub Actions

Pattern tipico:
1. Push su `main` → Actions builda il sito
2. Actions fa SCP/rsync di `dist/` verso `~/sito/html/` sull'EC2
3. Nessun restart necessario, Nginx serve i nuovi file

Chiave SSH deploy dedicata + IP fisso Actions o self-hosted runner in VPC.

### Aggiungere backend Node/Python

Aggiungi un servizio nel compose e un sottodominio nel Caddyfile:

```yaml
  api:
    image: alexis82/api:latest
    container_name: sito-api
    restart: unless-stopped
    networks:
      - web-net
```

```
api.esempio.it {
    reverse_proxy api:3000
}
```

---

## Note

- Nginx serve i file, Caddy fa TLS + reverse proxy
- Caddy gestisce Let's Encrypt in automatico (rinnovi inclusi), niente `certbot`
- Certificati persistiti in `./caddy/data` — non cancellare
- Nginx non è esposto direttamente, l'unico ingresso pubblico è Caddy sulle 80/443
- Multi-arch: setup identico su `t3.*` (x86_64) e `t4g.*` (ARM Graviton)
- Con un Elastic IP + Security Group configurato bene, il setup è resiliente a reboot e stop/start
