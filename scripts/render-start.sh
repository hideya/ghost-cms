#!/bin/bash
set -xe

echo "Starting Ghost production server..."

echo "Loading environment variables..."
set -a; source .env; set +a

echo "Environment check:"
echo "NODE_ENV: $NODE_ENV"
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

# Verify critical files exist
echo "Checking critical files..."
if [ ! -f "ghost/core/core/server/services/identity-tokens/IdentityTokenService.js" ]; then
  echo "ERROR: IdentityTokenService.js missing - build may have failed"
  exit 1
fi

# Start Ghost with memory optimization for Render free tier
echo "Starting Ghost with memory optimization..."
node --max_old_space_size=460 ghost/core/index.js
