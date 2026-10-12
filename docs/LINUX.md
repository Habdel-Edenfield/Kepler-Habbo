# Running Kepler on Linux (server + client)

This guide takes a clean Linux machine to a working v14 hotel: the server
runs, the database is imported, the client opens in a browser, you register,
become an administrator, enter a room and chat.

Tested on Ubuntu 26.04 (x86_64) with Docker 29 / Compose 2.40, Firefox and
Chrome. *Portuguese version: [LINUX.pt-BR.md](LINUX.pt-BR.md).*

## How it fits together

```
 Browser (Firefox/Chrome)
   │  page + DCRs ──────────────► client-web      nginx         :8087
   │  game socket (WebSocket) ──► client-ws-game  websockify    :12331 ─┐
   │  MUS socket  (WebSocket) ──► client-ws-mus   websockify    :12332 ─┤ TCP
   │                                                                    ▼
   │                              kepler          Java server   :12321 / :12322
   │                                                                    │
   │                              kepler-mariadb  MariaDB 11.4  (internal only)
```

- Everything runs in Docker containers. You do **not** need Java or MariaDB
  installed on the machine: the image compiles Kepler with its own JDK, and the
  database lives in its own container and volume (`kepler-mariadb`). It does not
  publish port 3306, so it does not clash with a MariaDB already on the host.
- The v14 client is Shockwave, which never had a Linux player, and Adobe stopped
  distributing it in 2019. The client runs in
  [DirPlayer](https://github.com/igorlira/dirplayer-rs), an open-source Shockwave
  emulator (Rust/WebAssembly). Browsers cannot open raw TCP sockets, so the
  client's connections go through `websockify`, which turns WebSocket back
  into TCP for Kepler.
- The client files (Sulake DCRs, from
  [Kepler-www](https://github.com/Quackster/Kepler-www)) and DirPlayer are
  downloaded by a script into `client/`, which is ignored by Git.

## 1. Install the requirements

Debian/Ubuntu:

```bash
sudo apt update
sudo apt install docker.io docker-compose-v2 git curl unzip
sudo usermod -aG docker "$USER"
```

Log out and back in, so your user can run `docker` without `sudo`. Check:

```bash
docker compose version
```

Other distributions: install Docker Engine with the Compose plugin
(<https://docs.docker.com/engine/install/>), plus `git`, `curl` and `unzip`.

## 2. Check that the ports are free

| Port  | Used by                         |
|-------|---------------------------------|
| 12321 | Kepler game server              |
| 12322 | Kepler MUS (camera)             |
| 8087  | Client web files                |
| 12331 | WebSocket bridge for the game   |
| 12332 | WebSocket bridge for MUS        |

```bash
ss -ltn | grep -E ':(12321|12322|8087|12331|12332)\b' || echo "all free"
```

If one is taken, pick another number in `.env` (step 4).

## 3. Get the code

The Linux files (`compose.client.yml`, `tools/linux/`) currently live in the
`linux-setup` branch of this fork:

```bash
git clone -b linux-setup https://github.com/Habdel-Edenfield/Kepler-Habbo.git kepler
cd kepler
```

## 4. Configure

```bash
cp .env.example .env
```

Edit `.env` and change at least `MYSQL_PASSWORD` and `MARIADB_ROOT_PASSWORD`.
To generate random values:

```bash
sed -i "s/^MYSQL_PASSWORD=.*/MYSQL_PASSWORD=$(openssl rand -hex 16)/; s/^MARIADB_ROOT_PASSWORD=.*/MARIADB_ROOT_PASSWORD=$(openssl rand -hex 16)/" .env
```

Optional: add this line to `.env` so every `docker compose` command also
manages the client containers (then you can drop the `-f ... -f ...` below):

```
COMPOSE_FILE=compose.yml:compose.client.yml
```

Notes:

- `PUBLISH_IP=127.0.0.1` keeps every port reachable only from this computer.
  Use `0.0.0.0` to let other machines connect, and then also set
  `CLIENT_SERVER_HOST` to this machine's IP or host name.
- Do not change `MYSQL_HOSTNAME` or `MYSQL_PORT`; they point to the database
  container.

## 5. Start the server and the database

```bash
docker compose up -d --build
```

The first build downloads Gradle and the libraries and takes a few minutes.
The database imports `tools/kepler.sql` automatically on its first start.

Check:

```bash
docker compose ps
docker logs kepler
```

Both containers should be `healthy`, and the log should end with
`Game server is listening on 0.0.0.0:12321`.

## 6. Prepare and start the client

```bash
./tools/linux/setup-client.sh
docker compose -f compose.yml -f compose.client.yml up -d --build
```

The script downloads about 70 MB (Kepler-www and DirPlayer, pinned versions
checked with SHA-256) into `client/`. Run it again whenever you change ports
or `CLIENT_SERVER_HOST` in `.env`.

## 7. Play

1. Open <http://localhost:8087/> in Firefox or Chrome. The Sulake loader
   appears, then the hotel view with the login box (about 20 seconds the
   first time).
2. Click **"You can create one here"** and follow the registration. On the
   terms page, scroll the text to the bottom before ticking the box. The
   password must be 6 to 10 characters.
3. At the end you land in the hotel with the Navigator open.

## 8. Become an administrator

Set your user's `rank` to 7 (replace `YourName`):

```bash
docker exec kepler-mariadb sh -c 'mariadb -ukepler -p"$MYSQL_PASSWORD" kepler -e "UPDATE users SET \`rank\` = 7 WHERE username = \"YourName\""'
```

The rank is read at login: reload the page and log in again. To check, enter
a room and type `:coords` in the chat. Only administrators get a window
with the coordinates.

## Everyday commands

```bash
docker compose -f compose.yml -f compose.client.yml stop      # stop everything
docker compose -f compose.yml -f compose.client.yml start     # start again
docker compose -f compose.yml -f compose.client.yml down      # remove containers (data is kept)
docker logs -f kepler                                         # follow the server log
```

Reset the database (deletes all users and rooms):

```bash
docker compose -f compose.yml -f compose.client.yml down
docker volume rm kepler-mariadb
docker compose -f compose.yml -f compose.client.yml up -d
```

After changing Java code, rebuild the server with
`docker compose up -d --build kepler`.

## Troubleshooting

- **"port is already allocated"**: another program uses that port. Change it
  in `.env`, re-run `./tools/linux/setup-client.sh` if it is a client port, and
  start again.
- **Login box appears but nothing happens when you click**: check that the
  bridges are running and receive the connection:
  `docker logs kepler-client-ws-game` should show `connecting to: kepler:12321`,
  and `docker logs kepler` should show `Connection from ...`.
- **Typed text shows up late or jumbled**: wait until the hotel view has fully
  loaded before typing in the login box; the emulator can take a moment after
  the page first appears.
- **Rank 7 does not work**: log out and back in; the rank is only read at login.
- **Graphics glitches** (black boxes behind furniture, stray sprites) after
  re-entering a room: a known DirPlayer limitation
  ([dirplayer-rs#128](https://github.com/igorlira/dirplayer-rs/issues/128)).
  Reloading the page fixes it.
- **No sound machine samples**: the Kepler-www release package does not include
  `dcr/sound/`. It exists only in the Kepler-www Git repository.

## Other ways to run the client

DirPlayer is the only option here that needs no Adobe software. If an emulator
bug blocks you, the original Shockwave Player 12 (32-bit) can run under Wine in
an old NPAPI-capable Windows browser, or as a Shockwave projector. Both need
Adobe installers that are no longer officially distributed, and old plugins
with known security holes, so keep them away from the internet.
