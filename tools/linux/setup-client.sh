#!/usr/bin/env bash
# Downloads and prepares the Habbo v14 client for Kepler on Linux:
#   - Kepler-www (DCRs, gamedata, images) from https://github.com/Quackster/Kepler-www
#   - DirPlayer polyfill (Shockwave emulator) from https://github.com/igorlira/dirplayer-rs
# Everything goes to ./client/ (ignored by Git: Sulake files are not redistributed here).
# Serve it with: docker compose -f compose.yml -f compose.client.yml up -d
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CLIENT="$ROOT/client"
DOWNLOADS="$CLIENT/downloads"
WWW="$CLIENT/www"

KEPLER_WWW_URL="https://github.com/Quackster/Kepler-www/releases/download/v0.1.0/Kepler-www-v0.1.0.zip"
KEPLER_WWW_SHA256="8da00309860f3e36d2eab661571c0015f1cf03fd9e6bb89c33e3b2768045a177"
DIRPLAYER_URL="https://github.com/igorlira/dirplayer-rs/releases/download/v0.8.1/dirplayer-polyfill-0.8.1.zip"
DIRPLAYER_SHA256="6f5000412c50833345a630ade25fb70359dc4e1aae66352c80de7da77542162c"

# Reads KEY from .env without executing the file; falls back to a default.
env_value() {
    local value=""
    if [ -f "$ROOT/.env" ]; then
        value="$(grep -E "^$1=" "$ROOT/.env" | tail -n1 | cut -d= -f2- | tr -d '\r')"
    fi
    echo "${value:-$2}"
}

SERVER_HOST="$(env_value CLIENT_SERVER_HOST localhost)"
SERVER_PORT="$(env_value SERVER_PORT 12321)"
MUS_PORT="$(env_value MUS_PORT 12322)"
WS_GAME_PORT="$(env_value WS_GAME_PORT 12331)"
WS_MUS_PORT="$(env_value WS_MUS_PORT 12332)"
CLIENT_WEB_PORT="$(env_value CLIENT_WEB_PORT 8087)"
WEB_URL="http://$SERVER_HOST:$CLIENT_WEB_PORT/"

for tool in curl unzip sha256sum sed; do
    command -v "$tool" >/dev/null || { echo "Missing tool: $tool (sudo apt install $tool)" >&2; exit 1; }
done

# download URL SHA256 -> path of the verified file
download() {
    local file="$DOWNLOADS/$(basename "$1")"
    if [ ! -f "$file" ] || ! echo "$2  $file" | sha256sum -c --quiet - 2>/dev/null; then
        echo "Downloading $(basename "$1")..." >&2
        curl -fL --progress-bar -o "$file.part" "$1"
        mv "$file.part" "$file"
    fi
    echo "$2  $file" | sha256sum -c --quiet - || { echo "Checksum mismatch: $file" >&2; exit 1; }
    echo "$file"
}

mkdir -p "$DOWNLOADS"
www_zip="$(download "$KEPLER_WWW_URL" "$KEPLER_WWW_SHA256")"
dirplayer_zip="$(download "$DIRPLAYER_URL" "$DIRPLAYER_SHA256")"

echo "Extracting into client/www..."
rm -rf "$WWW"
mkdir -p "$WWW/dirplayer"
unzip -q "$www_zip" -d "$WWW"
unzip -q "$dirplayer_zip" -d "$WWW/dirplayer"

# Kepler-www expects to be served at http://localhost/ (port 80).
sed -i "s#http://localhost/#$WEB_URL#g" "$WWW/gamedata/external_variables.txt"

sed -e "s#@WEB_URL@#$WEB_URL#g" \
    -e "s#@SERVER_HOST@#$SERVER_HOST#g" \
    -e "s#@SERVER_PORT@#$SERVER_PORT#g" \
    -e "s#@MUS_PORT@#$MUS_PORT#g" \
    -e "s#@WS_GAME_PORT@#$WS_GAME_PORT#g" \
    -e "s#@WS_MUS_PORT@#$WS_MUS_PORT#g" \
    "$ROOT/tools/linux/client.html.tpl" > "$WWW/index.html"

echo "Client ready. Start it with:"
echo "  docker compose -f compose.yml -f compose.client.yml up -d"
echo "and open $WEB_URL"
