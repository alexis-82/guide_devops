# Terraform con AWS

Appunti di installazione di Terraform su Linux e configurazione dell'accesso programmatico ad AWS tramite un utente IAM dedicato.

> Riferimento ufficiale: <https://developer.hashicorp.com/terraform>
> Verifica sempre l'ultima versione stabile su <https://releases.hashicorp.com/terraform/> prima di procedere.

---

## 1. Installazione di Terraform su Linux

### Metodo A — Download del binario (installazione manuale)

Utile quando serve una versione specifica o quando non si vuole aggiungere un repository di terze parti.

```bash
# Variabili — aggiorna la versione se necessario
TF_VERSION="1.16.2"

# Download e installazione
wget https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_amd64.zip
sudo unzip terraform_${TF_VERSION}_linux_amd64.zip -d /usr/local/bin/
sudo chmod +x /usr/local/bin/terraform

# Pulizia
rm terraform_${TF_VERSION}_linux_amd64.zip
```

> **Nota:** meglio installare in `/usr/local/bin/` (convenzione per software non gestito dal package manager) piuttosto che in `/usr/bin/`.

### Metodo B — Repository APT ufficiale HashiCorp (Debian/Ubuntu)

Consigliato in ambienti a lungo termine: aggiornamenti gestiti da `apt`.

```bash
# 1. Aggiungi la chiave GPG di HashiCorp
wget -O- https://apt.releases.hashicorp.com/gpg | \
  sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

# 2. Aggiungi il repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | \
  sudo tee /etc/apt/sources.list.d/hashicorp.list

# 3. Installa
sudo apt update && sudo apt install -y terraform
```

### Verifica dell'installazione

```bash
terraform -v
```

Output atteso:

```
Terraform v1.16.2
on linux_amd64
```

Abilita l'autocompletamento della shell (opzionale ma comodo):

```bash
terraform -install-autocomplete
```

---

## 2. Configurazione utente IAM su AWS

Terraform ha bisogno di credenziali programmatiche per interagire con AWS. Best practice: **non usare mai l'utente root** — creare un utente IAM dedicato.

### 2.1 Creazione dell'utente `terraform`

Nella console AWS:

1. **IAM → Users → Create user**
2. **User name:** `terraform`
3. (Opzionale) spunta *"Provide user access to the AWS Management Console"* solo se serve accesso web — per Terraform NON è necessario.
4. **Next → Attach policies directly →** seleziona `AdministratorAccess`
   > ⚠️ `AdministratorAccess` è comodo in fase di test, ma in produzione applica il principio del **least privilege**: assegna solo i permessi effettivamente richiesti dalle risorse gestite.
5. **Next → Create user**

### 2.2 Generazione dell'Access Key

1. Apri l'utente `terraform` appena creato
2. Tab **Security credentials → Create access key**
3. Seleziona **Command Line Interface (CLI)**
4. Spunta la conferma in fondo alla pagina → **Next → Create access key**
5. **Salva subito**:
   - `Access key ID`
   - `Secret access key`
   > La Secret access key viene mostrata **una sola volta**: se la perdi devi rigenerarla.
6. **Done**

---

## 3. Configurazione delle credenziali in locale

Non inserire mai le chiavi direttamente nei file `.tf`. Opzioni consigliate, in ordine di preferenza:

### Opzione 1 — AWS CLI (`~/.aws/credentials`)

```bash
sudo apt install -y awscli
aws configure
```

Verrà creato `~/.aws/credentials`:

```ini
[default]
aws_access_key_id = AKIA...
aws_secret_access_key = ...
region = eu-south-1
```

### Opzione 2 — Variabili d'ambiente

```bash
export AWS_ACCESS_KEY_ID="AKIA..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_DEFAULT_REGION="eu-south-1"
```

### Controlla che siano effettivamente in ambiente

```bash
env | grep AWS
```

#### Attenzione con export

`export` vale solo per la shell corrente e i suoi figli. Se apri un altro terminale, le variabili non ci sono. Opzioni:

- **Sessione singola**: export prima di ogni sessione di lavoro
- **Persistente per l'utente**: aggiungi gli export in ~/.bashrc o ~/.zshrc — comodo ma le chiavi finiscono su disco in chiaro
- **Meglio**: usa uno strumento tipo direnv con un .envrc per progetto (aggiunto a .gitignore), oppure aws-vault che tiene le chiavi nel keyring del sistema e le inietta solo quando serve:

```bash
aws-vault exec terraform -- terraform plan
```

Per iniziare va benissimo l'`export` a mano; `aws-vault` te lo consiglio quando inizi ad avere più account/profili.

---

## 4. Test rapido: primo provider AWS

Crea `main.tf`:

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-south-1"  # Milano
}

# Info sull'account AWS con cui Terraform si è autenticato
data "aws_caller_identity" "current" {}

output "account_id" {
  value = data.aws_caller_identity.current.account_id
}

# Security Group: consente SSH in ingresso
resource "aws_security_group" "ssh_access" {
  name        = "allow-ssh"
  description = "Consente SSH in ingresso"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]   # ⚠️ in produzione: ["TUO.IP.PUBBLICO/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow-ssh"
  }
}

resource "aws_instance" "app_server" {
  ami = "ami-000000000000"
  instance_type = "t2.micro"

  key_name               = "terraform-key" # nome esatto della key pair su AWS

  tags = {
    Name = "NomeDellInstanza"
  }
}

output "instance_public_ip" {
  value       = aws_instance.app_server.public_ip
  description = "IP pubblico dell'istanza EC2"
}

output "ssh_command" {
  value       = "ssh -i ~/.ssh/aws_terraform ubuntu@${aws_instance.app_server.public_ip}"
  description = "Comando pronto per connettersi via SSH"
}
```

## Aggiungere una Key Pair per l'accesso SSH

Per collegarti via SSH all'istanza EC2 serve una **key pair**: **creata dalla console AWS** (EC2 → Key Pairs → Create key pair) e scarica un file `.pem`.


### Chiave generata da AWS

Crei la key pair dalla console AWS, AWS genera la coppia e ti fa scaricare **una sola volta** il file `.pem` (la chiave privata). La pubblica resta su AWS.

---

### Procedura chiave `.pem`

Il `.pem` scaricato **è la tua chiave privata SSH**

### 1. Spostalo in `~/.ssh/` e imposta i permessi

Il file appena scaricato è tipicamente in `~/Downloads/nome-chiave.pem`:

```bash
mv ~/Downloads/nome-chiave.pem ~/.ssh/
chmod 600 ~/.ssh/nome-chiave.pem
```

> `chmod 600` è **obbligatorio**: se il file è leggibile da altri utenti del sistema, SSH rifiuta di usarlo con l'errore `UNPROTECTED PRIVATE KEY FILE`.

### 2. Nel Terraform NON serve `aws_key_pair`

Dato che la chiave esiste già su AWS, devi solo **referenziarne il nome** (quello che hai messo nella console al momento della creazione, es. `terraform-key`):

```hcl
resource "aws_instance" "app_server" {
  ami           = "ami-000000000000"
  instance_type = "t2.micro"

  key_name               = "terraform-key"   # <-- nome esatto della key pair su AWS
  vpc_security_group_ids = [aws_security_group.ssh_access.id]

  tags = {
    Name = "NomeDellInstanza"
  }
}
```

Il Security Group e gli output (`instance_public_ip`, `ssh_command`) restano identici a prima.

### 3. Connessione SSH

Usi il `.pem` con `-i`, esattamente come si farebbe con qualsiasi chiave privata:

```bash
ssh -i ~/.ssh/nome-chiave.pem ubuntu@15.161.xxx.xxx
```

Se aggiorni l'output `ssh_command` per riflettere questo scenario:

```hcl
output "ssh_command" {
  value = "ssh -i ~/.ssh/nome-chiave.pem ubuntu@${aws_instance.app_server.public_ip}"
}
```

## Metodo per assegnazione spazio archivio

Aggiungere all'interno di **resource "aws_instance"** questo blocco per
personalizzare il disco root (di default molte AMI Ubuntu partono con 8 GB):

```hcl
root_block_device {
  volume_size = 20      # dimensione in GB (max 30 GB per il Free Tier)
  volume_type = "gp3"   # SSD general purpose, più economico e performante di gp2
}
```

> **Free Tier**: hai 30 GB/mese di EBS General Purpose SSD inclusi.
> Il conteggio è cumulativo su tutte le istanze attive.
```
---