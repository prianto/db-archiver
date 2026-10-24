# DB Archiver

Tiny MySQL backup tool: `mysqldump` → gzip → auto-delete after 30 days. Runs daily at 00:00 via cron.

Full documentation / Dokumentasi lengkap:

- [English](readme.en.md)
- [Bahasa Indonesia](readme.id.md)

## Quick start

```bash
cd /home/username/db-archiver
chmod 600 config.ini && chmod +x db-archiver.sh
# edit config.ini, then test:
./db-archiver.sh
# add to crontab -e:
0 0 * * * /home/username/db-archiver/db-archiver.sh >> /home/username/db-archiver/db-archiver.log 2>&1
```

Backups are saved to `./backups/<connection>/<database>_YYYYMMDD_HHMMSS.sql.gz`.
