[![kubernetes.png](https://i.ibb.co/JRVzfRLg/kubernetes.png)](https://ibb.co/LzmCLzwH)

# Kubernetes Lab: cluster multi-nodo con kubeadm su VMware

Guida operativa per creare un cluster Kubernetes realistico a 3 nodi (1 control plane + 2 worker) su VMware Workstation.

---

## Indice

- [1. Ambiente testato](#1-ambiente-testato)
- [2. Preparazione della VM template (una volta sola)](#2-preparazione-della-vm-template-una-volta-sola)
  - [2.1 Aggiornamento sistema](#21-aggiornamento-sistema)
  - [2.2 Disabilitazione swap](#22-disabilitazione-swap)
  - [2.3 Moduli kernel e parametri di rete](#23-moduli-kernel-e-parametri-di-rete)
  - [2.4 Installazione e configurazione containerd](#24-installazione-e-configurazione-containerd)
  - [2.5 Installazione kubeadm, kubelet, kubectl](#25-installazione-kubeadm-kubelet-kubectl)
  - [2.6 Accesso SSH con chiave](#26-accesso-ssh-con-chiave)
  - [2.7 Hardening SSH (opzionale ma consigliato)](#27-hardening-ssh-opzionale-ma-consigliato)
  - [2.8 Pulizia pre-clonazione](#28-pulizia-pre-clonazione)
  - [2.9 Shutdown del template](#29-shutdown-del-template)
- [3. Clonazione VMware (×3)](#3-clonazione-vmware-3)
  - [3.1 Rigenera i MAC address](#31-rigenera-i-mac-address)
  - [3.2 Primo avvio: personalizzazione di ciascun clone](#32-primo-avvio-personalizzazione-di-ciascun-clone)
- [4. Configurazione cluster (post-clone)](#4-configurazione-cluster-post-clone)
  - [4.1 /etc/hosts su tutti i nodi](#41-etchosts-su-tutti-i-nodi)
  - [4.2 Checklist pre-kubeadm](#42-checklist-pre-kubeadm)
- [5. Bootstrap del cluster](#5-bootstrap-del-cluster)
  - [5.1 kubeadm init sul master](#51-kubeadm-init-sul-master)
  - [5.2 Configurazione kubectl come utente non-root](#52-configurazione-kubectl-come-utente-non-root)
  - [5.3 Installazione CNI (Flannel)](#53-installazione-cni-flannel)
  - [5.4 Join dei worker](#54-join-dei-worker)
  - [5.5 Verifica finale](#55-verifica-finale)
- [6. Smoke test](#6-smoke-test)
- [7. Strumenti opzionali](#7-strumenti-opzionali)
  - [7.0 Panoramica: dashboard e strumenti di gestione](#70-panoramica-dashboard-e-strumenti-di-gestione)
  - [7.1 kubectl su Windows](#71-kubectl-su-windows)
  - [7.2 OpenLens (GUI desktop)](#72-openlens-gui-desktop)
  - [7.3 k9s (TUI sul master)](#73-k9s-tui-sul-master)
  - [7.4 Kubernetes Dashboard (via Helm)](#74-kubernetes-dashboard-via-helm)
  - [7.5 metrics-server (per grafici CPU/RAM)](#75-metrics-server-per-grafici-cpuram)
- [8. Snapshot VMware](#8-snapshot-vmware)
- [9. Appendice: troubleshooting](#9-appendice-troubleshooting)
- [Appendice B: alternative CNI (Calico e Cilium)](#appendice-b-alternative-cni-calico-e-cilium)
- [Riferimenti](#riferimenti)

---

## 1. Ambiente testato

| Componente | Valore |
|---|---|
| Hypervisor host | VMware Workstation Pro su Windows |
| OS guest | Ubuntu Server 24.04 LTS (o superiore) |
| Risorse per VM | 2 vCPU, 2-4 GB RAM, 20 GB disco |
| Rete | Bridged sulla LAN fisica |
| Kubernetes | v1.37 |
| Container runtime | containerd 2.x |
| CNI | Flannel |

### Variabili di riferimento

| Ruolo | Hostname | IP |
|---|---|---|
| Control plane | `k8s-m` | 192.168.1.200 |
| Worker 1 | `k8s-w1` | 192.168.1.201 |
| Worker 2 | `k8s-w2` | 192.168.1.202 |
| Gateway/DNS LAN | `fritzbox` | 192.168.1.1 |
| Pod CIDR | — | 10.244.0.0/16 |
| Service CIDR | — | 10.96.0.0/12 (default kubeadm) |

Adatta questi valori al tuo ambiente prima di eseguire i comandi.

---

## 2. Preparazione della VM template (una volta sola)

Tutti i passi di questa sezione si eseguono su **una singola VM** che poi verrà clonata. Riducono il lavoro ripetitivo e garantiscono che tutti i nodi partano identici.

### 2.1 Aggiornamento sistema

```bash
sudo apt update && sudo apt upgrade -y
```

### 2.2 Disabilitazione swap

Kubernetes richiede swap disabilitato per una gestione memoria prevedibile.

```bash
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Verifica
swapon --show     # non deve stampare nulla
free -h           # colonna Swap a 0
```

### 2.3 Moduli kernel e parametri di rete

```bash
# Moduli persistenti al boot
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Sysctl per bridge e forwarding
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system

# Verifica
lsmod | grep -E 'overlay|br_netfilter'
sysctl net.bridge.bridge-nf-call-iptables net.ipv4.ip_forward
```

### 2.4 Installazione e configurazione containerd

```bash
sudo apt install -y containerd

# Config di default
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null

# ⚠️ REQUISITO OBBLIGATORIO: usare systemd come cgroup driver
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

sudo systemctl restart containerd
sudo systemctl enable containerd

# Verifica
systemctl is-active containerd                      # deve rispondere: active
sudo grep SystemdCgroup /etc/containerd/config.toml # deve mostrare: SystemdCgroup = true
```

**Nota**: se vuoi la versione più recente di containerd invece di quella degli archivi Ubuntu, usa il repo Docker ufficiale ([docs.docker.com/engine/install/ubuntu](https://docs.docker.com/engine/install/ubuntu)). Su Ubuntu 24.04+ la versione negli archivi è comunque adeguata.

### 2.5 Installazione kubeadm, kubelet, kubectl

Riferimento ufficiale (aggiornato all'ultima versione): [kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)

```bash
sudo apt install -y apt-transport-https ca-certificates curl gpg

# Chiave GPG del repo Kubernetes (adatta la versione se necessario)
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.37/deb/Release.key | \
  sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Repo
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.37/deb/ /' | \
  sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt update
sudo apt install -y kubelet kubeadm kubectl

# Blocca gli aggiornamenti automatici (gli upgrade K8s vanno fatti a mano seguendo la procedura kubeadm)
sudo apt-mark hold kubelet kubeadm kubectl

# Verifica
kubeadm version -o short
kubelet --version
```

### 2.6 Accesso SSH con chiave

L'obiettivo è poter fare SSH dalla macchina di gestione (Windows o Linux) alla VM senza password.

**Da Windows (PowerShell host):**

```powershell
# Genera la chiave (se non ne hai già una)
ssh-keygen -t ed25519 -C "alessio@windows" -f $env:USERPROFILE\.ssh\id_ed25519

# One-liner per copiare la chiave sulla VM
Get-Content $env:USERPROFILE\.ssh\id_ed25519.pub | ssh alessio@<IP_template> "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"

# Test
ssh alessio@<IP_template>   # deve entrare senza password
```

**Da Linux:**

```bash
# Genera la chiave
ssh-keygen -t ed25519 -C "alessio@cachyos" -f ~/.ssh/id_ed25519

# Copia con ssh-copy-id
ssh-copy-id alessio@<IP_template>

# Test
ssh alessio@<IP_template>
```

### 2.7 Hardening SSH (opzionale ma consigliato)

> ⚠️ **Prima di disabilitare l'autenticazione a password**, verifica in una **seconda sessione SSH** (senza chiudere la prima) che il login con chiave funzioni. Se qualcosa va storto puoi ancora rimediare dalla sessione aperta.

```bash
sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart ssh
```

### 2.8 Pulizia pre-clonazione

Queste operazioni evitano che i cloni ereditino identità duplicate (host key SSH, machine-id, log).

```bash
# Pulizia log e cache
sudo journalctl --vacuum-time=1s
sudo apt clean
sudo apt autoremove -y
history -c && history -w

# Rimozione host key SSH (verranno rigenerate al primo boot di ogni clone)
sudo rm /etc/ssh/ssh_host_*

# Reset machine-id (verrà rigenerato al primo boot)
sudo truncate -s 0 /etc/machine-id
sudo rm /var/lib/dbus/machine-id
sudo ln -s /etc/machine-id /var/lib/dbus/machine-id
```

### 2.9 Shutdown del template

```bash
sudo shutdown now
```

Non riaccendere questa VM: da qui in poi lavori sui cloni.

---

## 3. Clonazione VMware (×3)

Con il template **spento**:

1. In VMware, tasto destro sulla VM template → **Manage → Clone**
2. Wizard:
   - "The current state in the virtual machine" → **Next**
   - **Create a full clone** (non linked clone) → **Next**
   - Nome: `k8s-m`, cartella di destinazione → **Finish**
3. Ripeti per `k8s-w1` e `k8s-w2`

### 3.1 Rigenera i MAC address

VMware dovrebbe rigenerarli automaticamente, ma è meglio forzarlo:

- Tasto destro su ciascun clone → **Settings → Network Adapter → Advanced...**
- Nel campo **MAC Address** clicca **Generate** e OK

Se "Generate" non basta, edita manualmente il file `.vmx` della VM (a VMware chiuso): cerca e **cancella** le righe `ethernet0.generatedAddress` e `ethernet0.generatedAddressOffset`. Al successivo avvio VMware ne genera uno nuovo.

### 3.2 Primo avvio: personalizzazione di ciascun clone

Accendi **una VM alla volta** e configurala prima di passare alla successiva (per evitare conflitti di hostname/IP sulla LAN).

Sul clone (accesso via console VMware, non ancora via SSH):

```bash
# Imposta l'hostname specifico del nodo (k8s-m sul master, k8s-w1 sul primo worker, ecc.)
sudo hostnamectl set-hostname k8s-w1

# Aggiorna solo la riga 127.0.1.1 di /etc/hosts (NON usare sed globale, romperebbe la mappatura del master)
sudo sed -i "s/^127.0.1.1.*/127.0.1.1 $(hostname)/" /etc/hosts

# IP statico via netplan (verifica prima il nome del file con: ls /etc/netplan/)
sudo vim /etc/netplan/*.yaml
# Modifica addresses: [192.168.1.201/24]
# Rimuovi eventuali righe macaddress: e set-name: ereditate dal template
sudo netplan apply

# Rigenera le host key SSH e riavvia sshd
sudo ssh-keygen -A
sudo systemctl restart ssh

# Reboot per applicare tutto pulito
sudo reboot
```

Verifiche post-reboot:

```bash
hostname                    # deve corrispondere al nodo (k8s-m / k8s-w1 / k8s-w2)
ip -4 addr show             # IP corretto
ip link show | grep ether   # MAC diverso da quello del template
cat /etc/machine-id         # non deve essere vuoto e deve essere diverso tra i nodi
```

**Nota su cloud-init**: se dopo reboot le modifiche a netplan si perdono, cloud-init sta rigenerando la config. Disabilita il networking gestito da cloud-init:

```bash
sudo tee /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg <<EOF
network: {config: disabled}
EOF
```

---

## 4. Configurazione cluster (post-clone)

### 4.1 /etc/hosts su tutti i nodi

Modifica `/etc/hosts` su **ciascuno** dei 3 nodi aggiungendo le mappature statiche.

```bash
sudo tee -a /etc/hosts >/dev/null <<'EOF'
192.168.1.200 k8s-m
192.168.1.201 k8s-w1
192.168.1.202 k8s-w2
EOF

# Verifica assenza di caratteri invisibili (spazi/tab strani da copia-incolla)
cat -A /etc/hosts | tail -5
# Gli spazi devono essere spazi normali; solo il $ di fine riga come carattere speciale
```

Riavvia il resolver e testa:

```bash
sudo systemctl restart systemd-resolved

getent hosts k8s-m
getent hosts k8s-w1
getent hosts k8s-w2

ping -c 2 k8s-m
ping -c 2 k8s-w1
ping -c 2 k8s-w2
```

### 4.2 Checklist pre-kubeadm

Su **tutti e 3 i nodi** verifica:

```bash
# Swap disabilitato
swapon --show               # non deve stampare nulla

# Moduli kernel
lsmod | grep -E 'overlay|br_netfilter'

# Sysctl
sysctl net.bridge.bridge-nf-call-iptables net.ipv4.ip_forward

# Containerd attivo con cgroup systemd
systemctl is-active containerd
sudo grep SystemdCgroup /etc/containerd/config.toml

# Firewall (se attivo, disabilitalo per il lab)
sudo systemctl status ufw
sudo systemctl disable --now ufw   # se attivo
```

---

## 5. Bootstrap del cluster

### 5.1 kubeadm init sul master

Sul solo `k8s-m`:

```bash
sudo kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --apiserver-advertise-address=192.168.1.200 \
  --control-plane-endpoint=k8s-m
```

**Spiegazione dei flag**:

- `--pod-network-cidr=10.244.0.0/16` → subnet interna dei Pod, default di **Flannel** (che installeremo). Deve **non sovrapporsi** alla LAN fisica: nel nostro caso la LAN è `192.168.1.0/24`, quindi `10.244.0.0/16` va bene. `192.168.0.0/16` (default di Calico) **causerebbe conflitto**: se vuoi usare Calico, cambia il CIDR a qualcosa come `10.10.0.0/16` e adatta la config di Calico.
- `--apiserver-advertise-address=192.168.1.200` → IP su cui l'API server ascolta.
- `--control-plane-endpoint=k8s-m` → hostname del control plane. Necessario per HA futuro, buona pratica anche adesso.

A fine esecuzione, `kubeadm` stampa:

1. Tre comandi da eseguire come utente non-root (mkdir/cp/chown per `$HOME/.kube/config`)
2. Un comando `kubeadm join ...` con token e hash → **salvalo**, servirà per i worker

### 5.2 Configurazione kubectl come utente non-root

Sul master, come utente `alessio` (non root):

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Test
kubectl get nodes
# k8s-m appare in stato NotReady — normale, manca il CNI
```

### 5.3 Installazione CNI (Flannel)

Flannel è il CNI più semplice e va benissimo per iniziare. Per alternative più potenti (Calico, Cilium) vedi l'**Appendice B**.

Con `--pod-network-cidr=10.244.0.0/16` Flannel funziona senza modifiche:

```bash
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```

Attendi 30-60 secondi e verifica:

```bash
kubectl get pods -n kube-flannel        # kube-flannel-ds-* Running
kubectl get pods -n kube-system         # coredns-* passa a Running
kubectl get nodes                       # k8s-m passa a Ready
```

Se `k8s-m` resta NotReady oltre i 2 minuti:

```bash
kubectl describe node k8s-m | tail -30
kubectl logs -n kube-flannel <nome-pod-flannel>
```

### 5.4 Join dei worker

Sul comando stampato da `kubeadm init` (esempio):

```bash
sudo kubeadm join k8s-m:6443 --token <token> \
    --discovery-token-ca-cert-hash sha256:<hash>
```

Eseguilo su `k8s-w1` e su `k8s-w2` (con sudo).

**Se il token è scaduto** (validità 24 ore), rigeneralo sul master:

```bash
kubeadm token create --print-join-command
```

### 5.5 Verifica finale

Dal master, dopo 1-2 minuti:

```bash
kubectl get nodes -o wide
```

Output atteso:

```
NAME     STATUS   ROLES           AGE   VERSION
k8s-m    Ready    control-plane   Xm    v1.37.x
k8s-w1   Ready    <none>          Xm    v1.37.x
k8s-w2   Ready    <none>          Xm    v1.37.x
```

Tutti e 3 i nodi in `Ready`. Cluster operativo. 🚀

---

## 6. Smoke test

Verifica che il cluster funzioni davvero deployando nginx e testando l'accesso via NodePort.

```bash
# Deploy nginx con 3 repliche
kubectl create deployment nginx-test --image=nginx --replicas=3

# Verifica che i pod si distribuiscano
kubectl get pods -o wide -l app=nginx-test

# Esponi come NodePort
kubectl expose deployment nginx-test --port=80 --type=NodePort

# Vedi la porta assegnata (30000-32767)
kubectl get svc nginx-test
```

Dal PowerShell su Windows, prova su **tutti** i nodi — deve rispondere ovunque, indipendentemente da dove sono i pod (magia di kube-proxy):

```powershell
curl http://k8s-m:<NodePort>
curl http://k8s-w1:<NodePort>
curl http://k8s-w2:<NodePort>
```

Cleanup:

```bash
kubectl delete deployment nginx-test
kubectl delete svc nginx-test
```

---

## 7. Strumenti opzionali

### 7.0 Panoramica: dashboard e strumenti di gestione

Kubernetes non ha una UI ufficiale privilegiata. Le opzioni principali sono:

**Kubernetes Dashboard (ufficiale)**
- Web UI base ma completa: risorse, log, exec nei container, metriche.
- **Pro**: ufficiale, integrata, leggera.
- **Contro**: UI datata, autenticazione via token da configurare a mano.
- Gira **dentro** il cluster.

**Lens / OpenLens**
- Desktop app (Windows/Linux/Mac) che si collega via kubeconfig. Non gira nel cluster, gira sul PC.
- Probabilmente la più usata tra i DevOps.
- **Pro**: UI moderna, multi-cluster, terminale integrato, metriche Prometheus se presenti, log real-time.
- **Contro**: Lens richiede account Mirantis. **OpenLens** è il fork community senza registrazione.

**Headlamp (CNCF Sandbox)**
- Progetto CNCF, moderno, open source. Può girare come desktop app o come web UI nel cluster.
- **Pro**: 100% open source, no login, estensibile con plugin, in crescita.
- **Contro**: meno diffuso di Lens quindi meno guide/community.

**Rancher**
- Piattaforma completa di gestione K8s: multi-cluster, provisioning, upgrade, monitoring, RBAC, marketplace.
- **Pro**: professionale, molto usato in azienda, ottimo per il curriculum.
- **Contro**: pesante (2-4 GB RAM), complesso, overkill per un lab singolo.

**k9s (TUI)**
- Terminal UI stile `htop` per Kubernetes.
- **Pro**: velocissimo, zero risorse cluster, aiuta a imparare `kubectl`.
- **Contro**: solo tastiera, curva di apprendimento iniziale.

**Consigliato per questo lab**: **OpenLens su Windows + k9s sul master**. Zero pod aggiuntivi nel cluster, GUI dove serve, TUI per il lavoro veloce. Kubernetes Dashboard vale la pena installarla come esercizio didattico (ServiceAccount, RBAC, token auth).

### 7.1 kubectl su Windows

```powershell
winget install -e --id Kubernetes.kubectl

# Copia il kubeconfig dal master
mkdir $env:USERPROFILE\.kube -ErrorAction SilentlyContinue
scp alessio@k8s-m:~/.kube/config $env:USERPROFILE\.kube\config

# Aggiungi k8s-m al hosts di Windows (PowerShell come amministratore)
Add-Content -Path C:\Windows\System32\drivers\etc\hosts -Value "`n192.168.1.200 k8s-m`n192.168.1.201 k8s-w1`n192.168.1.202 k8s-w2"

# Test
kubectl get nodes
```

### 7.2 OpenLens (GUI desktop)

Alternativa a Lens (più completo) senza registrazione: [github.com/MuhammedKalkan/OpenLens/releases](https://github.com/MuhammedKalkan/OpenLens/releases)
Lens con registrazione: [https://lenshq.io/](https://lenshq.io/)

Dopo l'installazione: `File → Add Cluster` → seleziona `%USERPROFILE%\.kube\config`. Riavvia OpenLens se il cluster non appare subito.

Comandi per visualizzare la telemetria:

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl patch deployment metrics-server -n kube-system --type=json -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'
kubectl get pods -n kube-system | grep metrics-server -w
kubectl top nodes
kubectl top pods -A
```

### 7.3 k9s (TUI sul master)

```bash
curl -sS https://webi.sh/k9s | sh
source ~/.config/envman/PATH.env

k9s
```

Comandi utili dentro k9s:

- `:pods`, `:deploy`, `:svc`, `:ns` → naviga tra risorse
- `l` su un pod → log
- `s` su un pod → shell
- `d` su una risorsa → describe
- `Ctrl+C` o `:q` → esci

### 7.4 Kubernetes Dashboard (via Helm)

Installazione Helm:

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

Installazione Dashboard:

```bash
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
helm repo update

helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard \
  --create-namespace --namespace kubernetes-dashboard

kubectl get pods -n kubernetes-dashboard
```

Accesso via port-forward (comodo per il lab):

```bash
kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-kong-proxy \
  8443:443 --address 0.0.0.0
```

Dal browser: `https://192.168.1.200:8443` (accetta il warning del certificato self-signed).

Crea utente admin e genera il token per il login:

```bash
kubectl create serviceaccount admin-user -n kubernetes-dashboard

kubectl create clusterrolebinding admin-user \
  --clusterrole=cluster-admin \
  --serviceaccount=kubernetes-dashboard:admin-user

kubectl -n kubernetes-dashboard create token admin-user
```

Incolla il token nella schermata di login.

### 7.5 metrics-server (per grafici CPU/RAM)

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Patch per certificati self-signed (necessario in lab)
kubectl patch deployment metrics-server -n kube-system --type=json \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

# Verifica dopo 30 secondi
kubectl top nodes
kubectl top pods -A
```

---

## 8. Snapshot VMware

Con il cluster funzionante e tutti gli strumenti installati, crea uno snapshot di ciascuna VM (a caldo o a freddo):

- Tasto destro su ciascuna VM → **Snapshot → Take Snapshot**
- Nome: `cluster-fresco-funzionante`
- Descrizione: `3 nodi Ready, Flannel + metrics-server, OpenLens connesso`

Da qui in avanti sei libero di sperimentare: se rompi qualcosa, rollback dello snapshot e sei di nuovo in 2 minuti a questo stato.

---

## 9. Appendice: troubleshooting

### `kex_exchange_identification: Connection reset` da SSH

Le host key non sono state rigenerate al primo boot del clone. Da console VMware:

```bash
sudo ssh-keygen -A
sudo systemctl restart ssh
```

### `Temporary failure in name resolution` con `/etc/hosts` corretto

Il file contiene caratteri invisibili (spazi non-standard, tab) da copia-incolla. Verifica:

```bash
cat -A /etc/hosts
```

Se vedi caratteri strani (`^I` per tab, `M-BM-` per non-breaking-space) nelle righe che hai aggiunto, riscrivile a mano con `nano`/`vim` invece che con `tee` o `echo`.

### MAC address duplicato dopo il clone

Sintomi: DHCP assegna lo stesso IP a più VM, ARP conflict, ping intermittente.

Fix: spegni la VM, edita il file `.vmx` (VMware chiuso), rimuovi le righe:

```
ethernet0.generatedAddress = "..."
ethernet0.generatedAddressOffset = "..."
```

VMware ne genera uno nuovo al successivo avvio. In alternativa, VMware Settings → Network Adapter → Advanced → **Generate** MAC.

### Cloud-init sovrascrive netplan al reboot

Ubuntu Server rigenera i file netplan a ogni boot se cloud-init è attivo per il networking. Disabilitalo:

```bash
sudo tee /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg <<EOF
network: {config: disabled}
EOF
```

Poi crea la tua config netplan pulita (es. `/etc/netplan/01-static.yaml`) con permessi `600`.

### Nodi worker restano NotReady dopo il join

Quasi sempre il pod Flannel sul worker sta ancora scaricando l'immagine. Attendi 1-2 minuti. Se persiste:

```bash
kubectl get pods -n kube-flannel -o wide
kubectl logs -n kube-flannel <nome-pod-flannel-sul-worker>
kubectl describe node <nome-worker> | tail -20
```

### Riepilogo comandi di gestione

| Cosa vuoi fare | Da dove | Comando |
|---|---|---|
| Vedere pod del cluster | Master (o Windows con kubeconfig) | `kubectl get pods -A -o wide` |
| Vedere pod di un nodo | Master | `kubectl get pods -A --field-selector spec.nodeName=k8s-w1 -o wide` |
| Container raw del runtime | Sul nodo via SSH | `sudo crictl ps` |
| Log container basso livello | Sul nodo via SSH | `sudo crictl logs <container-id>` |

---

## Appendice B: alternative CNI (Calico e Cilium)

Flannel è il CNI più semplice e va bene per iniziare, ma non è l'unico. Ecco le alternative principali da conoscere.

### Cos'è un CNI

Il **CNI** (Container Network Interface) è il componente che dà a ogni Pod un IP e permette a Pod su nodi diversi di comunicare come se fossero sulla stessa rete. Senza CNI i nodi restano `NotReady`. Kubernetes definisce l'API, il CNI la implementa.

### Confronto rapido

| Aspetto | Flannel | Calico | Cilium |
|---|---|---|---|
| Complessità setup | Bassissima | Media | Media/alta |
| NetworkPolicy K8s | No (o via terze parti) | Sì, native + estese | Sì, L3-L7 (HTTP, gRPC) |
| Modalità default | VXLAN overlay | BGP L3 (o overlay) | eBPF |
| Performance | Buone | Ottime (senza overlay) | Eccellenti |
| Scalabilità | Piccoli/medi | Grandi | Grandi |
| Crittografia Pod-to-Pod | No | WireGuard opzionale | WireGuard/IPsec |
| Osservabilità | Base | Media (calicoctl) | Avanzata (Hubble) |
| Curva di apprendimento | Facile | Media | Ripida |
| Uso tipico | Lab, K3s, edge | Enterprise on-prem | Cloud moderno, service mesh |

### Flannel — il minimo indispensabile

**Cosa fa**: crea una rete overlay VXLAN sopra la LAN. Ogni nodo prende una fetta della subnet dei Pod, il traffico tra nodi viaggia incapsulato in UDP.

**Pro**: zero config, pochi componenti, pochi bug. Ideale per imparare senza distrazioni.
**Contro**: nessuna NetworkPolicy nativa. Se vuoi filtrare traffico Pod-to-Pod devi aggiungere componenti esterni.

Chi lo usa: K3s (default), cluster piccoli, ambienti edge, lab.

### Calico — lo standard enterprise on-prem

**Cosa fa**: di default **non usa overlay**. Ogni nodo diventa un piccolo router BGP che annuncia le sue subnet dei Pod agli altri. Il traffico Pod-to-Pod viene instradato nativamente dalla LAN, senza incapsulamento. Se la rete non supporta BGP (WiFi domestico, cloud restrittivo), fallback a IPIP o VXLAN.

**Pro**: NetworkPolicy native e potenti (K8s standard + estensioni proprietarie come `GlobalNetworkPolicy`, regole egress, DNS-based). Performance migliori senza overlay. Modalità eBPF opzionale che sostituisce kube-proxy. Scala a migliaia di nodi. Supporta dual-stack IPv4/IPv6, WireGuard.

**Contro**: più componenti da capire (`calico-node`, `calico-kube-controllers`, `Typha` per cluster grandi). Se usi BGP puro serve un minimo di conoscenza di routing.

Chi lo usa: OpenShift, EKS (opzione), Rancher, AKS, la maggior parte dei cluster enterprise on-prem.

**Installazione (in alternativa a Flannel)**:

Al momento del `kubeadm init`, usa un CIDR che non collida con la LAN:

```bash
sudo kubeadm init \
  --pod-network-cidr=10.10.0.0/16 \
  --apiserver-advertise-address=192.168.1.200 \
  --control-plane-endpoint=k8s-m
```

Poi installa Calico (metodo operator, consigliato):

```bash
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/master/manifests/tigera-operator.yaml

# Scarica e modifica il CIDR nella custom resource
curl -O https://raw.githubusercontent.com/projectcalico/calico/master/manifests/custom-resources.yaml
sed -i 's|192.168.0.0/16|10.10.0.0/16|' custom-resources.yaml
kubectl create -f custom-resources.yaml
```

Verifica:

```bash
kubectl get pods -n calico-system
kubectl get pods -n tigera-operator
```

Con Calico installato puoi iniziare a scrivere `NetworkPolicy`, competenza fondamentale in produzione.

### Cilium — il futuro basato su eBPF

**Cosa fa**: usa **eBPF** (una tecnologia del kernel Linux che permette di eseguire codice sandbox dentro il kernel) per implementare networking, policy e osservabilità. Sostituisce anche kube-proxy con la sua implementazione eBPF, molto più efficiente.

**Pro**: NetworkPolicy L3-L7 (filtra non solo per IP/porta ma anche HTTP method, headers, gRPC service calls). Osservabilità profonda con **Hubble** (UI che mostra il traffico in tempo reale). Service mesh integrato senza sidecar. Performance eccellenti. Feature moderne (session affinity, DSR, source IP preservation).

**Contro**: curva di apprendimento più ripida (concetti eBPF). Richiede kernel Linux relativamente recente (5.10+ consigliato). Community e documentazione ottime ma meno "battaglia sul campo" di Calico su on-prem.

Chi lo usa: default di **Google GKE Dataplane V2**, **AWS EKS Auto Mode**, cluster nuovi in molte aziende cloud-native. Sta prendendo il posto di Calico in molti setup nuovi.

**Installazione (in alternativa a Flannel)**:

Cilium **non** vuole il flag `--pod-network-cidr` in `kubeadm init` — lo gestisce lui:

```bash
sudo kubeadm init \
  --apiserver-advertise-address=192.168.1.200 \
  --control-plane-endpoint=k8s-m \
  --skip-phases=addon/kube-proxy    # opzionale: Cilium può sostituire kube-proxy
```

Installazione via Helm:

```bash
helm repo add cilium https://helm.cilium.io/
helm repo update

helm install cilium cilium/cilium --version 1.16.0 \
  --namespace kube-system \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost=k8s-m \
  --set k8sServicePort=6443
```

Verifica con la CLI dedicata:

```bash
# Installa cilium CLI
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
curl -L --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-amd64.tar.gz
sudo tar xzvfC cilium-linux-amd64.tar.gz /usr/local/bin

cilium status --wait
```

Attiva Hubble per l'osservabilità (opzionale):

```bash
cilium hubble enable --ui
cilium hubble ui   # apre la UI su porta locale
```

### Percorso consigliato per te

1. **Ora**: Flannel installato, cluster funzionante, sperimenti con Pod/Deployment/Service — impari i concetti base senza distrazioni di rete.
2. **Prossimo lab (rollback snapshot + rifai)**: Calico. Impara a scrivere `NetworkPolicy` — competenza richiestissima in azienda e non testabile senza un CNI che la supporti nativamente.
3. **Più avanti**: Cilium con Hubble. Vedi il traffico in tempo reale, sperimenta policy L7, ti familiarizzi con eBPF concettualmente. È dove sta andando il mercato.

Avere usato **tutti e tre** ti dà una prospettiva completa: sai discutere trade-off in un colloquio, sai scegliere il CNI giusto per un progetto, non sei legato a un solo strumento.

### Cambiare CNI su un cluster esistente

Non è supportato "a caldo": bisogna fare `kubeadm reset` su tutti i nodi, ripulire le interfacce di rete e riniziare. In pratica:

```bash
# Su tutti i nodi
sudo kubeadm reset -f
sudo rm -rf /etc/cni/net.d
sudo iptables -F && sudo iptables -t nat -F && sudo iptables -t mangle -F && sudo iptables -X
sudo systemctl restart containerd
```

Poi rifai `kubeadm init` sul master con il CIDR nuovo e installi il nuovo CNI. Se hai fatto lo **snapshot VMware** come consigliato, la strada più pulita è rollback + re-init da zero.

### Accesso diretto da host

Serve per eseguire kubectl nel terminale del nostro host (Windows, Linux, macOS):
Link ufficiale download kubectl: [https://kubernetes.io/docs/tasks/tools/](https://kubernetes.io/docs/tasks/tools/)

```bash
$env:KUBECONFIG="$env:USERPROFILE\.kube\config" (Windows, potrebbe essere già configurato in automatico senza path)
export KUBECONFIG=~/.kube/config (Linux, macOS)
```
### Solo per la sessione corrente. Per renderla permanente:

```powershell
[System.Environment]::SetEnvironmentVariable('KUBECONFIG', "$env:USERPROFILE\.kube\config", 'User')
```

---

## Riferimenti

- Documentazione ufficiale kubeadm: [kubernetes.io/docs/setup/production-environment/tools/kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/)
- Flannel: [github.com/flannel-io/flannel](https://github.com/flannel-io/flannel)
- Calico: [docs.tigera.io/calico/latest](https://docs.tigera.io/calico/latest/about/)
- Cilium: [docs.cilium.io](https://docs.cilium.io/) — Hubble: [github.com/cilium/hubble](https://github.com/cilium/hubble)
- Helm: [helm.sh/docs](https://helm.sh/docs/)
- k9s: [k9scli.io](https://k9scli.io/)
- OpenLens: [github.com/MuhammedKalkan/OpenLens](https://github.com/MuhammedKalkan/OpenLens)
- crictl (cri-tools): [github.com/kubernetes-sigs/cri-tools](https://github.com/kubernetes-sigs/cri-tools)

## Screenshot

[![kubernetes-cluster-architecture.jpg](https://i.ibb.co/R4bZP8Zz/kubernetes-cluster-architecture.jpg)](https://ibb.co/3YdGWKGB)

[![Screenshot-20260911-175530.png](https://i.ibb.co/ycdqZ6HC/Screenshot-20260911-175530.png)](https://ibb.co/C3mQYbRy)