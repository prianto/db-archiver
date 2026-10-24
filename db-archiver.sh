#!/usr/bin/env bash
# DB Archiver - MySQL backup + gzip compression with retention.
# Usage: ./db-archiver.sh [path/to/config.ini]
set -uo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${1:-${DB_ARCHIVER_CONFIG:-$BASE_DIR/config.ini}}"

log() { printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }

[[ -r "$CONFIG" ]] || { log "ERROR: config not readable: $CONFIG"; exit 2; }
command -v mysqldump >/dev/null || { log "ERROR: mysqldump not found"; exit 2; }
command -v gzip >/dev/null || { log "ERROR: gzip not found"; exit 2; }

# Warn if config (contains passwords) is readable by others
perm="$(stat -c '%a' "$CONFIG" 2>/dev/null || echo 600)"
[[ "$perm" =~ ^[0-7]00$ ]] || log "WARNING: $CONFIG has mode $perm; run: chmod 600 $CONFIG"

# ---------- parse INI ----------
declare -A CFG
SECTIONS=()
current=""
while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line%$'\r'}"
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"
  [[ -z "$line" || "$line" == \#* || "$line" == \;* ]] && continue
  if [[ "$line" =~ ^\[(.+)\]$ ]]; then
    current="${BASH_REMATCH[1]}"
    [[ "$current" != "settings" ]] && SECTIONS+=("$current")
  elif [[ "$line" =~ ^([A-Za-z_]+)[[:space:]]*=[[:space:]]*(.*)$ ]]; then
    CFG["$current.${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
  fi
done < "$CONFIG"

RETENTION_DAYS="${CFG[settings.retention_days]:-30}"
BACKUP_DIR="${CFG[settings.backup_dir]:-$BASE_DIR/backups}"
[[ "$RETENTION_DAYS" =~ ^[0-9]+$ ]] || { log "ERROR: retention_days must be a number"; exit 2; }
mkdir -p "$BACKUP_DIR"

if [[ ${#SECTIONS[@]} -eq 0 ]]; then
  log "ERROR: no database sections found in $CONFIG"
  exit 2
fi

TMP_CNF="$(mktemp)"
trap 'rm -f "$TMP_CNF"' EXIT
chmod 600 "$TMP_CNF"

failed=0
log "Starting backup (${#SECTIONS[@]} connection(s), retention ${RETENTION_DAYS} days)"

for sec in "${SECTIONS[@]}"; do
  host="${CFG[$sec.host]:-127.0.0.1}"
  port="${CFG[$sec.port]:-3306}"
  user="${CFG[$sec.user]:-}"
  pass="${CFG[$sec.password]:-}"
  dbs="${CFG[$sec.databases]:-}"

  if [[ -z "$user" || -z "$dbs" ]]; then
    log "[$sec] ERROR: 'user' and 'databases' are required"
    failed=1
    continue
  fi

  # Credentials go in a temp option file, never on the command line
  esc="${pass//\\/\\\\}"
  esc="${esc//\"/\\\"}"
  {
    echo "[client]"
    echo "host=$host"
    echo "port=$port"
    echo "user=$user"
    echo "password=\"$esc\""
  } > "$TMP_CNF"

  mkdir -p "$BACKUP_DIR/$sec"
  IFS=',' read -ra db_list <<< "$dbs"
  for db in "${db_list[@]}"; do
    db="${db#"${db%%[![:space:]]*}"}"; db="${db%"${db##*[![:space:]]}"}"
    [[ -z "$db" ]] && continue
    stamp="$(date '+%Y%m%d_%H%M%S')"
    out="$BACKUP_DIR/$sec/${db}_${stamp}.sql.gz"
    tmp_out="$out.part"

    if mysqldump --defaults-extra-file="$TMP_CNF" \
         --single-transaction --quick --routines --triggers --events \
         --no-tablespaces --databases "$db" 2>"$tmp_out.err" \
         | gzip -9 > "$tmp_out" \
       && [[ ${PIPESTATUS[0]} -eq 0 ]]; then
      mv "$tmp_out" "$out"
      rm -f "$tmp_out.err"
      log "[$sec] OK   $db -> ${out#"$BASE_DIR"/} ($(du -h "$out" | cut -f1))"
    else
      log "[$sec] FAIL $db: $(tr '\n' ' ' < "$tmp_out.err")"
      rm -f "$tmp_out" "$tmp_out.err"
      failed=1
    fi
  done
done

# ---------- retention ----------
deleted="$(find "$BACKUP_DIR" -type f -name '*.sql.gz' -mtime +"$RETENTION_DAYS" -print -delete | wc -l)"
log "Retention: removed $deleted file(s) older than $RETENTION_DAYS days"

if [[ $failed -ne 0 ]]; then
  log "Finished with errors"
  exit 1
fi
log "Finished successfully"