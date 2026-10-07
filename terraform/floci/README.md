# ☁️ floci-setup

Prepara in un colpo solo una VM Linux per far girare **[Floci](https://github.com/floci-io/floci)**,
l'emulatore AWS locale, gratuito e open source (MIT). EC2, RDS, Lambda ed EKS girano come
container Docker veri, e i comandi della AWS CLI e di Terraform funzionano come su AWS.

![Debian](https://img.shields.io/badge/Debian-12%20%7C%2013-A81D33?logo=debian&logoColor=white)
![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04%20%7C%2024.04-E95420?logo=ubuntu&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-CE-2496ED?logo=docker&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-ready-844FBA?logo=terraform&logoColor=white)

---

## ✨ Cosa installa

| Componente | Dettagli |
|---|---|
| 🐳 **Docker CE** | dal repo ufficiale, con il plugin `compose` |
| 🧰 **AWS CLI v2** | con un profilo `floci` già configurato (credenziali fittizie `test`/`test`) |
| 🏗️ **Terraform** | dal repo ufficiale HashiCorp |
| ☁️ **Floci** | in `~/floci/compose.yaml`, con persistenza `hybrid` e region `eu-south-1` (Milano) |
| 🔧 **Utility** | `jq`, `git`, `unzip`, `curl` |

## 📋 Requisiti

- VM con **Debian 12/13** o **Ubuntu 22.04/24.04** (amd64 o arm64)
- **4 vCPU, 8 GB di RAM, 40 GB di disco** (con 4 GB funziona, ma RDS ed EC2 sono container veri e stanno stretti)
- Rete **NAT, host-only o LAN**, mai esposta su internet (vedi [Sicurezza](#-sicurezza))

## 🚀 Installazione

```bash
sudo ./floci-setup.sh <username>     # es. sudo ./floci-setup.sh alessio
newgrp docker                        # oppure esci e rientra: abilita docker senza sudo
```

## ✅ Verifica

```bash
aws --profile floci s3 mb s3://prova && aws --profile floci s3 ls
```

Se compare `prova`, Floci è operativo.

## 🖥️ Console web

Apri dal browser del tuo PC:

```
http://<IP-VM>:4566/_floci/ui
```

> Al primo accesso Floci scarica e avvia la console come container separato: attendi qualche secondo.
> La console mostra Compute, Networking, Storage e Database. Gli altri servizi (IAM, SSM, ...)
> funzionano lo stesso, ma si usano solo da CLI, SDK o Terraform.

## 🛠️ Comandi utili

| Cosa | Comando |
|---|---|
| Log di Floci | `cd ~/floci && docker compose logs -f` |
| Riavvio | `cd ~/floci && docker compose restart` |
| Aggiornamento | `cd ~/floci && docker compose pull && docker compose up -d` |
| Stato dei servizi | `curl -s http://localhost:4566/_floci/health \| jq` |
| Container avviati (EC2, RDS, ...) | `docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Ports}}'` |
| Inventario risorse per tag | `aws --profile floci resourcegroupstaggingapi get-resources` |

## ⚠️ Errori comuni

| Sintomo | Causa | Soluzione |
|---|---|---|
| `permission denied ... docker.sock` | il gruppo `docker` non è ancora attivo | `newgrp docker` oppure logout/login |
| Terraform cerca file in `/root/...` | lanciato con `sudo` | Terraform e la AWS CLI vanno usati **senza sudo** |
| La console non si apre | immagine della UI ancora in download | attendi e ricarica; controlla `docker compose logs` |

## 🔒 Sicurezza

Floci monta il **Docker socket** (`/var/run/docker.sock`), quindi chi raggiunge la porta `4566`
ha di fatto **i permessi di root sulla VM**. Va benissimo in un laboratorio domestico, ma:

- non esporre mai la VM su internet;
- le credenziali `test`/`test` sono fittizie e valgono solo per Floci: per AWS reale usa un profilo separato.

## 🔗 Link

- [Floci su GitHub](https://github.com/floci-io/floci) · [Documentazione](https://floci.io/floci/)
- [aws-lab](../aws-lab): scenario Terraform EC2 + RDS + S3 da provare su questa VM
