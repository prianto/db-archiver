# DB Archiver

Aplikasi kecil untuk backup MySQL. Database di-dump dengan `mysqldump`, dikompres dengan gzip, dan backup yang lebih dari 30 hari dihapus otomatis. Dirancang untuk dijalankan harian lewat cron.

## Fitur

- Multi database, tiap koneksi bisa memakai user MySQL berbeda
- Konfigurasi disimpan di file terpisah (`config.ini`)
- Hasil dump dikompres gzip (`.sql.gz`), snapshot konsisten (`--single-transaction`), termasuk routines, triggers, events
- Retensi: hapus backup yang lebih lama dari N hari (default 30)
- Password tidak ditaruh di command line (file opsi sementara, mode 600)
- Jika satu database gagal, yang lain tetap diproses; exit code 1 bila ada yang gagal

## Kebutuhan

- Linux dengan `bash`, `mysqldump`, `gzip`, `find`

## Struktur

```
/home/username/db-archiver/
├── db-archiver.sh
├── config.ini
├── readme.md / readme.en.md / readme.id.md
└── backups/
    └── <koneksi>/<database>_YYYYMMDD_HHMMSS.sql.gz
```

## Instalasi

1. Salin folder ke `/home/username/db-archiver`.
2. Edit `config.ini` sesuai koneksi Anda.
3. Amankan config dan jadikan script executable:

   ```bash
   chmod 600 /home/username/db-archiver/config.ini
   chmod +x /home/username/db-archiver/db-archiver.sh
   ```

4. Buat user MySQL khusus backup (contoh):

   ```sql
   CREATE USER 'backup_web'@'localhost' IDENTIFIED BY 'password';
   GRANT SELECT, SHOW VIEW, TRIGGER, EVENT, LOCK TABLES ON shop_db.* TO 'backup_web'@'localhost';
   ```

5. Uji manual:

   ```bash
   /home/username/db-archiver/db-archiver.sh
   ```

## Cron (setiap hari jam 00.00)

Jalankan `crontab -e` lalu tambahkan:

```cron
0 0 * * * /home/username/db-archiver/db-archiver.sh >> /home/username/db-archiver/db-archiver.log 2>&1
```

## Konfigurasi

| Key                | Section      | Keterangan                                      |
| ------------------ | ------------ | ----------------------------------------------- |
| `retention_days`   | `[settings]` | Lama penyimpanan backup dalam hari (default 30) |
| `backup_dir`       | `[settings]` | Folder backup (default `./backups`)             |
| `host`, `port`     | koneksi      | Default `127.0.0.1`, `3306`                     |
| `user`, `password` | koneksi      | Kredensial MySQL                                |
| `databases`        | koneksi      | Nama database, dipisah koma                     |

Setiap `[section]` selain `[settings]` adalah satu koneksi. Nilai dibaca apa adanya (tanpa tanda kutip).

## Restore

```bash
gunzip -c backups/shop/shop_db_20261024_000001.sql.gz | mysql -u root -p
```

## Catatan

- Gunakan file config lain dengan `./db-archiver.sh /path/ke/lain.ini` atau variabel `DB_ARCHIVER_CONFIG`.
- Retensi berdasarkan waktu modifikasi file.
- Salin juga backup ke luar server; backup di disk yang sama bukan pengaman penuh.
