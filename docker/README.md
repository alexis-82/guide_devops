# Installazione di Docker Compose V2 su Linux



* [Lista Comandi](#comandi-principali-di-docker) - [Guida Ufficiale](https://docs.docker.com/engine/install/ "Link")

### Scaricare Docker Compose V2

#### Debian
```bash
# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
```

#### Installazione pacchetti
```bash
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

#### Procedura per la configurazione del Gruppo
```bash
sudo groupadd docker
sudo usermod -aG docker $USER
sudo chown $USER:$USER /var/run/docker.sock
sudo systemctl restart docker
```

Verifichiamo che funzioni tutto correttamente:
```bash
docker info
```

### Verificare l'installazione
```bash
docker compose version
```

#### Ubuntu
```bash
# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
```

#### Installazione pacchetti
```bash
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

#### Procedura per la configurazione del Gruppo
```bash
sudo groupadd docker
sudo usermod -aG docker $USER
sudo chown $USER:$USER /var/run/docker.sock
sudo systemctl restart docker
```

Verifichiamo che funzioni tutto correttamente:
```bash
docker info
```

### Verificare l'installazione
```bash
docker compose version
```

---

# Comandi Principali di Docker

Ecco alcuni dei comandi principali di Docker che potrebbero esserti utili:

- `docker run`: Avvia o aggiorna un contenitore partendo da un'immagine.
- `docker build`: Costruisce un'immagine da un Dockerfile.
- `docker pull`: Scarica un'immagine da Docker Hub o da un registro personalizzato.
- `docker push`: Carica un'immagine su Docker Hub o su un registro personalizzato.
- `docker images`: Visualizza l'elenco delle immagini presenti nel sistema.
- `docker ps`: Mostra l'elenco dei contenitori in esecuzione, -a per visualizzarli tutti.
- `docker exec`: Esegue un comando all'interno di un contenitore in esecuzione.
- `docker images --filter=since=ID`: Mostra l'elenco delle immagini figlie dirette o indirette.
- `docker image rmi -f ID`: Eliminazione forzata dell'immagine.
- `docker container ls -a`: Visualizza la lista dei container.
- `docker container rm ID`: Eliminazione del container.
- `docker container stop $nomeContainer`: Ferma l'esecuzione del container.
- `docker container inspect $nomeContainer`: Eseguirà l'ispezione del container in JSON.

## Comandi completi di esempio
- `docker build -t $nomeImmagine .`: Costruzione dell'immagine, il . indica il percorso del file Dockerfile
- `docker run --rm --name $nomeContainer -it $nomeImmagine`: Avviamo il container in un immagine, --rm rimuove il container una volta finito e -it sta per interattivo
- `docker run --rm --name $nomeContainer -it -e myKey=pippo $nomeImmagine`: Con il flag -e specifichiamo una variabile, molto utile per i database
- `docker build -t $nomeImmagine .`: Oltre a costruire aggiorna anche il container se modifichiamo il file Dockerfile
- `docker run --rm --name $nomeContainer -it -p 3001:3000 $nomeImmagine`: Con il flag -p specifichiamo le porte host:container (dal browser porta 3001)
- `docker exec -it $nomeContainer /bin/sh`: Entriamo in modalità interattiva, cioè in shell, nel container
- `docker run -d --name $nomeContainer $nomeImmagine`: Il container si avvierà in modalità background (detach)
- `docker attach $nomeContainer`: Facciamo l'attach del container già in esecuzione.

## Bind Mount e Volumi
- `docker run -v HOST_PATH:CONTAINER_PATH $nomeImmagine`: Monta un directory host in un container (i percorsi devono essere assoluti).
- `docker volume create $nomeVolume`: Comando per creare un volume.
- `docker volume ls`: Comando per vedere la lista dei volumi creati.
- `docker volume inspect $nomeVolume`: Eseguirà l'ispezione del volume in JSON.
- `docker run -d --name $nomeNodo -v NOME_VOLUME:CONTAINER_PATH $nomeImmagine`: Avviamo il container con montato il volume creato.
- `docker volume prune -a`: Elimina tutti i volumi.

## Pulizia generica
- `docker system prune -a --volumes`: Rimuovere tutti i contenitori, le reti, le immagini (sia sospese che inutilizzate) e, facoltativamente, i volumi inutilizzati.

---

# Key Docker Commands

Here are some of the key Docker commands that might be useful:

- `docker run`: Starts a container based on an image.
- `docker build`: Builds an image from a Dockerfile.
- `docker pull`: Downloads an image from Docker Hub or a custom registry.
- `docker push`: Uploads an image to Docker Hub or a custom registry.
- `docker images`: Displays a list of images present in the system.
- `docker ps`: Shows the list of running containers, -a to display all.
- `docker exec`: Executes a command within a running container.
- `docker images --filter=since=ID`: Displays the list of direct or indirect child images.
- `docker image rmi -f ID`: Forced deletion of the image.
- `docker container ls -a`: Displays the list of containers.
- `docker container rm ID`: Deleting the container.
- `docker container stop $containerName`: Stops the execution of the container.
- `docker container inspect $containerName`: Will inspect the container in JSON format.


## Complete example commands
- `docker build -t $imageName .`: Builds the image, where the period indicates the path to the Dockerfile.
- `docker run --rm --name $containerName -it $imageName`: Launches the container from an image, where --rm removes the container once it finishes, and -it stands for interactive.
- `docker run --rm --name $containerName -it -e myKey=pippo $imageName`: Specifies a variable with the -e flag, which is very useful for databases.
- `docker build -t $imageName .`: Besides building, it also updates the container if we modify the Dockerfile.
- `docker run --rm --name $containerName -it -p 3001:3000 $imageName`: Specifies the host:container ports with the -p flag (port 3001 from the browser).
- `docker exec -it $containerName /bin/sh`: Enters interactive mode, i.e., shell, within the container.
- `docker run -d --name $nomeContainer $nomeImmagine`: The container will start in background (detached) mode.
- `docker attach $nomeContainer`: We attach to the already running container.

## Bind Mount and Volumes
- `docker run -v HOST_PATH:CONTAINER_PATH $nomeImmagine`: Mount a host directory in a container (paths must be absolute).
- `docker volume create $nomeVolume`: Command to create a volume.
- `docker volume ls`: Command to see the list of created volumes.
- `docker volume inspect $nomeVolume`: Will inspect the volume in JSON format.
- `docker run -d --name $nomeNodo -v NOME_VOLUME:CONTAINER_PATH $nomeImmagine`: We start the container with the created volume mounted.
- `docker volume prune -a`: Delete all volumes.

## General cleaning
- `docker system prune -a --volumes`: Remove all unused containers, networks, images (both dangling and unused), and optionally, volumes.