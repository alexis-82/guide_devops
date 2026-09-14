# Guide DevOps

Raccolta personale di guide operative e appunti su strumenti e pratiche DevOps,
testati su ambienti reali (lab VMware a 3 nodi, Oracle Cloud, Amazon AWS).

Il taglio è pratico: comandi commentati riga per riga, trappole incontrate sul
campo, configurazioni funzionanti da riusare. Tutto in italiano.

---

## Contenuti

### ☸️ [Kubernetes](./kubernetes/)

Cluster `kubeadm` multi-nodo su VMware, dall'installazione al day-2.

- **[Installazione e configurazione cluster](./kubernetes/installazione_configurazione/)** — Guida completa da zero: template VM, containerd, CNI, clonazione, bootstrap con `kubeadm init`, hardening SSH.
- **[Cheatsheet comandi `kubectl`](./kubernetes/comandi/)** — Comandi base per il lavoro quotidiano: pod, deployment, rollout, manifest YAML, pulizia risorse. Testato su cluster `kubeadm` v1.37.
- **[Esempi YAML](./kubernetes/examples-yaml/)** — *(work in progress)*

### 🐳 [Docker](./docker/)

Installazione di Docker Compose V2 su Debian/Ubuntu e progetti di esempio.

- **[Guida installazione + comandi principali](./docker/)**
- **[Node.js + PostgreSQL](./docker/docker-compose-Node.js-PostgreSQL/)** — Stack full-stack con init SQL.
- **[MongoDB + Mongo Express](./docker/docker-compose-MongoDB-MongoExpress/)**
- **[MySQL](./docker/docker-compose-mysql/)** con database Northwind.
- **[MySQL + phpMyAdmin](./docker/docker-compose-mysql-phpmyadmin/)**
- **[Flask](./docker/docker-flask/)** — Applicazione Python containerizzata.
- **[Docker network bridge](./docker/docker-network-bridge/)**
- **[Script di utilità](./docker/scripts/)** — Cleanup completo e upgrade automatico di `docker-compose`.

### 🤖 [Ansible](./ansible/)

Introduzione ad Ansible con playbook di esempio.

- **[Panoramica e concetti base](./ansible/)**
- **[Playbook con `become_method: sudo`](./ansible/sudo/)** — Configurazione tipica.
- **[Playbook con `become_method: su`](./ansible/su/)** — Variante per host senza `sudo`.

### 🏗️ [Terraform](./terraform/)

Installazione di Terraform su Linux e provisioning su AWS.

- **[Installazione + configurazione AWS con utente IAM dedicato](./terraform/)**
- **[Cheatsheet comandi](./terraform/comandi/)** — `init`, `plan`, `apply`, `destroy`, workspace, state.
- **[Esempi `.tf`](./terraform/examples-tf/)** — *(work in progress)*

---

## Ambienti di test

| Ambiente        | Uso                                                        |
| --------------- | ---------------------------------------------------------- |
| VMware lab      | Cluster Kubernetes 3 nodi (1 control plane + 2 worker)     |
| Oracle Cloud    | VPS Ubuntu per test cloud-native e self-hosting  |
| Amazon AWS      | Provisioning con Terraform tramite utente IAM dedicato     |
| Debian / Ubuntu | Distribuzioni di riferimento per tutti i comandi mostrati  |

---

## Autore

**[Alessio Abrugiati](https://github.com/alexis-82)** — Sviluppatore full-stack (React/TypeScript, Node.js, Python) e Linux enthusiast.
Appunti maturati sul campo tra sviluppo, self-hosting e sperimentazione DevOps.

## Licenza

Repository personale a scopo didattico. Sentiti libero di consultare e adattare i contenuti.