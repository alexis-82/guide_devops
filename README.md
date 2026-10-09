# Guide DevOps

[![Lint](https://github.com/alexis-82/guide_devops/actions/workflows/lint.yml/badge.svg)](https://github.com/alexis-82/guide_devops/actions/workflows/lint.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)

Raccolta personale di guide operative e appunti su strumenti e pratiche DevOps,
testati su ambienti reali (lab VMware a 3 nodi, Oracle Cloud, Amazon AWS).

Il taglio è pratico: comandi commentati riga per riga, trappole incontrate sul
campo, configurazioni funzionanti da riusare. Tutto in italiano.

---

## Contenuti

### ☸️ [Kubernetes](./kubernetes/)

Cluster `kubeadm` multi-nodo su VMware: comandi e manifest per il lavoro quotidiano.

- **[Cheatsheet comandi `kubectl`](./kubernetes/comandi/)** — Comandi base per il lavoro quotidiano: pod, deployment, rollout, manifest YAML, pulizia risorse. Testato su cluster `kubeadm` v1.37.
- **[Esempi YAML](./kubernetes/examples-yaml/)** — Dall'installazione all'uso: Deployment nginx, Service NodePort, MetalLB in Layer 2 e Ingress con Traefik.

### 🐳 [Docker](./docker/)

Installazione di Docker Compose V2 su Debian/Ubuntu e progetti di esempio.

- **[Guida installazione + comandi principali](./docker/)**
- **[Node.js + PostgreSQL](./docker/docker-compose-Node.js-PostgreSQL/)** — Stack full-stack con init SQL.
- **[MongoDB + Mongo Express](./docker/docker-compose-MongoDB-MongoExpress/)**
- **[MySQL](./docker/docker-compose-mysql/)** con database Northwind.
- **[MySQL + phpMyAdmin](./docker/docker-compose-mysql-phpmyadmin/)**
- **[Flask](./docker/docker-flask/)** — Applicazione Python containerizzata.
- **[Docker network bridge](./docker/docker-network-bridge/)**
- **[Sito statico su AWS EC2 (Nginx + Caddy)](./docker/docker-Nginx-Caddy-sito-statico-AWS/)** — File già buildati caricati con rsync, HTTPS automatico con Let's Encrypt.
- **[React/Vite su AWS EC2 (build Docker + Nginx + Caddy)](./docker/docker-React-Vite-Nginx-Caddy-AWS/)** — Build multi-stage sul server, deploy con `git pull`.
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
- **[aws-lab](./terraform/aws-lab/)** — Lab EC2 + RDS + S3 (VPC, IAM, SSM, budget), su Floci o AWS reale.
- **[Floci](./terraform/floci/)** — Setup di una VM Linux per l'emulatore AWS locale Floci: AWS CLI e Terraform senza account AWS.

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

Distribuito con licenza [MIT](./LICENSE): puoi consultare, riusare e adattare liberamente guide e codice, mantenendo l'attribuzione.