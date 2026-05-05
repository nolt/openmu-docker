# OpenMU docker builder
This is my project to build a ready-to-use OpenMU server.

## Info
OpenMU web admin panel address http://localhost:8080

## Requirements
- Docker
- Docker Compose

## Building
- clone this repository
- replace values in .env to your own
- build
---
Build your service:

```docker compose up --build```

If you need to change something in Dockerfile or .env simply made your changes and run:

```docker compose up -d --build openmu```

Above command will recreate openmu service on the fly (you dont have to remove/stop whole service or container).

---
! WARNING !
Command below will stop and remove all created containers and volumes (purge).

```docker compose down -v```

---



More info about OpenMU project you will find here:
https://github.com/MUnique/OpenMU
