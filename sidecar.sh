#!/bin/bash

# ===========================================================
# 📦 sidecar.sh — Local LibrePhotos Dev Bootstrap
# Author: Winston Spencer
#
# Description:
#   - Removes any existing 'librephotos-db' Docker container
#   - Starts a fresh PostgreSQL instance
#   - Generates a local .env file
#   - Runs Django DB migrations
#   - Creates a superuser account
# ===========================================================

# === Config ===
CONTAINER_NAME="librephotos-db"
DB_NAME="librephotos"
DB_USER="librephotos"
DB_PASS=""
DB_PORT="5432"
ENV_FILE=".env"
LOG_FILE="./sidecar.log"
DJANGO_MANAGE="./manage.py"
SECRET_KEY=""
ADMIN_EMAIL="librephotos@winstonspencer.com"
ADMIN_USER="admin"
ADMIN_PASS=""
VENV_PATH="./venv/bin/activate"

# -----------------------------------------------------------
# 📓 Log Function
# -----------------------------------------------------------
log() {
  local level="$1"
  local func="${FUNCNAME[1]}"
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

  echo "[$timestamp] [$level] [$func] $emoji $msg" | tee -a "$LOG_FILE"
}


# -----------------------------------------------------------
# 📦 Export Environment Variables
# -----------------------------------------------------------
export_env_vars() {
  if [[ -f "$ENV_FILE" ]]; then
    set -a
    source "$ENV_FILE"
    set +a
  else
    log "ERROR" ".env file not found when trying to export variables"
    exit 1
  fi
}

# -----------------------------------------------------------
# 🔑 Generate Secrets
# -----------------------------------------------------------
generate_secrets() {
  DB_PASS=$(openssl rand -base64 18 | tr -d '=+/')
  ADMIN_PASS=$(openssl rand -base64 18 | tr -d '=+/')
  SECRET_KEY=$(openssl rand -base64 64)

  log "INFO" "Generated database password"
  log "INFO" "Generated superuser password"
  log "INFO" "Generated Django SECRET_KEY"
}

# -----------------------------------------------------------
# 🧹 Reset the database container
# -----------------------------------------------------------
reset_postgres_container() {
  log "INFO" "Checking for existing container '$CONTAINER_NAME'..."
  if docker ps -a --format '{{.Names}}' | grep -q "^$CONTAINER_NAME$"; then
    log "INFO" "Removing existing container '$CONTAINER_NAME'..."
    docker rm -f "$CONTAINER_NAME" >> "$LOG_FILE" 2>&1
  fi

  log "INFO" "Starting new PostgreSQL container '$CONTAINER_NAME' with healthcheck..."
  docker run -d \
    --name "$CONTAINER_NAME" \
    -e POSTGRES_DB="$DB_NAME" \
    -e POSTGRES_USER="$DB_USER" \
    -e POSTGRES_PASSWORD="$DB_PASS" \
    -p "$DB_PORT:5432" \
    --health-cmd="pg_isready -U $DB_USER -d $DB_NAME" \
    --health-interval=5s \
    --health-timeout=5s \
    --health-retries=5 \
    postgres >> "$LOG_FILE" 2>&1

  if [[ $? -eq 0 ]]; then
    log "SUCCESS" "PostgreSQL container started ✅"
  else
    log "ERROR" "Failed to start PostgreSQL container ❌"
    exit 1
  fi

  log "INFO" "Waiting for PostgreSQL to initialize..."
  until docker exec "$CONTAINER_NAME" pg_isready -U "$DB_USER" -d "$DB_NAME" > /dev/null 2>&1; do
    log "INFO" "Waiting for DB to be ready..."
    sleep 2
  done
  
  log "SUCCESS" "PostgreSQL is ready! 🎉 "
}


# -----------------------------------------------------------
# 📝 Generate local .env file
# -----------------------------------------------------------
write_env_file() {
  log "INFO" "Writing .env configuration to $ENV_FILE..."
  cat > "$ENV_FILE" <<EOF
DEBUG=True
SECRET_KEY=$SECRET_KEY

DB_BACKEND=postgresql
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASS=$DB_PASS
DB_HOST=localhost
DB_PORT=$DB_PORT
EOF

  log "SUCCESS" ".env file created 🎉"
}

# -----------------------------------------------------------
# 📦 Apply DB migrations
# -----------------------------------------------------------
run_migrations() {
  log "INFO" "Applying Django migrations..."
  export_env_vars

  if ! command -v django-admin > /dev/null; then
    log "ERROR" "Django is not installed or not in your Python environment ❌"
    log "INFO" "Try running: pip install -r requirements.txt or activate your virtualenv"
    exit 1
  fi

  if python3 "$DJANGO_MANAGE" migrate >> "$LOG_FILE" 2>&1; then
    log "SUCCESS" "Migrations applied 🧱"
  else
    log "ERROR" "Migration step failed ❌"
    tail -n 10 "$LOG_FILE"
    exit 1
  fi
}

# -----------------------------------------------------------
# 👤 Create superuser
# -----------------------------------------------------------
create_superuser() {
  log "INFO" "Creating superuser '$ADMIN_USER'..."
  export_env_vars

  python3 "$DJANGO_MANAGE" shell -c "
from django.contrib.auth import get_user_model
User = get_user_model()
if not User.objects.filter(username='$ADMIN_USER').exists():
    User.objects.create_superuser('$ADMIN_USER', '$ADMIN_EMAIL', '$ADMIN_PASS')
" >> "$LOG_FILE" 2>&1

  if [[ $? -eq 0 ]]; then
    log "SUCCESS" "Superuser '$ADMIN_USER' created 👑"
  else
    log "ERROR" "Failed to create superuser ❌"
    tail -n 10 "$LOG_FILE"
  fi
}


# -----------------------------------------------------------
# 🎬 Main
# -----------------------------------------------------------
main() {
  mkdir -p "$(dirname "$LOG_FILE")"
  touch "$LOG_FILE"

  log "INFO" "🚀 Bootstrapping LibrePhotos local environment"
  generate_secrets
  reset_postgres_container
  write_env_file
  run_migrations
  create_superuser

  log "SUCCESS" "Local LibrePhotos environment ready! 🖼️"
  log "SUCCESS" "🔐 DB Password: $DB_PASS"
  log "SUCCESS" "👤 Admin: $ADMIN_USER / $ADMIN_PASS"
}


if [[ -f "$VENV_PATH" ]]; then
  log "INFO" "Activating Python virtual environment..."
  source "$VENV_PATH"
else
  log "ERROR" "Virtual environment not found at $VENV_PATH ❌"
  exit 1
fi

main "$@" || {
  log "ERROR" "Sidecar encountered a fatal error ❌"
  exit 0  # Don't break preLaunchTask pipeline
}
