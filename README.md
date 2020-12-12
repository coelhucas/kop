# [WIP] King of Parties

### About
This game was made in a few (around ~8) hours to be used as a proof of concept of a talk I made for [Godot Online Brazil 2020](https://georgemarques.dev/godot-online-2020/) which theme was
the usage of WebSockets in Godot for real time multiplayer.

### Setup
To run this locally, you'll have to export two versions of the game:

#### Server
A simple local server should have the following `.env` file at the project's root:

```
SERVER=1
```

I'm using [GodotEnv](https://github.com/coelhucas/godotenv) to manage the `.env` and anything other than 0 is true to `SERVER`.

#### Client
A simple local client have the following `.env` file at the project's root:

```
SERVER=0
SERVER_URL=127.0.0.1
```
