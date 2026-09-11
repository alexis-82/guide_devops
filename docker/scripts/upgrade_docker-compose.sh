#!/bin/bash

# Controllo se jq è installato
if ! command -v jq &> /dev/null
then
    echo "Il pacchetto 'jq' non è installato nel sistema."
    echo "Per installarlo, esegui il seguente comando:"
    echo "sudo apt update && sudo apt install -y jq"
    echo "Dopo l'installazione, riavvia questo script."
    exit 1
fi

# Aggiornamento automatico di docker-compose
echo
echo -e "Aggiornamento automatico di docker-compose"
echo
sleep 5

# Verifica della versione
versione_attuale=$(docker-compose version | grep version | awk '{print $4}')
echo "Versione attuale di docker-compose: $versione_attuale"

# Download dell'ultima versione (se necessario)
versione_ultima=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq '.tag_name' | sed 's/"//g')
echo "Versione ultima di docker-compose: $versione_ultima"

if [ "$versione_attuale" != "$versione_ultima" ]; then
  # Poni la domanda all'utente
  echo "Vuoi aggiornare docker-compose alla versione $versione_ultima? (si/no)"
  read -p "Risposta: " risposta

  # Controlla la risposta dell'utente
  if [ "$risposta" == "si" ] || [ "$risposta" == "s" ]; then
    # Se l'utente risponde "si", aggiorna docker-compose
    echo "Rimozione di docker-compose in corso..."
    sudo rm $(which docker-compose)
    echo "Docker-compose rimosso."
    sleep 5
    echo "Aggiornamento di docker-compose in corso..."
    sleep 5
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    sleep 5
    echo "Aggiornamento completato!"
  elif [ "$risposta" == "no" ] || [ "$risposta" == "n" ]; then
    # Se l'utente risponde "no", esci dallo script
    sleep 3
    echo
    echo "Operazione annullata."
    exit 0
  fi
fi

# Messaggio di chiusura
sleep 3
echo
echo "Operazione completata!"
echo