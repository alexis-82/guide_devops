# Deploy sito React/Vite/Tailwind su AWS EC2 (Docker + Nginx + Caddy)

Guida per pubblicare un sito React (Vite + Tailwind + TypeScript) su un'istanza AWS EC2 partendo da zero: build multi-stage dentro Docker, Nginx serve i file statici, Caddy fa da reverse proxy con HTTPS automatico.

**Setup di riferimento:**
- Cloud: AWS EC2, Ubuntu 24.04 LTS
- Istanza: `t3.micro` (x86, Free Tier) o `t4g.small` (ARM Graviton)
- Stack sito: React + TypeScript + Vite + Tailwind CSS
- Dominio: `esempio.it` / `www.esempio.it` (sostituisci con il tuo)

---

## Indice

- [1. Istanza EC2](#1-istanza-ec2)
   - [1.1 Lancio](#11-lancio)
   - [1.2 Security Group](#12-security-group)
   - [1.3 Accesso e update](#13-accesso-e-update)
- [2. Installazione Docker](#2-installazione-docker)
- [3. DNS](#3-dns)
- [4. Struttura progetto](#4-struttura-progetto)
- [5. Verifiche pre-build](#5-verifiche-pre-build)
   - [5.1 `package.json`](#51-packagejson)
   - [5.2 `tailwind.config.js`](#52-tailwindconfigjs)
   - [5.3 `tsconfig.node.json`](#53-tsconfignodejson)
   - [5.4 Test build in locale](#54-test-build-in-locale)
- [6. Dockerfile multi-stage](#6-dockerfile-multi-stage)
- [7. Nginx per SPA](#7-nginx-per-spa)
- [8. `.dockerignore`](#8-dockerignore)
- [9. Caddyfile](#9-caddyfile)
- [10. `docker-compose.yml`](#10-docker-composeyml)
- [11. Build e avvio](#11-build-e-avvio)
- [12. Workflow aggiornamenti](#12-workflow-aggiornamenti)
- [13. Troubleshooting](#13-troubleshooting)
   - [`TS6306` / `TS6310` in build](#ts6306--ts6310-in-build)
   - [CSS senza classi Tailwind](#css-senza-classi-tailwind)
   - [404 al refresh su route React Router](#404-al-refresh-su-route-react-router)
   - [Caddy non prende il certificato](#caddy-non-prende-il-certificato)
   - [502 Bad Gateway](#502-bad-gateway)
   - [Build lento o OOM su `t3.micro`](#build-lento-o-oom-su-t3micro)
   - [SSH in timeout dopo un restart](#ssh-in-timeout-dopo-un-restart)
- [14. Note AWS](#14-note-aws)

---

## 1. Istanza EC2

### 1.1 Lancio

Dalla console EC2:

- **AMI:** Ubuntu Server 24.04 LTS
- **Tipo:** `t3.micro` o `t4g.small`
- **Key pair:** genera o riusa una `.pem`
- **Storage:** 8-20 GB gp3
- **Elastic IP:** allocalo e associalo all'istanza. Senza EIP l'IP pubblico cambia a ogni stop/start e il DNS smette di funzionare

### 1.2 Security Group

| Type  | Port | Source              |
|-------|------|---------------------|
| SSH   | 22   | Il tuo IP (`/32`)   |
| HTTP  | 80   | `0.0.0.0/0`         |
| HTTPS | 443  | `0.0.0.0/0`         |

La porta 80 serve a Caddy per ottenere il certificato: non chiuderla.

Sulle AMI Ubuntu di AWS **non ci sono regole iptables** che bloccano 80/443: basta il Security Group.

### 1.3 Accesso e update

```bash
chmod 400 ~/Downloads/mia-chiave.pem
ssh -i ~/Downloads/mia-chiave.pem ubuntu@ELASTIC_IP

sudo apt update && sudo apt upgrade -y
sudo reboot
```

---

## 2. Installazione Docker

```bash
sudo apt install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo usermod -aG docker $USER
```

Esci e rientra da SSH, poi:

```bash
docker run --rm hello-world
```

---

## 3. DNS

Nel pannello DNS (Route 53, Cloudflare, registrar):

```
esempio.it       A    ELASTIC_IP
www.esempio.it   A    ELASTIC_IP
```

```bash
dig esempio.it +short
dig www.esempio.it +short
```

Entrambi devono restituire l'Elastic IP.

---

## 4. Struttura progetto

```bash
# Opzione A - da GitHub
git clone https://github.com/utente/nome-repo.git ~/sito

# Opzione B - da PC di sviluppo
rsync -avz -e "ssh -i ~/Downloads/mia-chiave.pem" \
  --exclude 'node_modules' --exclude 'dist' \
  ./portfolio/ ubuntu@ELASTIC_IP:/home/ubuntu/sito/
```

```bash
cd ~/sito
mkdir -p caddy/data caddy/config
```

Struttura finale:

```
~/sito/
├── src/, index.html, package.json, ...   # codice React
├── Dockerfile
├── nginx.conf
├── .dockerignore
├── docker-compose.yml
└── caddy/
    ├── Caddyfile
    ├── data/       # certificati (persistente, non cancellare)
    └── config/
```

---

## 5. Verifiche pre-build

### 5.1 `package.json`

Tailwind, Vite e TypeScript devono stare in `devDependencies` (servono solo in build):

```json
{
  "scripts": {
    "dev": "vite",
    "build": "tsc -b && vite build",
    "preview": "vite preview"
  },
  "devDependencies": {
    "tailwindcss": "^3.x.x",
    "postcss": "...",
    "autoprefixer": "...",
    "vite": "...",
    "@vitejs/plugin-react": "...",
    "typescript": "..."
  }
}
```

### 5.2 `tailwind.config.js`

I path in `content` devono coprire i file sorgente, altrimenti la build produce un CSS senza classi utility:

```js
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: { extend: {} },
  plugins: [],
}
```

### 5.3 `tsconfig.node.json`

Il template Vite usa i project references di TypeScript. Il file referenziato deve avere `"composite": true` e l'emit non disabilitato, altrimenti `tsc -b` fallisce con:

```
error TS6306: Referenced project '.../tsconfig.node.json' must have setting "composite": true.
error TS6310: Referenced project '.../tsconfig.node.json' may not disable emit.
```

Contenuto corretto:

```json
{
  "compilerOptions": {
    "composite": true,
    "skipLibCheck": true,
    "module": "ESNext",
    "moduleResolution": "bundler",
    "allowSyntheticDefaultImports": true,
    "strict": true,
    "noEmit": false
  },
  "include": ["vite.config.ts"]
}
```

In dev mode (`npm run dev`) Vite non chiama `tsc`, quindi l'errore compare solo con `npm run build`.

### 5.4 Test build in locale

```bash
npm install && npm run build && ls dist/
```

Devi vedere `index.html` e `assets/`.

---

## 6. Dockerfile multi-stage

`~/sito/Dockerfile`:

```dockerfile
# Stage 1: build
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Stage 2: serve
FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
```

Immagini multi-arch: funziona sia su `t3.*` sia su `t4g.*`.

---

## 7. Nginx per SPA

`~/sito/nginx.conf`:

```nginx
server {
    listen 80;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;

    # Client-side routing (React Router)
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Cache aggressiva sugli asset con hash
    location /assets/ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Nega file nascosti
    location ~ /\. {
        deny all;
    }
}
```

La compressione la fa Caddy (`encode gzip zstd`), quindi qui non serve.

---

## 8. `.dockerignore`

```bash
cat > ~/sito/.dockerignore <<'EOF'
node_modules
dist
.git
.env
.env.local
*.log
.DS_Store
.vscode
caddy
EOF
```

`caddy` è escluso così i certificati non finiscono nel contesto di build.

---

## 9. Caddyfile

`~/sito/caddy/Caddyfile`:

```
esempio.it, www.esempio.it {
    reverse_proxy portfolio:80

    header {
        Strict-Transport-Security "max-age=31536000;"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "SAMEORIGIN"
        Referrer-Policy "strict-origin-when-cross-origin"
    }

    encode gzip zstd
}
```

Nessuna configurazione TLS: Caddy ottiene e rinnova da solo i certificati (Let's Encrypt, fallback ZeroSSL) per ogni dominio scritto nel blocco, e fa il redirect HTTP → HTTPS.

**Variante redirect www → root:**

```
www.esempio.it {
    redir https://esempio.it{uri} permanent
}

esempio.it {
    reverse_proxy portfolio:80
    # header ed encode come sopra
}
```

**Variante redirect root → www:**

```
esempio.it {
    redir https://www.esempio.it{uri} permanent
}

www.esempio.it {
    reverse_proxy portfolio:80
    # header ed encode come sopra
}
```

In entrambe le varianti Caddy prende il certificato per tutti e due i domini: serve anche a quello che fa solo redirect, altrimenti `https://` su quel nome darebbe errore.

---

## 10. `docker-compose.yml`

`~/sito/docker-compose.yml`:

```yaml
services:
  portfolio:
    build: .
    image: portfolio:latest
    container_name: portfolio
    restart: unless-stopped
    networks:
      - web-net

  caddy:
    image: caddy:2-alpine
    container_name: caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      - "443:443/udp"   # HTTP/3
    volumes:
      - ./caddy/Caddyfile:/etc/caddy/Caddyfile:ro
      - ./caddy/data:/data
      - ./caddy/config:/config
    depends_on:
      - portfolio
    networks:
      - web-net

networks:
  web-net:
```

`portfolio` e `caddy` sono nello stesso compose: la rete `web-net` viene creata automaticamente e Caddy raggiunge il sito tramite l'hostname `portfolio`.

Per HTTP/3 aggiungi anche **UDP 443** nel Security Group (opzionale: senza, si usa HTTP/2).

---

## 11. Build e avvio

```bash
cd ~/sito
docker compose up -d --build
docker compose logs -f caddy
```

Nei log cerca `certificate obtained successfully`.

```bash
curl -I https://esempio.it
```

Atteso: `HTTP/2 200`, `server: Caddy`, header `strict-transport-security`.

---

## 12. Workflow aggiornamenti

```bash
cd ~/sito
git pull
docker compose up -d --build
```

L'immagine `portfolio` si ricostruisce e il container viene sostituito (1-2 secondi di downtime). Caddy non va toccato.

Se modifichi solo il Caddyfile:

```bash
docker compose exec caddy caddy reload --config /etc/caddy/Caddyfile
```

---

## 13. Troubleshooting

### `TS6306` / `TS6310` in build
Sistema `tsconfig.node.json` (sezione 5.3).

### CSS senza classi Tailwind
Controlla `content` in `tailwind.config.js` (sezione 5.2).

### 404 al refresh su route React Router
Manca `try_files $uri $uri/ /index.html;` in `nginx.conf`.

### Caddy non prende il certificato
- `dig esempio.it +short` deve restituire l'Elastic IP
- Porte 80 e 443 aperte nel Security Group (e il SG giusto associato all'istanza)
- `docker compose logs caddy | grep -i error`

### 502 Bad Gateway
```bash
docker compose exec caddy wget -qO- http://portfolio:80 | head
docker compose logs portfolio
```

### Build lento o OOM su `t3.micro`
`npm ci` con 1 GB di RAM può andare in crisi. Aggiungi swap:

```bash
sudo fallocate -l 2G /swapfile && sudo chmod 600 /swapfile
sudo mkswap /swapfile && sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

### SSH in timeout dopo un restart
IP cambiato: manca l'Elastic IP.

---

## 14. Note AWS

- **Costi:** il Free Tier dipende dalla data di creazione dell'account. Prima del 15 luglio 2025: `t3.micro` gratis per 12 mesi (750 ore/mese). Dopo: piano gratuito a crediti (fino a 200 $, validi al massimo 6 mesi). Un indirizzo IPv4 pubblico, Elastic IP compreso, si paga dal febbraio 2024 (0.005 $/ora ≈ 3.6 $/mese) anche quando associato, quindi mettilo in conto
- **Backup:** l'unico dato da salvare è `~/sito/caddy/data/` (certificati). Il sito si ricostruisce dal repo. Per sicurezza, snapshot EBS periodico da console o Data Lifecycle Manager
- **Auto-restart:** `restart: unless-stopped` + `sudo systemctl enable docker` e tutto riparte dopo un reboot
- **Backend futuro:** nuovo servizio nel compose + blocco `api.esempio.it { reverse_proxy api:3000 }` nel Caddyfile
