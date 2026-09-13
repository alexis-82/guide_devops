# Terraform — Cheatsheet comandi base

Raccolta ragionata dei comandi `terraform` più usati nel lavoro quotidiano con progetti Infrastructure as Code. Testato su Terraform v1.16 con provider AWS.

---

## Indice

- [Ciclo di vita giornaliero](#ciclo-di-vita-giornaliero)
- [Init e provider](#init-e-provider)
- [Plan e apply avanzati](#plan-e-apply-avanzati)
- [Formattazione e validazione](#formattazione-e-validazione)
- [Ispezione stato e output](#ispezione-stato-e-output)
- [Manipolazione stato](#manipolazione-stato)
- [Distruzione risorse](#distruzione-risorse)

---

## Ciclo di vita giornaliero

I comandi che userai in ogni sessione di lavoro, nell'ordine tipico di esecuzione.

```bash
# Inizializza la cartella di lavoro: scarica provider, moduli, crea .terraform/
# Da eseguire la prima volta o dopo aver modificato required_providers/backend
terraform init

# Formatta i file .tf secondo lo stile canonico HashiCorp (2 spazi, allineamento =)
terraform fmt

# Controlla sintassi HCL e coerenza dei riferimenti (non contatta AWS, richiede init)
terraform validate

# Anteprima delle modifiche: confronta .tf vs .tfstate vs realtà su cloud
# Nessuna modifica applicata — solo lettura
terraform plan

# Applica le modifiche: rimostra il plan e chiede conferma con "yes"
terraform apply

# Distrugge tutta l'infrastruttura gestita in questa cartella (chiede conferma)
terraform destroy
```

---

## Init e provider

```bash
# Init "normale" (prima volta nel progetto)
terraform init

# Forza il download della versione più recente dei provider consentita da required_providers
terraform init -upgrade

# Reinizializza dopo migrazione backend (es. da locale a S3): migra automaticamente lo state
terraform init -migrate-state

# Reinizializza SENZA migrare lo state (utile se vuoi partire da zero su nuovo backend)
terraform init -reconfigure

# Mostra la versione di Terraform installata e dei provider
terraform version
```

---

## Plan e apply avanzati

Il ciclo `plan → apply` di base copre il 90% dei casi. Le varianti sotto servono per pipeline CI/CD, applicazioni parziali e ambienti multipli.

```bash
# Salva il piano su file per applicarlo in seguito (es. plan su PR, apply su merge)
terraform plan -out=piano.tfplan

# Applica un piano salvato — NON richiede conferma (già validato quando è stato generato)
terraform apply piano.tfplan

# Salta la conferma interattiva (utile in script CI/CD, ⚠️ pericoloso in prod)
terraform apply -auto-approve

# Passa una variabile inline (sovrascrive default e .tfvars)
terraform apply -var="instance_type=t3.small"

# Carica variabili da file specifico
terraform apply -var-file=prod.tfvars

# Limita l'operazione a una singola risorsa (utile in debug, ⚠️ crea drift dallo state completo)
terraform apply -target=aws_instance.app_server

# Forza la ricreazione di una risorsa senza toccare le altre (sostituisce il vecchio `taint`)
terraform apply -replace=aws_instance.app_server

# Solo aggiornamento dello stato con la realtà su cloud, nessuna modifica alle risorse
terraform apply -refresh-only
```

---

## Formattazione e validazione

```bash
# Formatta tutti i .tf nella cartella corrente
terraform fmt

# Scende ricorsivamente anche nelle sottocartelle (utile con moduli locali)
terraform fmt -recursive

# Non modifica i file, esce con codice ≠ 0 se qualcosa sarebbe cambiato (per CI)
terraform fmt -check

# Valida sintassi HCL e riferimenti (richiede terraform init già eseguito)
terraform validate

# Apre una REPL interattiva per valutare espressioni HCL contro lo state
# Esci con exit o Ctrl+D
terraform console
```

---

## Ispezione stato e output

Comandi in sola lettura per capire cosa Terraform sta gestendo. Fondamentali per debug e passaggi di consegna.

```bash
# Mostra il contenuto completo dello state in forma leggibile
terraform show

# Mostra il contenuto di un plan salvato
terraform show piano.tfplan

# Elenca tutte le risorse presenti nello state (primo comando quando entri in un progetto)
terraform state list

# Mostra i dettagli di una singola risorsa dello state
terraform state show aws_instance.app_server

# Mostra tutti gli output definiti nel progetto
terraform output

# Mostra un singolo output
terraform output instance_public_ip

# Output "raw" senza virgolette, comodo per pipe/copia (es. usare in ssh)
terraform output -raw ssh_command

# Formato JSON per script/parsing
terraform output -json

# Genera il grafo delle dipendenze in formato DOT (richiede graphviz per il rendering)
terraform graph | dot -Tpng > grafo.png
```

---

## Manipolazione stato

⚠️ **Attenzione**: questi comandi modificano lo state file. Fai sempre un backup (`cp terraform.tfstate terraform.tfstate.backup`) prima di eseguirli, e in team assicurati che nessun altro stia applicando.

```bash
# Rimuove una risorsa dallo state SENZA distruggerla su cloud
# Utile quando vuoi "dimenticarla" (es. ora gestita da altro tool)
terraform state rm aws_instance.app_server

# Rinomina una risorsa nello state (evita distruggi+ricrea quando cambi nome nel .tf)
terraform state mv aws_instance.old_name aws_instance.new_name

# Sposta una risorsa dentro un modulo
terraform state mv aws_instance.app_server module.web.aws_instance.app_server

# Porta sotto gestione Terraform una risorsa esistente su cloud ma non nello state
# ⚠️ Devi comunque scrivere il blocco resource nel .tf a mano
terraform import aws_instance.esistente i-0abc123def456

# Sblocca lo state (⚠️ solo se sei SICURO che nessun altro sta applicando)
# LOCK_ID lo trovi nel messaggio di errore
terraform force-unlock LOCK_ID
```

**Alternativa dichiarativa al state mv**: dalla 1.1 in poi, usa il blocco `moved` direttamente nel `.tf` — resta committato nel repo:

```hcl
moved {
  from = aws_instance.old_name
  to   = aws_instance.new_name
}
```

---

## Distruzione risorse

⚠️ **Attenzione**: `destroy` è irreversibile. Verifica sempre di essere nella cartella giusta con `pwd` e nell'ambiente giusto controllando `terraform workspace show` o la chiave del backend.

```bash
# Distrugge TUTTE le risorse gestite dal progetto corrente (chiede conferma)
terraform destroy

# Salta la conferma (⚠️ MAI in prod senza salvaguardie)
terraform destroy -auto-approve

# Distrugge solo una risorsa specifica (le altre restano)
terraform destroy -target=aws_instance.app_server

# Anteprima di cosa verrebbe distrutto, senza eseguire
terraform plan -destroy
```

**Alternativa più pulita per ambienti effimeri**: usa una cartella dedicata per gli esperimenti con backend state separato, così un `destroy` colpisce solo quell'ambiente.

```bash
# Struttura consigliata
envs/
├── dev/       # terraform destroy qui non tocca prod
├── staging/
└── prod/

# Distruzione mirata a un solo environment
cd envs/dev && terraform destroy
```