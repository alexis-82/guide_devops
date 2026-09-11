
Descrizione:
Per configurare Docker Compose con MySQL e phpMyAdmin, crea un file docker-compose.yml nella tua directory di progetto. Questo file definirà due servizi: un database MySQL e un'interfaccia phpMyAdmin. Configura le porte, le variabili d'ambiente e i volumi per ciascun servizio. Usa file .env separati per gestire le credenziali in modo sicuro. Assicurati che i servizi siano sulla stessa rete Docker per comunicare tra loro. Dopo aver creato il file, usa i comandi Docker Compose per avviare, fermare e gestire i tuoi container.


# Configurazione di Docker Compose con MySQL e phpMyAdmin

## Prerequisiti

-   Docker e Docker Compose V2 installati sul tuo sistema
-   Conoscenza base di YAML e Docker

## Passi per la configurazione

1. **Crea il file docker-compose.yml**

    Nella tua directory di progetto, crea un file chiamato `docker-compose.yml` con il seguente contenuto:

```yaml
services:
  db:
    image: mysql:latest
    restart: always
    env_file:
      - ./mysql.env
    volumes:
      - ./mysql_data:/var/lib/mysql
    ports:
      - "3306:3306"

  phpmyadmin:
    image: phpmyadmin/phpmyadmin:latest
    restart: always
    depends_on:
      - db
    env_file:
      - ./phpmyadmin.env
    ports:
      - "8080:80"
```

2. **Crea i file .env**

    Crea un file `mysql.env` e nella stessa directory con le seguenti variabili:

    ```
    MYSQL_DATABASE=dbname
    MYSQL_USER=user
    MYSQL_PASSWORD=password
    MYSQL_ROOT_PASSWORD=admin
    ```

    Crea un file `phpmyadmin.env` e nella stessa directory:

    ```
    # Impostazioni di phpMyAdmin
    PMA_HOST: db
    PMA_PORT: 3306
    PMA_ARBITRARY: 1
    UPLOAD_LIMIT=300M
    MEMORY_LIMIT=512M

    # Lingua di default (opzionale)
    PMA_LANGUAGE=italian

    # Tema di default (opzionale)
    PMA_THEME=pmahomme
    ```

3. **Avvia i container**

    Esegui il seguente comando nella directory del progetto:

    ```
    docker compose up -d
    ```

4. **Accedi a phpMyAdmin**

    Apri un browser e vai a: `http://localhost:8080`  

    oppure prima visualizza i container avviati:

    ```bash
    docker compose ps
    ```

    e esegui da terminale:

    ```bash
    docker exec -it docker-compose-mysql-phpmyadmin-db-1 mysql -u user -p
    ```

    oppure:

    ```bash
    docker exec -it docker-compose-mysql-phpmyadmin-db-1 mysql -u user -p -h <indirizzo_IP>

    ```

6. **Ferma i container**

    Quando hai finito, puoi fermare i container con:

    ```
    docker compose down
    ```
