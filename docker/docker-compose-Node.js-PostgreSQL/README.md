# Docker Compose con Node.js e PostgreSQL

Questo repository contiene un piccolo progetto realizzato con Node.js e PostgreSQL. L'applicazione è containerizzata utilizzando Docker Compose per un facile deployment e scalabilità.

## Tecnologie Utilizzate

- **Node.js**: Un runtime JavaScript basato sul motore JavaScript V8 di Chrome per eseguire codice JavaScript al di fuori di un browser web.
- **PostgreSQL**: Un potente sistema di database relazionale open-source.
- **Docker**: Una piattaforma per costruire, distribuire ed eseguire applicazioni utilizzando container.
- **Docker Compose**: Uno strumento per definire ed eseguire applicazioni Docker multi-container.

## Comandi generici

- `docker-compose up`: Questo comando crea e avvia i container definiti nel file docker-compose.yml.
- `docker-compose up --force-recreate`: Questo comando rigenera i container definiti nel file docker-compose.yml.
- `docker-compose up -d`: Avvia i container in modalità "detached" (in background).
- `docker-compose ls`: Elenca tutti i progetti Docker Compose presenti sul sistema.
- `docker-compose down`: Ferma i container.
- `docker-compose config`: Convalida e visualizza la configurazione Compose completa.
- `docker network create $nomeRete`: Per creare un Docker network personalizzato

## Collegare Due o più Container con Docker

### Passi per Collegare Due Container

1. **Creare una rete Docker personalizzata**
2. **Avviare il container del database nella rete**
3. **Avviare il container dell'applicazione nella stessa rete**

### Creare una Rete Docker Personalizzata

Per creare una rete Docker personalizzata, usa il seguente comando:

```bash
docker network create $nomeRete
```

invece per rimuovere una rete:

```bash
docker network rm $nomeRete
```

## Esempi comandi:

`docker run -d --name node_dbpg_1 --network $nomeRete -p 5432:5432 -v ./scripts/full.sql:/docker-entrypoint-initdb.d/full.sql --restart always --env-file postgres.env postgres`

1. **`docker run`**: Questo comando avvia un nuovo contenitore basato sull'immagine specificata alla fine del comando.

2. **`-d`**: Questo flag esegue il contenitore in modalità "detached", ossia in background. Il terminale non rimane bloccato sull'esecuzione del contenitore.

3. **`--name node_dbpg_1`**: Assegna un nome al contenitore. In questo caso, il nome del contenitore sarà `node_dbpg_1`. Questo rende più facile gestire il contenitore poiché puoi fare riferimento a esso tramite il nome piuttosto che l'ID.

4. **`--network $nomeRete`**: Questo flag consente ai contenitori di comunicare tra loro.

5. **`-p 5432:5432`**: Questo flag mappa la porta 5432 del sistema host alla porta 5432 del contenitore. Ciò significa che qualsiasi traffico sulla porta 5432 dell'host verrà inoltrato alla porta 5432 del contenitore.

6. **`-v ./scripts/full.sql:/docker-entrypoint-initdb.d/full.sql`**: Questo flag monta un volume, mappando il file `./scripts/full.sql` presente nel sistema host al percorso `/docker-entrypoint-initdb.d/full.sql` all'interno del contenitore. Questo è utile per inizializzare un database con uno script SQL.

7. **`--restart always`**: Questo flag configura il contenitore per riavviarsi automaticamente in caso di arresto anomalo. Il contenitore verrà riavviato anche quando il daemon Docker viene riavviato.

8. **`--env-file postgres.env`**: Specifica un file contenente le variabili d'ambiente da passare al contenitore. Il file `postgres.env` deve essere presente e contenere le variabili d'ambiente in formato `KEY=VALUE`.

9. **`postgres`**: Questo è il nome dell'immagine Docker da cui avviare il contenitore. Docker cercherà un'immagine con questo nome localmente o su Docker Hub se l'immagine non è disponibile localmente.

In sintesi, questo comando avvia un contenitore in background basato sull'immagine `postgres`, lo nomina `node_dbpg_1`, mappa la porta 5432 del contenitore alla porta 5432 dell'host, monta uno script SQL per l'inizializzazione del database, configura il contenitore per riavviarsi automaticamente in caso di arresto anomalo e carica le variabili d'ambiente dal file `postgres.env`.

---

`docker run -d --name node_web_node_1 --network $nomeRete -p 8080:8080 --env-file node.env web_node-node`

1. **`docker run`**: Questo comando avvia un nuovo contenitore basato sull'immagine specificata alla fine del comando.

2. **`-d`**: Questo flag esegue il contenitore in modalità "detached", ossia in background. Il terminale non rimane bloccato sull'esecuzione del contenitore.

3. **`--name node_web_node_1`**: Assegna un nome al contenitore. In questo caso, il nome del contenitore sarà `node_web_node_1`. Questo rende più facile gestire il contenitore poiché puoi fare riferimento a esso tramite il nome piuttosto che l'ID.

4. **`--network $nomeRete`**: Questo flag consente ai contenitori di comunicare tra loro.

5. **`-p 8080:8080`**: Questo flag mappa la porta 8080 del sistema host alla porta 8080 del contenitore. Ciò significa che qualsiasi traffico sulla porta 8080 dell'host verrà inoltrato alla porta 8080 del contenitore.

6. **`--env-file node.env`**: Specifica un file contenente le variabili d'ambiente da passare al contenitore. Il file `node.env` deve essere presente e contenere le variabili d'ambiente in formato `KEY=VALUE`.

7. **`web_node-node`**: Questo è il nome dell'immagine Docker da cui avviare il contenitore. Docker cercherà un'immagine con questo nome localmente o su Docker Hub se l'immagine non è disponibile localmente.

In sintesi, questo comando avvia un contenitore in background basato sull'immagine `web_node-node`, lo nomina `node_web_node_1`, crea un link a un altro contenitore chiamato `node_dbpg_1`, mappa la porta 8080 del contenitore alla porta 8080 dell'host e carica le variabili d'ambiente dal file `node.env`.

