# CI/CD con GitHub Actions

Guida generica per automatizzare test, build e rilascio di un progetto qualsiasi, fino alla creazione della **GitHub Release**. I concetti valgono per qualunque linguaggio; i template sono pronti da copiare.

Per un esempio completo su un progetto vero (Go + Wails, installer Windows e pacchetto Linux) vedi il caso pratico **[Zenith](./zenith/)**.

Il risultato a cui si arriva:

```bash
git tag -a v1.2.0 -m "v1.2.0"
git push origin v1.2.0
# → test, build per ogni OS, checksum, note di rilascio e GitHub Release: tutto automatico
```

## Contenuto della cartella

| Percorso                                              | Cosa contiene                                                         |
| ----------------------------------------------------- | --------------------------------------------------------------------- |
| [`templates/ci-node.yml`](./templates/ci-node.yml)     | CI per Node.js: matrice di versioni, cache npm, lint, test, build     |
| [`templates/ci-python.yml`](./templates/ci-python.yml) | CI per Python: matrice di versioni, cache pip, ruff, pytest           |
| [`templates/ci-go.yml`](./templates/ci-go.yml)         | CI per Go: gofmt, vet, test con race detector                        |
| [`templates/release.yml`](./templates/release.yml)     | Release generica da tag: test → build multi-OS → GitHub Release       |
| [`templates/release-docker.yml`](./templates/release-docker.yml) | Release di un'immagine Docker su `ghcr.io`                  |
| [`zenith/`](./zenith/)                                 | Caso pratico completo su un'app desktop Go + Wails                    |

---

## 1. I concetti

### CI, CD e CD

| Sigla | Significato | In pratica |
| ----- | ----------- | ---------- |
| **CI** — Continuous Integration | Ogni modifica viene compilata e testata in automatico, su una macchina pulita | a ogni push e a ogni pull request |
| **CD** — Continuous Delivery    | Ogni versione è *pronta* per il rilascio; la decisione di rilasciare è umana | crei un tag, la pipeline fa il resto |
| **CD** — Continuous Deployment  | Ogni modifica che passa i test va in produzione da sola | tipico dei servizi web, raro per app e librerie |

Si parte quasi sempre con **CI + Continuous Delivery**: tu decidi *quando* esce una versione, la pipeline decide *come*, sempre nello stesso modo.

### Le fasi di una pipeline

```
commit ──► build ──► test ──► package ──► release ──► deploy
           └───────── CI ─────────┘      └──── CD ─────────┘
```

| Fase      | Domanda a cui risponde                         | Esempi                                           |
| --------- | ---------------------------------------------- | ------------------------------------------------ |
| build     | Il codice compila?                             | `go build`, `npm run build`, `docker build`      |
| test      | Funziona? È scritto bene?                      | test unitari, lint, type check, formattazione    |
| package   | Cosa diamo agli utenti?                        | `.exe`, `.tar.gz`, `.whl`, immagine Docker       |
| release   | Dove lo trovano, con quale versione?           | GitHub Release, npm, PyPI, `ghcr.io`, Docker Hub |
| deploy    | Dove gira?                                     | server via SSH, Kubernetes, servizio cloud       |

### Perché automatizzare

- **Ripetibile**: build sempre da zero su una macchina pulita, niente "sul mio PC funziona".
- **Niente passaggi dimenticati**: versione nel binario, nomi dei file, checksum, note.
- **I test diventano un cancello**: se falliscono, la release non parte.
- **Multi-piattaforma**: Windows, Linux e macOS buildati ognuno sulla sua macchina, in parallelo.

---

## 2. Quali strumenti

I nomi che si incontrano fanno cose diverse. Divisi per categoria:

### Piattaforme CI/CD (eseguono la pipeline)

| Strumento         | Tipo                   | Quando sceglierlo                                                                 |
| ----------------- | ---------------------- | --------------------------------------------------------------------------------- |
| **GitHub Actions**| integrato in GitHub    | Il codice è su GitHub. Gratuito per i repo pubblici, runner Linux/Windows/macOS. **Scelto in questa guida.** |
| GitLab CI/CD      | integrato in GitLab    | Il codice è su GitLab (anche self-hosted). File `.gitlab-ci.yml`, concetti molto simili. |
| Buddy             | SaaS, editor visuale   | Vuoi costruire la pipeline col mouse e collegare più provider Git. Piano gratuito limitato. |
| Jenkins           | self-hosted            | Serve controllo totale o un ambiente aziendale chiuso. Server e plugin da mantenere. |
| CircleCI, Azure Pipelines, Bitbucket Pipelines | SaaS | Alternative valide, di solito scelte per integrazione con l'ecosistema già in uso. |

Regola pratica: **usa la CI del posto dove sta il codice**. Meno integrazioni, meno token da gestire.

### Client Git (NON sono CI/CD)

**GitKraken**, SourceTree, GitHub Desktop, il pannello Git di VS Code: interfacce grafiche per commit, branch, merge e tag. Non eseguono pipeline, ma sono comodi per **creare e pushare il tag** che la avvia (vedi §7).

### Strumenti di release (girano *dentro* la pipeline)

| Strumento                      | Cosa fa                                                                                 |
| ------------------------------ | --------------------------------------------------------------------------------------- |
| `gh` (GitHub CLI)              | Crea release e carica file. Già installato sui runner. **Usato nei template.**          |
| GoReleaser                     | Build, pacchetti e release per progetti Go (senza cgo) in un solo comando.             |
| release-please                 | Apre una PR di release con versione e CHANGELOG calcolati dai commit; al merge crea il tag. |
| semantic-release               | Come sopra ma senza PR: a ogni push su `main` decide e pubblica la versione.            |
| changesets                     | Versioni e changelog per monorepo JavaScript.                                           |

### Dove finiscono i rilasci

| Destinazione          | Per cosa                                      |
| --------------------- | --------------------------------------------- |
| GitHub Releases       | eseguibili, installer, archivi               |
| GitHub Container Registry (`ghcr.io`), Docker Hub | immagini Docker  |
| npm, PyPI, crates.io, pkg.go.dev | librerie dei vari linguaggi   |

---

## 3. Anatomia di un workflow GitHub Actions

Un workflow è un file YAML in `.github/workflows/`. Un repo può averne quanti ne vuoi; ognuno parte per conto suo.

```yaml
name: CI                         # nome mostrato nella scheda Actions

on:                              # TRIGGER: quando parte
  push:
    branches: [main]
  pull_request:

permissions:                     # cosa può fare il token della run (minimo indispensabile)
  contents: read

jobs:
  test:                          # JOB: id libero
    runs-on: ubuntu-24.04        # RUNNER: VM nuova, distrutta a fine job
    steps:                       # STEP: eseguiti in ordine, sulla stessa VM
      - uses: actions/checkout@v7          # ACTION: step riusabile scritto da altri
      - uses: actions/setup-node@v7
        with:                              # parametri dell'action
          node-version: 22
      - run: npm ci                        # comando shell
      - name: Test
        run: npm test

  build:
    needs: test                  # parte solo se "test" è verde; senza needs i job vanno in parallelo
    runs-on: ubuntu-24.04
    steps:
      - run: echo "build..."
```

| Termine      | Cos'è |
| ------------ | ----- |
| **Workflow** | il file `.yml`; uno per scopo (CI, release, deploy…) |
| **Trigger**  | l'evento che lo avvia (`on:`) |
| **Job**      | gruppo di step sulla stessa VM; job diversi = VM diverse, in parallelo salvo `needs:` |
| **Runner**   | la VM: `ubuntu-24.04`, `windows-latest`, `macos-latest`, `ubuntu-24.04-arm`… |
| **Step**     | un comando (`run:`) o un'action (`uses:`) |
| **Action**   | step riusabile pubblicato su GitHub (`owner/repo@versione`) |
| **Artifact** | file salvato da un job per passarlo a un altro, o da scaricare dalla pagina della run |

### Variabili ed espressioni

`${{ ... }}` è un'espressione valutata da GitHub **prima** di eseguire lo step. Le più usate:

| Espressione / variabile                   | Valore di esempio                       |
| ----------------------------------------- | --------------------------------------- |
| `${{ github.ref_name }}` / `$GITHUB_REF_NAME` | `v1.2.0` (tag) oppure `main` (branch) |
| `${{ github.sha }}` / `$GITHUB_SHA`       | hash del commit                          |
| `${{ github.repository }}`                | `alexis-82/progetto`                     |
| `${{ github.token }}`                     | token temporaneo della run (vedi §8)     |
| `${{ secrets.NOME }}`                     | un segreto configurato nel repo          |
| `${{ matrix.os }}`                        | valore corrente della matrice            |
| `${{ steps.<id>.outputs.<nome> }}`        | output di uno step precedente            |

Condizioni su job e step:

```yaml
- name: Solo sui tag
  if: startsWith(github.ref, 'refs/tags/v')
  run: echo "è una release"

- name: Anche se gli step prima sono falliti
  if: always()
  run: echo "pulizia"
```

Ricavare la versione dal tag nella shell:

```bash
TAG="$GITHUB_REF_NAME"      # v1.2.0
VERSION="${TAG#v}"          # 1.2.0
```

---

## 4. Trigger più usati

```yaml
on:
  push:
    branches: [main]            # push su main
    paths-ignore: ["**.md"]     # ...ma non se cambia solo la documentazione
  pull_request:                 # ogni PR (verso qualunque branch)
  push:
    tags: ["v*"]                # push di un tag che inizia per v
  workflow_dispatch:            # pulsante "Run workflow" nella scheda Actions
  schedule:
    - cron: "0 3 * * 1"         # ogni lunedì alle 03:00 UTC
```

> Gli esempi sopra sono separati per chiarezza: in un file vero la chiave `push` compare una volta sola, con `branches` e `tags` insieme se servono entrambi.

**Schema consigliato**: un workflow `ci.yml` su push e pull request, e un workflow `release.yml` separato che parte solo sui tag. Così la CI resta veloce e la release ha i suoi permessi.

---

## 5. La CI: pattern utili

I template [`ci-node.yml`](./templates/ci-node.yml), [`ci-python.yml`](./templates/ci-python.yml) e [`ci-go.yml`](./templates/ci-go.yml) usano tutti questi pattern.

### Setup del linguaggio con cache

Le action `setup-*` installano la versione richiesta e mettono in cache le dipendenze tra una run e l'altra:

```yaml
- uses: actions/setup-node@v7
  with:
    node-version: 22
    cache: npm                  # pnpm, yarn

- uses: actions/setup-python@v7
  with:
    python-version: "3.13"
    cache: pip

- uses: actions/setup-go@v7
  with:
    go-version-file: go.mod     # la versione la decide il progetto, non il workflow
```

Installa le dipendenze in modo riproducibile: `npm ci` (non `npm install`), `pip install -r requirements.txt` con versioni fissate, `go mod download`.

### Matrice: stesso job, più combinazioni

```yaml
strategy:
  fail-fast: false              # se una combinazione fallisce, finisci comunque le altre
  matrix:
    os: [ubuntu-24.04, windows-latest, macos-latest]
    node: [22, 24]
runs-on: ${{ matrix.os }}       # 3 × 2 = 6 job in parallelo
```

Con `include:` si elencano combinazioni esplicite, ognuna con i suoi valori extra (usato in [`release.yml`](./templates/release.yml) per dare un nome a ogni piattaforma).

### Servizi: database per i test

```yaml
jobs:
  test:
    runs-on: ubuntu-24.04
    services:
      postgres:
        image: postgres:17
        env:
          POSTGRES_PASSWORD: test
        ports: ["5432:5432"]
        options: --health-cmd pg_isready --health-interval 5s --health-retries 10
    env:
      DATABASE_URL: postgres://postgres:test@localhost:5432/postgres
    steps:
      - uses: actions/checkout@v7
      - run: npm ci && npm test
```

Il container parte prima degli step e viene distrutto alla fine. I servizi funzionano solo sui runner Linux.

### Annullare le run superate

```yaml
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true      # un nuovo push sullo stesso branch ferma la run precedente
```

Da **non** usare nel workflow di release: una release a metà va lasciata finire.

### Badge nel README del progetto

```markdown
[![CI](https://github.com/<utente>/<repo>/actions/workflows/ci.yml/badge.svg)](https://github.com/<utente>/<repo>/actions/workflows/ci.yml)
```

---

## 6. Versionamento

### Semantic Versioning

La pipeline di release è guidata dai **tag Git** nel formato [SemVer](https://semver.org/lang/it/), con la `v` davanti per convenzione:

```
v MAJOR . MINOR . PATCH [-prerelease]
  1     . 4     . 2
  2     . 0     . 0       -rc.1
```

| Incrementa | Quando                                     | Esempio            |
| ---------- | ------------------------------------------ | ------------------ |
| PATCH      | solo correzioni di bug                      | `v1.4.1 → v1.4.2`  |
| MINOR      | nuove funzionalità compatibili              | `v1.4.2 → v1.5.0`  |
| MAJOR      | cambi incompatibili (API, formato dati…)    | `v1.5.0 → v2.0.0`  |
| `-rc.N`, `-beta.N` | versione di prova, prima di quella stabile | `v2.0.0-rc.1` |

Sotto `v1.0.0` (es. `v0.3.0`) il progetto è considerato instabile: qualunque cosa può cambiare.

### Dove vive la versione

Due strategie, scegline una:

| Strategia | Come funziona | Adatta a |
| --------- | ------------- | -------- |
| **Il tag è la fonte** | Il codice non contiene il numero di versione; la pipeline lo legge dal tag e lo inietta in build (`-ldflags "-X main.version=$TAG"` in Go, variabile d'ambiente, file generato) | eseguibili, app, immagini Docker |
| **Il file è la fonte** | La versione sta in `package.json`, `pyproject.toml`, `Cargo.toml`; si aggiorna il file, si committa, poi si tagga | librerie pubblicate su npm/PyPI |

Con la seconda strategia conviene un controllo nella pipeline che fermi la release se tag e file non coincidono:

```bash
# Node: il tag v1.2.0 deve corrispondere a "version": "1.2.0"
test "${GITHUB_REF_NAME#v}" = "$(node -p 'require("./package.json").version')"
```

### Messaggi di commit e note di rilascio

Le note di rilascio si possono ricavare dai commit, quindi conviene scriverli leggibili. Lo standard più diffuso è [Conventional Commits](https://www.conventionalcommits.org/it/):

```
feat: esportazione in CSV
fix: crash all'avvio senza file di configurazione
docs: istruzioni per macOS
chore: aggiornamento dipendenze
feat!: nuovo formato del file di configurazione    ← "!" = cambio incompatibile → MAJOR
```

Oltre a dare note pulite, è il formato che strumenti come release-please leggono per calcolare la versione successiva da soli.

---

## 7. La release: pipeline guidata dai tag

Il template [`templates/release.yml`](./templates/release.yml) implementa questo flusso:

```mermaid
flowchart LR
    tag([git push tag v1.2.0]) --> test
    test --> bl[build linux]
    test --> bw[build windows]
    test --> bm[build macos]
    bl --> rel[release<br/>checksum + note + gh release]
    bw --> rel
    bm --> rel
    rel --> gh[(GitHub Release)]
```

**Funziona già così com'è**: al posto della build vera produce un file di testo per ogni piattaforma. È il modo più veloce per vedere il giro completo su un repo di prova, poi si sostituiscono i blocchi `TODO`.

### I passaggi, uno per uno

**1. Trigger sui tag**

```yaml
on:
  push:
    tags: ["v*"]
```

**2. Test come cancello.** Il job `test` ripete i controlli della CI. Non è ridondante: un tag si può creare su un commit che non è mai passato dalla CI. Tutti gli altri job hanno `needs: test` (direttamente o a catena).

**3. Build per piattaforma**, in parallelo, con una matrice:

```yaml
strategy:
  matrix:
    include:
      - { os: ubuntu-24.04,   target: linux-amd64 }
      - { os: windows-latest, target: windows-amd64 }
      - { os: macos-latest,   target: macos-arm64 }
runs-on: ${{ matrix.os }}
```

Ogni build scrive i suoi file in `dist/` e li salva come artifact:

```yaml
- uses: actions/upload-artifact@v7
  with:
    name: ${{ matrix.target }}
    path: dist/*
    if-no-files-found: error    # se la build non produce niente, fallisce subito
```

Se il progetto non ha binari per OS (es. una web app o uno script Python) basta **un solo job di build** senza matrice.

**4. Raccolta e checksum.** Il job `release` scarica tutti gli artifact in una cartella sola e calcola gli SHA-256:

```yaml
- uses: actions/download-artifact@v8
  with:
    path: dist
    merge-multiple: true
- run: cd dist && sha256sum * > SHA256SUMS.txt
```

Chi scarica può verificare con `sha256sum -c SHA256SUMS.txt`. GitHub calcola inoltre in automatico il digest SHA-256 di ogni file caricato in una release.

**5. Note di rilascio.** Tre modi, dal più semplice:

| Metodo | Comando | Note |
| ------ | ------- | ---- |
| Generate da GitHub | `gh release create … --generate-notes` | Elenca le **pull request** unite. Se lavori con push diretti su `main` esce quasi vuota. |
| Dai commit | `git log --pretty='- %s' vPRECEDENTE..vATTUALE` | Usato nel template. Richiede `fetch-depth: 0` nel checkout. |
| Dal messaggio del tag | `gh release create … --notes-from-tag` | Scrivi le note in `git tag -a v1.2.0 -m "..."` |
| Da un `CHANGELOG.md` | estrarre la sezione della versione | Il più curato, va mantenuto a mano o con release-please. |

**6. Creazione della release** con `gh`, già presente sui runner:

```bash
gh release create "$GITHUB_REF_NAME" dist/* \
  --title "$GITHUB_REF_NAME" \
  --notes-file notes.md \
  --verify-tag            # non creare un tag nuovo se quello indicato non esiste
```

Opzioni utili: `--prerelease` (il template la aggiunge da solo se il tag contiene un trattino, es. `v2.0.0-rc.1`), `--draft` (release nascosta da pubblicare a mano dopo un controllo), `--latest=false`.

Il job ha bisogno del permesso di scrittura, dato **solo a lui**:

```yaml
release:
  permissions:
    contents: write
```

### Variante: immagine Docker

Se il "prodotto" è un'immagine, il template [`templates/release-docker.yml`](./templates/release-docker.yml) la builda e la pubblica su GitHub Container Registry a ogni tag:

```
git tag v1.2.3  →  ghcr.io/<utente>/<repo>:1.2.3
                   ghcr.io/<utente>/<repo>:1.2
                   ghcr.io/<utente>/<repo>:latest
```

Il login usa il token della run (`packages: write`), quindi non servono segreti. Le immagini appaiono nella sezione **Packages** del profilo; la prima volta sono private, la visibilità si cambia dalle impostazioni del package.

---

## 8. Segreti e sicurezza

### `GITHUB_TOKEN`

Ogni run riceve un token temporaneo (`${{ github.token }}` o `${{ secrets.GITHUB_TOKEN }}`) valido solo per quel repo e per la durata della run. Basta per creare release, pubblicare su `ghcr.io`, commentare PR. I suoi permessi si dichiarano nel workflow:

```yaml
permissions:
  contents: read        # default per tutto il workflow

jobs:
  release:
    permissions:
      contents: write   # alzati solo dove servono
```

### Segreti propri

Per tutto il resto (token npm/PyPI, chiave SSH di un server, credenziali cloud): **Settings → Secrets and variables → Actions → New repository secret**, poi:

```yaml
- run: npm publish
  env:
    NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}
```

- GitHub oscura i segreti nei log (`***`), ma non stamparli comunque e non scriverli su file che finiscono negli artifact.
- I workflow avviati da **pull request di fork** non ricevono i segreti: è voluto, il codice di una PR esterna non è fidato.
- Dove possibile preferisci **OIDC** ai segreti a lunga durata: per PyPI (*trusted publishing*), AWS, Azure e GCP il workflow ottiene credenziali temporanee senza salvare nessuna chiave.

### Environments: approvazione prima del deploy

**Settings → Environments → New environment** (es. `production`), con *Required reviewers*. Un job che dichiara

```yaml
deploy:
  environment: production
```

si ferma e aspetta l'approvazione di un revisore prima di partire, e solo lui vede i segreti di quell'environment.

### Fidarsi delle action di terze parti

`uses: owner/action@v7` esegue codice di altri con accesso al tuo token. Regole minime:

- preferisci action ufficiali (`actions/*`, `docker/*`) o molto diffuse;
- per le altre, fissa il commit invece del tag (i tag si possono spostare):
  ```yaml
  - uses: owner/action@3f1c2b9e8d7a6f5e4d3c2b1a0f9e8d7c6b5a4f3e  # v2.1.0
  ```
- **Dependabot** (§11) tiene aggiornate le versioni delle action con delle PR.

---

## 9. Mettere in piedi la pipeline su un progetto

Una volta sola, su ogni progetto nuovo.

```bash
cd mio-progetto
mkdir -p .github/workflows

# 1. CI: scegli il template del linguaggio
cp ../guide_devops/cicd/templates/ci-node.yml .github/workflows/ci.yml

# 2. Release
cp ../guide_devops/cicd/templates/release.yml .github/workflows/release.yml
```

Poi:

1. **Adatta la CI** e falla diventare verde: commit, push, controlla la scheda **Actions**. Finché la CI è rossa non ha senso andare avanti.
2. **Prova la release a vuoto**: lascia `release.yml` com'è (con i file di testo), crea un tag `v0.0.1-test.1` e verifica che la pre-release compaia. Poi cancellala (§10).
3. **Sostituisci i `TODO`** con test e build veri del progetto. Controlla in locale i comandi prima di metterli nel workflow.
4. **Decidi i nomi dei file** rilasciati e non cambiarli più: script di installazione, updater o link nella documentazione possono dipendere da quei nomi.
5. **Prima release vera.**

Impostazioni del repo (**Settings → Actions → General**): *Workflow permissions* può restare su "Read repository contents"; i job che devono scrivere lo chiedono con `permissions:`.

---

## 10. Procedura di rilascio

Ogni volta che vuoi pubblicare una versione.

```bash
# 1. main aggiornato e CI verde
git switch main
git pull
gh run list --workflow ci.yml --limit 1

# 2. Cosa è cambiato dall'ultima versione → scegli il numero (§6)
git describe --tags --abbrev=0                # ultimo tag, es. v1.1.0
git log --oneline v1.1.0..HEAD

# 3. Tag annotato + push: è questo che avvia la release
git tag -a v1.2.0 -m "v1.2.0"
git push origin v1.2.0

# 4. Segui la pipeline e controlla il risultato
gh run watch
gh release view v1.2.0
```

**Con un client grafico** (GitKraken, GitHub Desktop, VS Code) il passo 3 è: tasto destro sul commit → *Create tag* (annotato) → nome `v1.2.0` → *Push tag to origin*. Il resto non cambia.

**Rifare una release** (tag sbagliato, build da correggere):

```bash
gh release delete v1.2.0 --yes          # cancella la release e i file allegati
git push origin :refs/tags/v1.2.0       # cancella il tag su GitHub
git tag -d v1.2.0                       # cancella il tag locale
# correggi, committa, ricrea il tag (passo 3)
```

> Cancellare e ricreare un tag va bene solo se la release è stata pubblica per poco. Se qualcuno può averla già scaricata, pubblica la versione successiva (`v1.2.1`).

### Debug

| Problema                                       | Cosa fare                                                                 |
| ---------------------------------------------- | ------------------------------------------------------------------------- |
| Errore temporaneo (rete, registry, apt)        | Scheda Actions → run → **Re-run failed jobs**: non serve rifare il tag    |
| Log poco chiari                                | **Re-run jobs → Enable debug logging**, oppure segreto `ACTIONS_STEP_DEBUG=true` |
| Il workflow non parte                          | file non in `.github/workflows/`, YAML non valido, tag che non rispetta il pattern di `on.push.tags` |
| `Resource not accessible by integration`       | manca un permesso nel blocco `permissions:` (es. `contents: write`)       |
| Le note contengono un solo commit              | manca `fetch-depth: 0` nel checkout: senza storia e tag non trova il tag precedente |
| Funziona in locale ma non sul runner           | dipendenze di sistema mancanti, path Windows, variabili d'ambiente locali |
| Provare il workflow senza pushare              | [`act`](https://github.com/nektos/act) esegue i job Linux in locale con Docker (non è identico al runner) |

---

## 11. Passi successivi

1. **Branch protection** (Settings → Branches → *Require status checks*): niente merge su `main` senza CI verde.
2. **Dependabot** — file `.github/dependabot.yml` con un blocco per ogni ecosistema (`npm`, `pip`, `gomod`, `docker`, e `github-actions` per le action stesse): PR automatiche per gli aggiornamenti.
3. **release-please**: versione e CHANGELOG calcolati dai Conventional Commits; il tag lo crea lui al merge della PR di release, e la pipeline del §7 parte come sempre.
4. **Firma del codice**: installer Windows (`signtool`) e app macOS (notarizzazione) non firmati mostrano avvisi agli utenti. Il certificato va nei segreti del repo.
5. **Deploy continuo** per i servizi: un job `deploy` dopo la release, con `environment: production`, che aggiorna il server (SSH + `docker compose pull && docker compose up -d`) o il cluster Kubernetes.

---

## Riferimenti

- GitHub Actions: <https://docs.github.com/actions>
- Sintassi dei workflow: <https://docs.github.com/actions/reference/workflow-syntax-for-github-actions>
- Contesti ed espressioni: <https://docs.github.com/actions/reference/contexts-reference>
- `gh release create`: <https://cli.github.com/manual/gh_release_create>
- Docker build-push-action: <https://github.com/docker/build-push-action>
- Semantic Versioning: <https://semver.org/lang/it/>
- Conventional Commits: <https://www.conventionalcommits.org/it/>
- release-please: <https://github.com/googleapis/release-please>
- act: <https://github.com/nektos/act>
