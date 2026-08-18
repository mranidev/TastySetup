#!/usr/bin/env bash
#
# Deploy TastySetup to Wasmer Edge.
#
# Builds a clean staging copy (excluding secrets and runtime junk)
# and runs `wasmer deploy`. Requires the Wasmer CLI and a logged-in account.
#
# Usage:  bash deploy.sh [--bump]
#   --bump   bump the package patch version (default)

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
STAGE="${STAGE_DIR:-/tmp/tastysetup-deploy}"

BUMP="--bump"
if [[ "${1:-}" == "--no-bump" ]]; then
  BUMP=""
fi

echo "==> Cleaning staging dir: $STAGE"
rm -rf "$STAGE"
mkdir -p "$STAGE"

echo "==> Copying project to staging (excluding secrets and runtime junk)"
rsync -a \
  --exclude '.freebuff/' \
  --exclude '.env' \
  --exclude '.env.testing' \
  --exclude 'node_modules/' \
  --exclude '.git/' \
  --exclude 'storage/logs/*.log' \
  --exclude 'storage/framework/cache/data/*' \
  --exclude 'storage/framework/cache/*.php' \
  --include 'storage/framework/sessions/.gitignore' \
  --exclude 'storage/framework/sessions/*' \
  --include 'storage/framework/views/.gitignore' \
  --exclude 'storage/framework/views/*' \
  --exclude 'storage/igniter/cache/*' \
  --exclude 'storage/igniter/combiner/*' \
  "$ROOT/" "$STAGE/"

# Guarantee runtime dirs exist
mkdir -p "$STAGE/storage/framework/views" "$STAGE/storage/framework/sessions" "$STAGE/storage/logs"
touch "$STAGE/storage/framework/views/.gitkeep" "$STAGE/storage/framework/sessions/.gitkeep"

# Publish vendor assets (TastyIgniter public assets)
cp "$ROOT/.env" "$STAGE/.env" 2>/dev/null || true
cd "$STAGE"
php artisan vendor:publish --tag=laravel-assets --force 2>/dev/null || true
rm -f "$STAGE/.env"
cd "$ROOT"

# Prune dev-only vendor packages
cp "$ROOT/.env" "$STAGE/.env"
cd "$STAGE"
composer install --no-dev --no-interaction --no-progress --prefer-dist 2>&1 | tail -3
rm "$STAGE/.env"
cd "$ROOT"

# Sanity checks
test ! -f "$STAGE/.env" || { echo "ERROR: .env must not be packaged"; exit 1; }
test -d "$STAGE/storage/framework/views" || { echo "ERROR: storage/framework/views missing"; exit 1; }
test -d "$STAGE/storage/framework/sessions" || { echo "ERROR: storage/framework/sessions missing"; exit 1; }

echo "==> Deploying to Wasmer Edge"
cd "$STAGE"
wasmer deploy --non-interactive --publish-package ${BUMP}

echo "==> Done. Live at https://tastysetup.wasmer.app"
