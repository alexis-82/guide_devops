# MySQL con database Northwind

## Avvio

```bash
# Crea il file di variabili partendo dal modello (e cambia le password)
cp mysql.env.example mysql.env

# La rete macvlan è dichiarata come external: va creata una volta sola
# (adatta subnet, gateway e interfaccia alla tua LAN)
docker network create -d macvlan \
  --subnet=192.168.1.0/24 --gateway=192.168.1.1 \
  -o parent=ens32 my_macvlan_network

docker compose up -d
```

Al primo avvio il file `database-northwind` viene montato in `/docker-entrypoint-initdb.d/init.sql` e crea il database `Northwind` con dati di esempio. Lo script di init viene eseguito solo se `./database/data` è vuota.

## Verifica

Per connetterti al database MySQL nel tuo container e verificare che funzioni correttamente, puoi seguire questi passaggi:

1. Accedi al container MySQL:

   ```bash
   docker exec -it nome_container_mysql bash
   ```
   
   Sostituisci `nome_container_mysql` con il nome effettivo del tuo container MySQL. Puoi trovare il nome del container con il comando `docker ps`.

2. Una volta dentro il container, connettiti a MySQL:

   ```bash
   mysql -u root -p
   ```

   Inserisci la password di root quando richiesto (quella che hai impostato in `MYSQL_ROOT_PASSWORD` nel file `mysql.env`).

3. Verifica i database disponibili:

   ```sql
   SHOW DATABASES;
   ```

   Dovresti vedere il database `Northwind` nell'elenco.

4. Seleziona il database:

   ```sql
   USE Northwind;
   ```

5. Verifica le tabelle nel database:

   ```sql
   SHOW TABLES;
   ```

   Dovresti vedere le tabelle di Northwind (`Customers`, `Orders`, `Products`, ...).

6. Esegui una query di prova:

   ```sql
   SELECT * FROM Customers LIMIT 10;
   ```

   Questo mostrerà i primi 10 clienti del database di esempio.

Metodo alternativo usando docker exec direttamente:

Se preferisci non entrare nel container, puoi eseguire comandi MySQL direttamente dalla tua macchina host:

```bash
docker exec -it nome_container_mysql mysql -uroot -p Northwind
```

Questo comando ti connetterà direttamente al database `Northwind` nel container MySQL.

Se hai ancora problemi, controlla i log del container MySQL:

```bash
docker logs nome_container_mysql
```