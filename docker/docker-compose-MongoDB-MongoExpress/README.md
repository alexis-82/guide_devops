# MongoDB e Mongo Express Setup

Questa configurazione crea un ambiente Docker con MongoDB e Mongo Express, utilizzando una rete macvlan per assegnare indirizzi IP statici ai container.

## Docker Compose (`docker-compose.yml`)

Il file `docker-compose.yml` definisce due servizi:

1. **MongoDB**
   - Immagine: `mongo`
   - Porta: 27017
   - IP statico: 192.168.1.195
   - Volume: `./mongo-data:/data/db`
   - Variabili d'ambiente: definite in `mongo.env`

2. **Mongo Express**
   - Immagine: `mongo-express`
   - Porta: 8081
   - IP statico: 192.168.1.194
   - Dipende da: MongoDB
   - Variabili d'ambiente: definite in `mongo-express.env`

La rete `my_macvlan_network` è configurata come macvlan, utilizzando l'interfaccia `ens32` e la subnet 192.168.1.0/24.

## Variabili d'ambiente

### MongoDB (`mongo.env`)
- Username root: admin
- Password root: password

### Mongo Express (`mongo-express.env`)
- Username per accesso web: root
- Password per accesso web: admin
- Credenziali admin MongoDB: admin/password
- Server MongoDB: mongodb

## Note di sicurezza
- Le password utilizzate in questo esempio sono deboli e dovrebbero essere sostituite con password forti in un ambiente di produzione.
- L'accesso a MongoDB e Mongo Express dovrebbe essere limitato in base alle necessità di sicurezza del tuo ambiente.