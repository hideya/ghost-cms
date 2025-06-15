#!/bin/bash
set -xe

echo "Starting Ghost production server..."
echo "Node environment: $NODE_ENV"
echo "Ghost version: $(cat ghost/core/package.json | grep '"version"' | head -1 | cut -d'"' -f4)"

if [ ! -f .env ]; then
  echo ".env file does not exist."
  echo "Enter the contents manually from the Render dashboard as a Secret File"
  exit 1
fi

# Set production environment
export NODE_ENV=production

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

# Fix Ghost version detection (monorepo issue)
echo "Checking Ghost root and core versions ..."
echo "Current root package.json version: $(grep '"version"' package.json | head -1)"
echo "Current Ghost core version: $(grep '"version"' ghost/core/package.json | head -1)"

root_version=$(jq -r '.version' package.json)
core_version=$(jq -r '.version' ghost/core/package.json)
if [ "$root_version" != "$core_version" ]; then
  echo "Versions are not the same. Will fail to show the admin page. Exiting."
  exit 1
fi

# Verify critical files exist
echo "Checking critical files..."
if [ ! -f "ghost/core/core/server/services/identity-tokens/IdentityTokenService.js" ]; then
  echo "ERROR: IdentityTokenService.js missing - build may have failed"
  exit 1
fi

# Start Ghost with memory optimization for Render free tier
echo "Starting Ghost with memory optimization..."
# Limits the "old space" heap memory that the Node.js V8 engine can use for long-lived JavaScript objects
# This 460MB limitation for 512MB system is seen in official Heroku documentation and widely used in practice
node --max_old_space_size=460 ghost/core/index.js
