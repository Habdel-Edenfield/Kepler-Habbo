<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Kepler</title>
    <style>
        body { margin: 0; background: #000; color: #aaa; font: 12px sans-serif; }
        #stage { display: flex; justify-content: center; padding-top: 20px; }
        p { text-align: center; }
    </style>
    <script>
        // DirPlayer cannot open raw TCP sockets from a browser: send the
        // client's game and MUS connections to the websockify containers.
        window.__dirplayerFlashConfig = {
            socketProxy: [
                { host: "@SERVER_HOST@", port: @SERVER_PORT@, proxyUrl: "ws://@SERVER_HOST@:@WS_GAME_PORT@" },
                { host: "@SERVER_HOST@", port: @MUS_PORT@, proxyUrl: "ws://@SERVER_HOST@:@WS_MUS_PORT@" }
            ]
        };
    </script>
    <script src="dirplayer/dirplayer-polyfill.js"></script>
</head>
<body>
<div id="stage">
    <embed
        src="@WEB_URL@dcr/14.1_b8/habbo.dcr"
        type="application/x-director"
        width="720"
        height="540"
        bgColor="#000000"
        swRemote="swSaveEnabled='true' swVolume='true' swRestart='false' swPausePlay='false' swFastForward='false' swTitle='Habbo Hotel' swContextMenu='true'"
        swStretchStyle="none"
        swText=""
        sw1="site.url=@WEB_URL@;url.prefix=@WEB_URL@"
        sw2="connection.info.host=@SERVER_HOST@;connection.info.port=@SERVER_PORT@"
        sw3="client.reload.url=@WEB_URL@"
        sw4="connection.mus.host=@SERVER_HOST@;connection.mus.port=@MUS_PORT@"
        sw5="external.variables.txt=@WEB_URL@gamedata/external_variables.txt;external.texts.txt=@WEB_URL@gamedata/external_texts.txt">
</div>
<p>Kepler v14 &middot; client emulated by <a href="https://github.com/igorlira/dirplayer-rs">DirPlayer</a></p>
</body>
</html>
