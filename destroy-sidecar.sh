#!/bin/bash

# ===========================================================
# 🔥 destroy-sidecar.sh — Nuke LibrePhotos Dev Bootstrap
# Author: Winston Spencer
#
# Description:
#   - Stops & removes 'librephotos-db' Docker container
#   - Optionally prunes related Docker volumes
#   - Deletes generated .env file
#   - Cleans up log files if needed
# ===========================================================

# === Config ===
CONTAINER_NAME="librephotos-db"
ENV_FILE=".env"
LOG_FILE="./sidecar.log"
DELETE_VOLUMES=false

# -----------------------------------------------------------
# 📓 Log Function
# -----------------------------------------------------------
log() {
  local level="$1"
  local msg="$2"
  local timestamp
  timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  local emoji=""

  case "$level" in
    INFO) emoji="ℹ️ " ;;
    SUCCESS) emoji="✅" ;;
    ERROR) emoji="❌" ;;
    *) emoji="🔸" ;;
  esac

  echo "[$timestamp] [$level] $emoji $msg"
}

# -----------------------------------------------------------
# 🧨 Remove Docker Container
# -----------------------------------------------------------
remove_container() {
  if docker ps -a --format '{{.Names}}' | grep -q "^$CONTAINER_NAME$"; then
    log "INFO" "Stopping and removing container '$CONTAINER_NAME'..."
    docker rm -f "$CONTAINER_NAME" > /dev/null 2>&1
    log "SUCCESS" "Container '$CONTAINER_NAME' removed"
  else
    log "INFO" "No container named '$CONTAINER_NAME' found"
  fi
}

# -----------------------------------------------------------
# 🧼 Remove .env and log files
# -----------------------------------------------------------
cleanup_files() {
  if [[ -f "$ENV_FILE" ]]; then
    rm "$ENV_FILE"
    log "SUCCESS" "Removed $ENV_FILE"
  else
    log "INFO" "$ENV_FILE not found — skipping"
  fi

  if [[ -f "$LOG_FILE" ]]; then
    rm "$LOG_FILE"
    log "SUCCESS" "Removed $LOG_FILE"
  else
    log "INFO" "$LOG_FILE not found — skipping"
  fi
}

# -----------------------------------------------------------
# 🧯 Optionally remove Docker volumes
# -----------------------------------------------------------
purge_volumes() {
  if [[ "$DELETE_VOLUMES" == true ]]; then
    log "INFO" "Pruning unused Docker volumes..."
    docker volume prune -f > /dev/null
    log "SUCCESS" "Docker volumes pruned"
  else
    log "INFO" "Skipping volume prune (set DELETE_VOLUMES=true to enable)"
  fi
}

# -----------------------------------------------------------
# 🎬 Main
# -----------------------------------------------------------
main() {
  log "INFO" "Destroying local LibrePhotos dev setup... 💣"
  remove_container
  cleanup_files
  purge_volumes
  log "SUCCESS" "Destruction complete. Dev environment cleaned 🧼"
}

main "$@"
