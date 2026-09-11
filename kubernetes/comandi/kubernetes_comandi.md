# Kubernetes — Cheatsheet comandi base

Raccolta ragionata dei comandi `kubectl` più usati nel lavoro quotidiano con un cluster K8s. Testato su cluster kubeadm v1.37.

---

## Indice

- [Informazioni cluster e contesto](#informazioni-cluster-e-contesto)
- [Pod](#pod)
- [Deployment](#deployment)
- [Manifest YAML (apply/delete)](#manifest-yaml-applydelete)
- [Rollout e aggiornamenti](#rollout-e-aggiornamenti)
- [Pulizia risorse](#pulizia-risorse)

---

## Informazioni cluster e contesto

```bash
# Mostra endpoint API server e servizi core del cluster (utile come primo health check)
kubectl cluster-info

# Elenca tutti i namespace del cluster
kubectl get ns

# Elenca i nodi del cluster con stato, ruolo, età e versione K8s
kubectl get nodes

# Come sopra ma con IP, OS, kernel e container runtime — molto più informativo
kubectl get nodes -o wide
```

---

## Pod

```bash
# Crea un Pod "al volo" con l'immagine nginx (imperativo — utile per test veloci)
kubectl run mio-pod --image=nginx

# Crea un Pod con comando personalizzato che resta attivo (utile per debug/shell)
kubectl run alpine-test --image=alpine --command -- sleep 3600

# Elenca i Pod nel namespace corrente (default)
kubectl get pods

# Elenca i Pod in TUTTI i namespace (-A = --all-namespaces)
kubectl get pods -A

# Elenca i Pod con info aggiuntive: IP, nodo su cui girano
kubectl get pods -o wide

# Watch: aggiorna in tempo reale lo stato dei Pod di un namespace (Ctrl+C per uscire)
kubectl get pods -n kube-system -w

# Watch + info estese
kubectl get pods -n kube-system -w -o wide

# Mostra dettagli completi di un Pod: eventi, container, volumi, condizioni (primo comando quando qualcosa non va)
kubectl describe pod mio-pod

# Apre il manifest YAML del Pod in un editor per modificarlo al volo (non è GitOps, ma utile per test)
kubectl edit pod mio-pod

# Mostra i log del container principale del Pod
kubectl logs mio-pod

# Log in tempo reale (segue l'output come tail -f)
kubectl logs -f mio-pod

# Log di un Pod con più container: specifica quale
kubectl logs mio-pod -c nome-container

# Apre una shell interattiva dentro il Pod (per debug)
kubectl exec -it mio-pod -- bash

# Se bash non c'è (immagini minimal), prova sh
kubectl exec -it mio-pod -- sh

# Elimina il Pod (se gestito da un Deployment/ReplicaSet ne nasce subito uno nuovo)
kubectl delete pod mio-pod
```

---

## Deployment

Il Deployment è l'astrazione che gestisce Pod replicati e aggiornamenti. In produzione si usa quasi sempre questo, non Pod nudi.

```bash
# Crea un Deployment nginx con 1 replica di default
kubectl create deployment nginx-deploy --image=nginx

# Crea un Deployment httpbin (utile per testare HTTP: risponde con echo delle richieste)
kubectl create deployment httpbin-deploy --image=kennethreitz/httpbin

# Elenca i Deployment del namespace corrente
kubectl get deployments

# Scala il numero di repliche (numero TOTALE desiderato, non incrementale)
kubectl scale deployment nginx-deploy --replicas=3

# Mostra tutte le immagini dei Pod (filtro grep sul describe)
kubectl describe pods | grep Image

# Elimina un Deployment (rimuove anche ReplicaSet e Pod associati)
kubectl delete deployment nginx-deploy
```

---

## Manifest YAML (apply/delete)

Modo "dichiarativo": descrivi lo stato desiderato in un file YAML e K8s ci arriva. È la strada per la produzione (GitOps, versionamento su Git).

```bash
# Applica un manifest YAML (crea la risorsa se non esiste, la aggiorna se sì)
kubectl apply -f nginx-pod.yaml

# Elimina le risorse definite in un manifest YAML
kubectl delete -f nginx-pod.yaml

# Applica tutti i file YAML in una cartella
kubectl apply -f ./manifests/

# Applica un manifest da URL (utile per installare tool con un comando)
kubectl apply -f https://esempio.com/deploy.yaml
```

---

## Rollout e aggiornamenti

Il ciclo di aggiornamento di un Deployment: cambi immagine, monitori il rollout, e se rompi qualcosa fai rollback.

```bash
# Cambia l'immagine di un container in un Deployment (sintassi: deployment/NOME container_name=nuova_immagine)
# ⚠️ "nginx" prima del "=" è il NOME DEL CONTAINER dentro il Pod, non del Deployment
kubectl set image deployment/nginx-deploy nginx=nginx:1.25

# Per httpbin (il container si chiama "httpbin"):
kubectl set image deployment/httpbin-deploy httpbin=kennethreitz/httpbin:latest

# Mostra lo stato del rollout in corso (si blocca finché non finisce, o fallisce)
kubectl rollout status deployment/nginx-deploy

# Rollback all'immagine precedente (utile se il nuovo deploy è rotto)
kubectl rollout undo deployment/nginx-deploy

# Vedi la history dei rollout
kubectl rollout history deployment/nginx-deploy

# Rollback a una revisione specifica
kubectl rollout undo deployment/nginx-deploy --to-revision=2
```

---

## Pulizia risorse

⚠️ **Attenzione**: questi comandi cancellano in blocco. Verifica sempre il namespace attivo con `kubectl config current-context` prima di eseguirli.

```bash
# Elimina TUTTE le risorse "principali" (Pod, Deployment, Service, ecc.) nel namespace corrente
# NON tocca ConfigMap, Secret, PVC, PV — vanno cancellati separatamente
kubectl delete all --all

# Elimina tutti i ConfigMap del namespace corrente
kubectl delete configmap --all

# Elimina tutti i Secret del namespace corrente
# ⚠️ ATTENZIONE: cancella anche il Secret 'default-token' che alcuni componenti usano
kubectl delete secret --all

# Elimina tutti i PersistentVolumeClaim (richieste di storage) del namespace corrente
kubectl delete pvc --all

# Elimina tutti i PersistentVolume del cluster (⚠️ risorsa cluster-wide, non per namespace)
kubectl delete pv --all

# Verifica lo stato dei namespace dopo la pulizia
kubectl get namespaces
```

**Alternativa più pulita**: se vuoi ripartire da zero, crea un namespace dedicato per gli esperimenti e cancella quello.

```bash
# Crea namespace di test
kubectl create namespace lab

# Deploya risorse dentro il namespace
kubectl create deployment nginx-deploy --image=nginx -n lab

# Quando hai finito, cancella tutto in un colpo
kubectl delete namespace lab
```