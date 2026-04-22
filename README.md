# OpenMU docker builder
This is my project to build a ready-to-use OpenMU server.

## Info
OpenMU web admin panel address http://localhost:8082

## Requirements
- Docker
- Docker Compose

## Building
- clone this repository
- replace values in .env to your own
- build
  
```docker compose -d --build```

```docker compose down -v``` ← this command will remove containers with all created volumes


More info about OpenMU project you can find here:
https://github.com/MUnique/OpenMU
