#!/bin/bash
set -xe

echo "Starting Ghost production server..."

echo "Loading environment variables..."
set -a; source .env; set +a

echo "Environment check:"
echo "NODE_ENV: $NODE_ENV"
echo "GHOST_VERSION: $GHOST_VERSION"
echo "PORT: $PORT"
echo "URL: $url"
echo "Database client: $database__client"
echo "Database host: $database__connection__host"
echo "Database port: $database__connection__port"
echo "Database name: $database__connection__database"
echo "Storage active: $storage__active"
echo "Storage region: $storage__s3__region"
echo "Storage bucket: $storage__s3__bucket"
echo "Storage endpoint: $storage__s3__endpoint"
echo "Storage asset host: $storage__s3__assetHost"
# Note: Intentionally NOT showing passwords, API keys, or other secrets

# Fix Ghost version detection (monorepo issue)
echo "Fixing Ghost version detection..."
echo "Current root package.json version: $(grep '"version"' package.json | head -1)"
echo "Current Ghost core version: $(grep '"version"' ghost/core/package.json | head -1)"

# Temporarily update root package.json to have the correct version
echo "Updating root package.json version to match Ghost core..."
sed -i 's/"version": "0.0.0-private"/"version": "5.122.0"/' package.json
echo "Updated root package.json version: $(grep '"version"' package.json | head -1)"

# Verify critical files exist
echo "Checking critical files..."
if [ ! -f "ghost/core/core/server/services/identity-tokens/IdentityTokenService.js" ]; then
  echo "ERROR: IdentityTokenService.js missing - build may have failed"
  exit 1
fi

# Start Ghost with memory optimization for Render free tier
echo "Starting Ghost with memory optimization..."
node --max_old_space_size=460 ghost/core/index.js
