![flag](https://raw.githubusercontent.com/stevenrskelton/flag-icon/master/png/16/country-4x3/it.png)
# Documentazione Docker con Flask

## Descrizione del Progetto

In questo progetto, utilizziamo Docker per gestire i nostri contenitori e le nostre immagini. Docker è una piattaforma open-source che semplifica la creazione, la distribuzione e l'esecuzione di applicazioni all'interno di contenitori.

## Procedura creazione immagine con container
⚠️ Bisogna avere già installato python3 con pip

Installiamo virtualenv:
```
pip install virtualenv
```
Entrare in ambiente venv in Linux:
```
virtualenv venv
```
Entrare in ambiente venv in Windows:
```
python -m virtualenv venv
```
Attiviamo l'ambiente env per Linux:
```
cd venv/local/bin
source activate
```
Per Windows10/11:
```
cd venv
./Script/activate
```
Installazione di Flask:
```
pip install flask
```
Generiamo il file requirements.txt direttamente dal venv:
```
pip freeze > requirements.txt
```
Controlliamo se il codice di app.py funziona, possiamo utilizzare anche nodemon:
```
python3 app.py
```
oppure
```
nodemon app.py
```
Costruiamo la nostra immagine tramite la lettura del file Dockerfile:
```
docker build -t myapp .
```
Ora possiamo avviare la nostra immagine con il container tramite il comando:
```
docker run -it --name myapp.container -p 3200:3200 myapp
```
- myapp.container = possiamo dare qualsiasi nome al nostro container


---
![flag](https://raw.githubusercontent.com/stevenrskelton/flag-icon/master/png/16/country-4x3/gb.png)

# Docker Documentation with Flask

## Project Description

In this project, we use Docker to manage our containers and images. Docker is an open-source platform that simplifies the creation, distribution, and execution of applications within containers.

## Procedure for Creating Image with Container
⚠️ Python3 with pip must be installed beforehand.

Install virtualenv:
```
pip install virtualenv
```
Enter venv environment in Linux:
```
virtualenv venv
```
Enter venv environment in Windows:
```
python -m virtualenv venv
```
Activate the environment env for Linux:
```
cd venv/bin
source activate
```
For Windows 10/11:
```
cd venv
./Script/activate
```

Install Flask:
```
pip install flask
```
Generate the requirements.txt file directly from venv:
```
pip freeze > requirements.txt
```
Check if the app.py code works, we can also use nodemon:
```
python3 app.py
```
or
```
nodemon app.py
```
Build our image by reading the Dockerfile:
```
docker build -t myapp .
```
Now we can start our image with the container using the command:
```
docker run -it --name myapp.container -p 3200:3200 myapp
```
myapp.container = we can give any name to our container




