# King of Parties

### About
This game was made in a few (around ~8) hours to be used as a proof of concept of a talk I made for [Godot Online Brazil 2020](https://georgemarques.dev/godot-online-2020/) which theme was
the usage of WebSockets in Godot for real time multiplayer.

## Playing the game
You can download the respective current version of the game for these systems:
- [Windows](https://github.com/coelhucas/mp-game-pck/archive/master.zip)
- [MacOS](https://github.com/coelhucas/mp-game-pck/archive/macos.zip)
- [Linux](https://github.com/coelhucas/mp-game-pck/archive/linux.zip)

Some notes:
- Always run the project from the `AutoPatcher` file, to keep you in the most recent version;
- You may notice in every update a download of ~30MBs, the project size isn't increasing this much, it's just that the patcher doesn't has any diff algorithm, it just download the entire `.pck`
to replace the current one.

### Setup locally
To run this locally, you'll have to export two versions of the game:

#### Server
A simple local server should have the following `.env` file at the project's root:

```
SERVER=1
```

This project contains already the `godot-server` binary to run the build contained in `builds/server` onto a Linux server;
I'm using [GodotEnv](https://github.com/coelhucas/godotenv) to manage the `.env` and anything other than 0 is true to `SERVER`.

#### Client
A simple local client have the following `.env` file at the project's root:

```
SERVER=0
SERVER_URL=127.0.0.1
```
