# DB Archiver

A tiny MySQL backup tool. It dumps databases with `mysqldump`, compresses them with gzip, and deletes backups older than 30 days. Designed to run daily from cron.

## Features

- Multiple databases, each connection with its own MySQL user
- Config kept in a separate file (`config.ini`)
- Gzip-compressed dumps (`.sql.gz`), consistent snapshot (`--single-transaction`), includes routines, triggers, events
- Retention: removes backups older than N days (default 30)
- Passwords are never put on the command line (temporary option file, mode 600)
- A failed database does not stop the others; exit code is 1 if any failed

## Requirements

- Linux with `bash`, `mysqldump`, `gzip`, `find`

## Layout

```
/home/username/db-archiver/
├── db-archiver.sh
├── config.ini
├── readme.md / readme.en.md / readme.id.md
└── backups/
    └── <connection>/<database>_YYYYMMDD_HHMMSS.sql.gz
```

## Setup

1. Copy the folder to `/home/username/db-archiver`.
2. Edit `config.ini` with your connections.
3. Secure the config and make the script executable:

   ```bash
   chmod 600 /home/username/db-archiver/config.ini
   chmod +x /home/username/db-archiver/db-archiver.sh
   ```

4. Create a MySQL user for backup (example):

   ```sql
   CREATE USER 'backup_web'@'localhost' IDENTIFIED BY 'password';
   GRANT SELECT, SHOW VIEW, TRIGGER, EVENT, LOCK TABLES ON shop_db.* TO 'backup_web'@'localhost';
   ```

5. Test manually:

   ```bash
   /home/username/db-archiver/db-archiver.sh
   ```

## Cron (every day at 00:00)

Run `crontab -e` and add:

```cron
0 0 * * * /home/username/db-archiver/db-archiver.sh >> /home/username/db-archiver/db-archiver.log 2>&1
```

## Configuration

| Key                | Section      | Description                         |
| ------------------ | ------------ | ----------------------------------- |
| `retention_days`   | `[settings]` | Days to keep backups (default 30)   |
| `backup_dir`       | `[settings]` | Backup folder (default `./backups`) |
| `host`, `port`     | connection   | Default `127.0.0.1`, `3306`         |
| `user`, `password` | connection   | MySQL credentials                   |
| `databases`        | connection   | Comma-separated database names      |

Each `[section]` other than `[settings]` is one connection. Values are read literally (no quotes needed).

## Restore

```bash
gunzip -c backups/shop/shop_db_20261024_000001.sql.gz | mysql -u root -p
```

## Notes

- Use a different config file with `./db-archiver.sh /path/to/other.ini` or the `DB_ARCHIVER_CONFIG` variable.
- Retention is based on file modification time.
- Also copy backups off the server; backups on the same disk are not a full safety net.
