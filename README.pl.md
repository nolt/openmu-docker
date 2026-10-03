# OpenMU docker builder

🇬🇧 [English version](README.md)

Projekt do zbudowania gotowego do użycia serwera OpenMU.

## Informacje
Adres panelu administracyjnego OpenMU: http://localhost:8080

## Wymagania
- Docker
- Docker Compose

## Budowanie
- sklonuj to repozytorium
- skopiuj `.env.example` do `.env` i ustaw własne wartości (dane dostępowe do bazy, port panelu administracyjnego, strefa czasowa, ustawienia kopii zapasowych):

  ```cp .env.example .env```

  `.env` jest ignorowany przez gita, więc lokalne wartości nigdy nie trafią do commita, a `git pull` ich nie nadpisze.
- zbuduj
---
Zbuduj usługę:

```docker compose up --build```

Jeśli chcesz coś zmienić w Dockerfile albo w `.env`, wprowadź zmiany i uruchom:

```docker compose up -d --build openmu```

To polecenie odtworzy usługę openmu w locie (nie trzeba usuwać ani zatrzymywać całego stosu czy kontenera).

---
! UWAGA !
Poniższe polecenie zatrzyma i usunie wszystkie utworzone kontenery oraz wolumeny (czyszczenie do zera).

```docker compose down -v```

---



## Kopie zapasowe

Kontener `openmu-db-backup` automatycznie robi kopie bazy PostgreSQL.
Co ustalony czas (`BACKUP_INTERVAL`, w sekundach, domyślnie `86400` = 24 h) uruchamia
`backup/backup.sh`, który:

- zrzuca bazę `openmu` poleceniem `pg_dump -Fc` (format custom),
- weryfikuje zrzut przez `pg_restore --list`,
- pakuje go gzipem do `backups/openmu_RRRRMMDD_GGMMSS.dump.gz`,
- usuwa kopie starsze niż `RETENTION_DAYS` (domyślnie `7`).

Pliki lądują w `./backups/` na hoście. Każde uruchomienie jest logowane, a nieudany zrzut
jest odnotowywany w logu i usuwany (nie zostają pliki częściowe ani puste):

```sh
docker logs openmu-db-backup
```

### Ręczne wykonanie kopii

```sh
docker exec openmu-db-backup /usr/local/bin/backup.sh
```

### Przywracanie kopii

Przywracanie nadpisuje bieżącą bazę, więc najpierw zatrzymaj serwer gry. Użyj
`stop` — **nigdy** `down -v`, bo to skasowałoby wolumen z danymi, do którego chcesz
przywracać.

```sh
docker compose stop openmu

# Wybierz plik z ./backups/, rozpakuj i przywróć na istniejącą bazę.
#   --clean --if-exists : najpierw usuwa istniejące obiekty, żeby przywracanie do
#                         wypełnionej bazy nie kończyło się błędem "already exists".
# Właściciele i GRANT-y są celowo zachowane: zrzut je zawiera, a role logowania
# już istnieją w działającym klastrze, więc serwer połączy się potem bez
# dodatkowych kroków.  (-Fc jest opcjonalne — pg_restore sam wykrywa format.)
gunzip -c backups/openmu_RRRRMMDD_GGMMSS.dump.gz | \
  docker exec -i openmu-postgres pg_restore --clean --if-exists -U postgres -d openmu

docker compose start openmu
```

Zanim zaufasz przywróconej bazie, sprawdź, czy dane faktycznie wróciły:

```sh
docker exec -i openmu-postgres psql -U postgres -d openmu -tA -c \
  'SELECT count(*) FROM data."Account"; SELECT count(*) FROM config."GameConfiguration";'
# oczekiwany wynik: liczba Twoich kont oraz 1 (brak lub 0 w GameConfiguration oznacza,
# że serwer spróbuje zainicjalizować konfigurację od nowa, zamiast użyć przywróconej).
```

Przy zwykłym przywracaniu to wszystko — serwer wstanie na przywróconych danych.

#### Rozwiązywanie problemów: `permission denied for schema config` / `28P01` przy starcie

Potrzebne tylko wtedy, gdy przywracasz do **świeżo utworzonego / pustego** klastra Postgresa
(np. po odtworzeniu wolumenu z danymi). OpenMU łączy się czterema rolami logowania, po jednej
na kontekst (`config`, `account`, `guild`, `friend`); są one zdefiniowane na poziomie klastra
i *nie* wchodzą w skład zrzutu pojedynczej bazy. Jeśli ich brakuje (albo straciły uprawnienia,
bo schematy zostały podmienione), utwórz je (nazwa roli = hasło), nadaj im uprawnienia do
przywróconych schematów i uruchom serwer:

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

> Wskazówka: `./backups/` leży tylko na hoście. Na wypadek prawdziwej awarii kopiuj je także
> poza tę maszynę (rsync / magazyn obiektowy).

> ⚠️ Nie trzymaj lokalnych zmian w plikach śledzonych przez gita. `git pull` może nadpisać
> `docker-compose.yaml` (oraz `.env`, jeśli go śledzisz). Jeśli zmieni to nazwę wolumenu albo
> `PGDATA`, następne `docker compose up` zamontuje **świeży, pusty wolumen** i baza będzie
> wyglądała na wyczyszczoną — prawdziwe dane nadal są w poprzednim wolumenie, nie przepadły.
> Ustawienia specyficzne dla maszyny trzymaj w `docker-compose.override.yaml` (ignorowanym
> przez gita), a po każdym pullu sprawdź `git diff` oraz `docker volume ls | grep openmu`,
> zanim zrobisz `up`; jeśli pojawił się nowy wolumen, skieruj usługę bazy z powrotem na
> pierwotny, zamiast przywracać starszy zrzut.

---

Więcej informacji o projekcie OpenMU:
https://github.com/MUnique/OpenMU
