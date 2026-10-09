# Esempi YAML: dal cluster all'applicazione

Manifest pronti da applicare sul cluster `kubeadm` descritto nella [guida principale](../README.md)
(1 control plane + 2 worker, LAN `192.168.1.0/24`, CNI Flannel).

Il percorso va per gradi: prima l'app esposta con **NodePort**, poi un IP dedicato con **MetalLB**
e infine un **Ingress** con routing per nome host.

| File | Risorsa | Scopo |
| --- | --- | --- |
| `01-nginx-deployment.yaml` | Deployment | nginx con 2 repliche, requests/limits e readiness probe |
| `02-nginx-service-nodeport.yaml` | Service NodePort | Accesso da LAN su `<IP-nodo>:30080` |
| `03-metallb-pool.yaml` | IPAddressPool + L2Advertisement | Pool di IP LoadBalancer `192.168.1.240-250` |
| `04-nginx-service-clusterip.yaml` | Service ClusterIP | Backend interno per l'Ingress |
| `05-nginx-ingress.yaml` | Ingress | Host `nginx.lab.local` → Service `nginx-demo` |

---

## 1. Deployment + NodePort

```bash
kubectl apply -f 01-nginx-deployment.yaml
kubectl apply -f 02-nginx-service-nodeport.yaml

kubectl get pods -l app=nginx-demo -o wide   # i Pod girano sui worker
kubectl get svc nginx-demo-nodeport
```

Test da qualsiasi macchina della LAN (la NodePort risponde su **tutti** i nodi):

```bash
curl http://192.168.1.201:30080
curl http://192.168.1.202:30080
```

NodePort è comodo per un test, ma ha dei limiti: porte alte (30000-32767) e un IP di nodo da conoscere.
Il passo successivo risolve entrambi.

## 2. MetalLB: IP LoadBalancer in un cluster bare-metal

Su un cluster on-premise i Service `type: LoadBalancer` restano in `<pending>` perché nessun cloud
provider assegna l'IP. MetalLB fa proprio questo: prende un IP libero della LAN e lo annuncia via ARP.

```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.9/config/manifests/metallb-native.yaml

# Attendi che controller e speaker siano pronti
kubectl -n metallb-system wait --for=condition=ready pod --all --timeout=120s

kubectl apply -f 03-metallb-pool.yaml
```

> ⚠️ Il range `192.168.1.240-250` deve essere **fuori dal DHCP** del router (sul FritzBox:
> *Rete domestica → Rete → Impostazioni IPv4*) e non usato da altri host.
>
> kube-proxy in kubeadm usa la modalità `iptables` di default, quindi non serve abilitare `strictARP`
> (necessario solo con `mode: ipvs`).

## 3. Ingress controller (Traefik) + Ingress

Un Ingress da solo non fa nulla: serve un **Ingress controller**. Qui si usa Traefik, installato via Helm.
Il suo Service è di tipo `LoadBalancer`, quindi riceve automaticamente un IP dal pool MetalLB.

> Nota: il progetto `ingress-nginx` di Kubernetes è stato ritirato (manutenzione terminata a marzo 2026),
> per questo l'esempio usa Traefik, che supporta sia l'API Ingress sia Gateway API.

```bash
helm repo add traefik https://traefik.github.io/charts
helm repo update
helm install traefik traefik/traefik -n traefik --create-namespace

# EXTERNAL-IP deve mostrare un indirizzo del pool (es. 192.168.1.240)
kubectl -n traefik get svc traefik
```

Applica il Service interno e la regola di Ingress:

```bash
kubectl apply -f 04-nginx-service-clusterip.yaml
kubectl apply -f 05-nginx-ingress.yaml
kubectl get ingress nginx-demo
```

Test (sostituisci l'IP con l'EXTERNAL-IP di Traefik):

```bash
curl -H "Host: nginx.lab.local" http://192.168.1.240
```

Per usarlo dal browser aggiungi una riga al file `hosts` del tuo PC:

```text
192.168.1.240 nginx.lab.local
```

## Pulizia

```bash
kubectl delete -f .
helm uninstall traefik -n traefik
kubectl delete -f https://raw.githubusercontent.com/metallb/metallb/v0.14.9/config/manifests/metallb-native.yaml
```

> `kubectl delete -f .` prova a rimuovere anche le risorse MetalLB del file `03`: se hai già disinstallato
> MetalLB vedrai un errore sui CRD mancanti, ed è innocuo.
