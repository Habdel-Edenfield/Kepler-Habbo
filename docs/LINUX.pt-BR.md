# Rodando o Kepler no Linux (servidor + cliente)

Este guia leva uma máquina Linux limpa até um hotel v14 funcionando: o servidor
sobe, o banco é importado, o cliente abre no navegador, você cria uma conta,
vira administrador, entra num quarto e fala.

Testado no Ubuntu 26.04 (x86_64) com Docker 29 / Compose 2.40, Firefox e
Chrome. *Versão em inglês: [LINUX.md](LINUX.md).*

## Como as peças se encaixam

```
 Navegador (Firefox/Chrome)
   │  página + DCRs ─────────────► client-web      nginx         :8087
   │  conexão do jogo (WebSocket) ► client-ws-game  websockify    :12331 ─┐
   │  conexão MUS (WebSocket) ───► client-ws-mus   websockify    :12332 ─┤ TCP
   │                                                                     ▼
   │                               kepler          servidor Java :12321 / :12322
   │                                                                     │
   │                               kepler-mariadb  MariaDB 11.4  (só interno)
```

- Tudo roda em contêineres Docker, "caixas" isoladas. **Não** é preciso
  instalar Java nem MariaDB na máquina: a imagem compila o Kepler com o próprio
  JDK, e o banco fica no próprio contêiner e volume (`kepler-mariadb`). Ele não
  abre a porta 3306, então não briga com um MariaDB que já exista na máquina.
- O cliente v14 é Shockwave, que nunca teve versão para Linux, e a Adobe parou
  de distribuir em 2019. O cliente roda no
  [DirPlayer](https://github.com/igorlira/dirplayer-rs), um emulador de Shockwave
  de código aberto (Rust/WebAssembly). Navegadores não abrem conexões TCP
  diretas, então as conexões do cliente passam pelo `websockify`, que converte
  WebSocket de volta em TCP para o Kepler.
- Os arquivos do cliente (DCRs da Sulake, do
  [Kepler-www](https://github.com/Quackster/Kepler-www)) e o DirPlayer são
  baixados por um script para a pasta `client/`, que fica fora do Git.

## 1. Instale o necessário

Debian/Ubuntu:

```bash
sudo apt update
sudo apt install docker.io docker-compose-v2 git curl unzip
sudo usermod -aG docker "$USER"
```

Saia da sessão e entre de novo, para seu usuário poder usar `docker` sem
`sudo`. Confira:

```bash
docker compose version
```

Outras distribuições: instale o Docker Engine com o plugin Compose
(<https://docs.docker.com/engine/install/>), além de `git`, `curl` e `unzip`.

## 2. Confira se as portas estão livres

| Porta | Usada por                         |
|-------|-----------------------------------|
| 12321 | Servidor de jogo do Kepler        |
| 12322 | MUS do Kepler (câmera)            |
| 8087  | Arquivos web do cliente           |
| 12331 | Ponte WebSocket do jogo           |
| 12332 | Ponte WebSocket do MUS            |

```bash
ss -ltn | grep -E ':(12321|12322|8087|12331|12332)\b' || echo "todas livres"
```

Se alguma estiver ocupada, escolha outro número no `.env` (passo 4).

## 3. Baixe o código

Os arquivos para Linux (`compose.client.yml`, `tools/linux/`) estão, por
enquanto, no branch `linux-setup` deste fork:

```bash
git clone -b linux-setup https://github.com/Habdel-Edenfield/Kepler-Habbo.git kepler
cd kepler
```

## 4. Configure

```bash
cp .env.example .env
```

Edite o `.env` e troque pelo menos `MYSQL_PASSWORD` e `MARIADB_ROOT_PASSWORD`.
Para gerar valores aleatórios:

```bash
sed -i "s/^MYSQL_PASSWORD=.*/MYSQL_PASSWORD=$(openssl rand -hex 16)/; s/^MARIADB_ROOT_PASSWORD=.*/MARIADB_ROOT_PASSWORD=$(openssl rand -hex 16)/" .env
```

Opcional: acrescente esta linha ao `.env` para que todo comando
`docker compose` também cuide dos contêineres do cliente (aí dá para tirar o
`-f ... -f ...` dos comandos abaixo):

```
COMPOSE_FILE=compose.yml:compose.client.yml
```

Observações:

- `PUBLISH_IP=127.0.0.1` deixa todas as portas acessíveis só deste computador.
  Use `0.0.0.0` para outras máquinas conectarem e, nesse caso, coloque em
  `CLIENT_SERVER_HOST` o IP ou nome desta máquina.
- Não mude `MYSQL_HOSTNAME` nem `MYSQL_PORT`; eles apontam para o contêiner
  do banco.

## 5. Suba o servidor e o banco

```bash
docker compose up -d --build
```

A primeira compilação baixa o Gradle e as bibliotecas e leva alguns minutos.
O banco importa `tools/kepler.sql` sozinho na primeira vez que sobe.

Confira:

```bash
docker compose ps
docker logs kepler
```

Os dois contêineres devem aparecer como `healthy`, e o log deve terminar com
`Game server is listening on 0.0.0.0:12321`.

## 6. Prepare e suba o cliente

```bash
./tools/linux/setup-client.sh
docker compose -f compose.yml -f compose.client.yml up -d --build
```

O script baixa cerca de 70 MB (Kepler-www e DirPlayer, em versões fixas,
conferidas por SHA-256) para `client/`. Rode de novo sempre que mudar as
portas ou o `CLIENT_SERVER_HOST` no `.env`.

## 7. Jogue

1. Abra <http://localhost:8087/> no Firefox ou no Chrome. Aparece o
   carregamento da Sulake e depois a vista do hotel com a caixa de login
   (uns 20 segundos na primeira vez).
2. Clique em **"You can create one here"** e siga o cadastro. Na página dos
   termos, role o texto até o fim antes de marcar a caixa. A senha precisa
   ter de 6 a 10 caracteres.
3. No fim você entra no hotel com o Navegador aberto.

## 8. Vire administrador

Troque o `rank` do seu usuário para 7 (troque `SeuNome`):

```bash
docker exec kepler-mariadb sh -c 'mariadb -ukepler -p"$MYSQL_PASSWORD" kepler -e "UPDATE users SET \`rank\` = 7 WHERE username = \"SeuNome\""'
```

O rank é lido no login: recarregue a página e entre de novo. Para conferir,
entre num quarto e digite `:coords` no chat. Só administradores recebem uma
janela com as coordenadas.

## Comandos do dia a dia

```bash
docker compose -f compose.yml -f compose.client.yml stop      # para tudo
docker compose -f compose.yml -f compose.client.yml start     # liga de novo
docker compose -f compose.yml -f compose.client.yml down      # remove os contêineres (os dados ficam)
docker logs -f kepler                                         # acompanha o log do servidor
```

Zerar o banco (apaga todos os usuários e quartos):

```bash
docker compose -f compose.yml -f compose.client.yml down
docker volume rm kepler-mariadb
docker compose -f compose.yml -f compose.client.yml up -d
```

Depois de mudar o código Java, recompile o servidor com
`docker compose up -d --build kepler`.

## Problemas comuns

- **"port is already allocated"**: outro programa usa aquela porta. Troque no
  `.env`, rode `./tools/linux/setup-client.sh` de novo se for porta do cliente,
  e suba outra vez.
- **A caixa de login aparece mas nada acontece ao clicar**: confira se as
  pontes estão rodando e recebendo a conexão.
  `docker logs kepler-client-ws-game` deve mostrar `connecting to: kepler:12321`,
  e `docker logs kepler` deve mostrar `Connection from ...`.
- **O texto digitado aparece atrasado ou embaralhado**: espere a vista do hotel
  carregar por completo antes de digitar no login; o emulador pode demorar um
  pouco depois que a página aparece.
- **O rank 7 não funciona**: saia e entre de novo; o rank só é lido no login.
- **Falhas gráficas** (caixas pretas atrás dos móveis, pedaços soltos) ao
  voltar para um quarto: limitação conhecida do DirPlayer
  ([dirplayer-rs#128](https://github.com/igorlira/dirplayer-rs/issues/128)).
  Recarregar a página resolve.
- **Sem os sons da máquina de som**: o pacote de release do Kepler-www não
  traz `dcr/sound/`. Essa pasta só existe no repositório Git do Kepler-www.

## Outras formas de rodar o cliente

O DirPlayer é a única opção aqui que dispensa software da Adobe. Se um bug do
emulador atrapalhar, o Shockwave Player 12 original (32 bits) roda no Wine
dentro de um navegador antigo de Windows com suporte a NPAPI, ou como projetor
do Shockwave. As duas opções dependem de instaladores da Adobe que não são mais
distribuídos oficialmente e de plugins velhos com falhas de segurança
conhecidas, então mantenha-as longe da internet.
