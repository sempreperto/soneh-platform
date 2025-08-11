#!/usr/bin/env bash
# soneh-apply.sh — aplica um bundle de arquivos/comandos vindo do STDIN
set -euo pipefail

ROOT="${ROOT:-$HOME/soneh}"
BACKUP_DIR="${BACKUP_DIR:-$ROOT/.backup/$(date +%Y%m%d-%H%M%S)}"
DRY="${DRY:-0}"

mkdir -p "$BACKUP_DIR"
work="$(mktemp)"; trap 'rm -f "$work"' EXIT
cat > "$work"

state="idle"; rel=""; tmp=""
while IFS= read -r line || [[ -n "$line" ]]; do
  case "$state" in
    idle)
      if [[ "$line" == "### FILE "* ]]; then
        rel="${line#"### FILE "}"
        tmp="$(mktemp)"
        state="file"
      elif [[ "$line" == "### RUN" ]]; then
        tmp="$(mktemp)"
        state="run"
      fi
      ;;
    file)
      if [[ "$line" == "### END" ]]; then
        dst="$ROOT/$rel"
        mkdir -p "$(dirname "$dst")" "$(dirname "$BACKUP_DIR/$rel")"
        if [[ -f "$dst" ]]; then cp -a "$dst" "$BACKUP_DIR/$rel" || true; fi
        if [[ "$DRY" == "1" ]]; then
          echo "[DRY] escreveria $dst (backup em $BACKUP_DIR/$rel)"
        else
          mv "$tmp" "$dst"
          echo "[ok] escreveu $dst"
        fi
        state="idle"; rel=""; tmp=""
      else
        printf '%s\n' "$line" >> "$tmp"
      fi
      ;;
    run)
      if [[ "$line" == "### END" ]]; then
        if [[ "$DRY" == "1" ]]; then
          echo "[DRY] executaria comandos:"
          sed 's/^/    /' "$tmp"
        else
          echo "[run] executando comandos do bundle…"
          bash -euo pipefail "$tmp"
        fi
        rm -f "$tmp"
        state="idle"; tmp=""
      else
        printf '%s\n' "$line" >> "$tmp"
      fi
      ;;
  esac
done < "$work"

if [[ "$state" != "idle" ]]; then
  echo "Erro: seção não fechada (faltou '### END')" >&2; exit 2
fi

echo "[done] backups em: $BACKUP_DIR"
