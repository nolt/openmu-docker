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

This overwrites the current database, so stop the game server first. Use
`stop` — **never** `down -v`, which would delete the data volume you are trying
to restore into.

```sh
docker compose stop openmu

# Pick a file from ./backups/, decompress, and restore over the existing DB.
#   --clean --if-exists : drop the existing objects first, so restoring into a
#                         populated database doesn't fail with "already exists".
# Ownership and GRANTs are kept on purpose: the dump carries them and the login
# roles already exist in a running cluster, so the server reconnects afterwards
# with no extra step.  (-Fc is optional — pg_restore auto-detects the format.)
gunzip -c backups/openmu_YYYYMMDD_HHMMSS.dump.gz | \
  docker exec -i openmu-postgres pg_restore --clean --if-exists -U postgres -d openmu

docker compose start openmu
```

Verify the data actually came back before trusting it:

```sh
docker exec -i openmu-postgres psql -U postgres -d openmu -tA -c \
  'SELECT count(*) FROM data."Account"; SELECT count(*) FROM config."GameConfiguration";'
# expect: your account count, and 1 (a missing/0 GameConfiguration means the
# server would try to (re-)initialize instead of using the restored config).
```

For a normal restore that is all — the server starts back up on the restored data.

#### Troubleshooting: `permission denied for schema config` / `28P01` on startup

Only needed if you restored into a **freshly created / empty** Postgres cluster
(e.g. the data volume had been recreated). OpenMU connects with four per-context
login roles (`config`, `account`, `guild`, `friend`); these are cluster-level and
are *not* part of a single-database dump. If they are missing (or lack privileges
because the schemas were replaced), create them (role name = password) and grant
them on the restored schemas, then start the server:

```sh
docker compose stop openmu
docker exec -i openmu-postgres psql -U postgres -d openmu <<'SQL'
DO $$
DECLARE r text;
BEGIN
  FOREACH r IN ARRAY ARRAY['config','account','guild','friend'] LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r) THEN
      EXECUTE format('CREATE ROLE %I LOGIN PASSWORD %L', r, r);
    END IF;
    EXECUTE format('GRANT USAGE ON SCHEMA config,data,guild,friend TO %I', r);
    EXECUTE format('GRANT ALL ON ALL TABLES IN SCHEMA config,data,guild,friend TO %I', r);
    EXECUTE format('GRANT ALL ON ALL SEQUENCES IN SCHEMA config,data,guild,friend TO %I', r);
  END LOOP;
END $$;
SQL
docker compose start openmu
```

> Tip: `./backups/` lives on the host only. For real disaster recovery, copy it
> off-box too (rsync/object storage).

> ⚠️ Keep local edits out of tracked files. A `git pull` can overwrite
> `docker-compose.yaml` (and `.env` if you track it). If that changes the volume
> name or `PGDATA`, the next `docker compose up` mounts a **fresh, empty volume**
> and the database looks wiped — the real data is still in the previous volume,
> not lost. Put machine-specific overrides in `docker-compose.override.yaml`
> (git-ignored) instead, and after any pull check `git diff` and
> `docker volume ls | grep openmu` before `up`; if a new volume appeared, point
> the DB service back at the original volume rather than restoring an older dump.

---

More info about OpenMU project you will find here:
https://github.com/MUnique/OpenMU
