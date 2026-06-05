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



## Backups

The `openmu-db-backup` container backs up the PostgreSQL database automatically.
On an interval (`BACKUP_INTERVAL`, seconds, default `86400` = 24h) it runs
`backup/backup.sh`, which:

- dumps the `openmu` database with `pg_dump -Fc` (custom format),
- verifies the dump with `pg_restore --list`,
- gzips it to `backups/openmu_YYYYMMDD_HHMMSS.dump.gz`,
- prunes backups older than `RETENTION_DAYS` (default `7`).

Files land in `./backups/` on the host. Every run is logged and a failed dump is
logged and removed (no partial/empty files left behind):

```sh
docker logs openmu-db-backup
```

### Run a backup manually

```sh
docker exec openmu-db-backup /usr/local/bin/backup.sh
```

### Restore a backup

This overwrites the current database, so stop the game server first:

```sh
docker compose stop openmu

# pick a file from ./backups/, decompress and restore.
# (-Fc = custom format; pg_restore auto-detects it from the archive header, so
#  it is optional, but kept explicit here.)
gunzip -c backups/openmu_YYYYMMDD_HHMMSS.dump.gz | \
  docker exec -i openmu-postgres pg_restore -U postgres -d openmu -Fc

# ...or dropping existing objects first:
gunzip -c backups/openmu_YYYYMMDD_HHMMSS.dump.gz | \
  docker exec -i openmu-postgres pg_restore -U postgres -d openmu -Fc --clean --if-exists

docker compose start openmu
```

> Tip: `./backups/` lives on the host only. For real disaster recovery, copy it
> off-box too (rsync/object storage).

---

More info about OpenMU project you will find here:
https://github.com/MUnique/OpenMU
