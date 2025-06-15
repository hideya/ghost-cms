#!/bin/bash
set -xe

echo "Start building Ghost..."
echo "Build environment: $NODE_ENV"
echo "Ghost version: $(cat ghost/core/package.json | grep '"version"' | head -1 | cut -d'"' -f4)"

if [ ! -f .env ]; then
  echo ".env file does not exist."
  echo "Enter the contents manually from the Render dashboard as a Secret File"
  exit 1
fi

echo "Installing dependencies..."
yarn install

# Reset Nx cache to ensure clean build
echo "Resetting build cache..."
yarn nx reset

echo "Installing S3 storage adapter..."
pushd /tmp
git clone https://github.com/hideya/ghost-s3-adapter.git
cd ghost-s3-adapter
ls -al
yarn install && yarn build
ls -al
popd

echo "Setting up storage adapter..."
mkdir -p content/adapters/storage/s3
cp /tmp/ghost-s3-adapter/index.js content/adapters/storage/s3/
cp /tmp/ghost-s3-adapter/package.json content/adapters/storage/s3/
cp -r /tmp/ghost-s3-adapter/node_modules content/adapters/storage/s3/

echo "Creating adapter copy for Ghost 5.x dev mode bug workaround..."
mkdir -p ghost/core/content/adapters/storage
cp -rf content/adapters/storage/s3 ghost/core/content/adapters/storage/
ls -al ghost/core/content/adapters/storage/s3/

echo "Cleaning up /tmp/ghost-s3-adapter..."
rm -rf /tmp/ghost-s3-adapter

echo "Loading environment variables..."
set -a; source .env; set +a

# Set production environment
echo "Setting production environment..."
export NODE_ENV=production

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
echo "Fixing Ghost version detection..."
echo "Current root package.json version: $(grep '"version"' package.json | head -1)"
echo "Current Ghost core version: $(grep '"version"' ghost/core/package.json | head -1)"

# Temporarily update root package.json to have the correct version
echo "Updating root package.json version to match Ghost core..."
core_version=$(jq -r '.version' ghost/core/package.json)
jq --arg v "$core_version" '.version = $v' package.json > package.tmp.json && mv package.tmp.json package.json
echo "Updated root package.json version: $(grep '"version"' package.json | head -1)"

# Use Nx's automatic dependency resolution (works even without daemon)
echo "Building Ghost using Nx automatic dependency resolution..."
yarn build

# Build Ghost core components that are normally handled by the archive target
# See: ghost/core/package.json
echo "Building Ghost core assets and TypeScript..."
yarn workspace ghost run build:assets
yarn workspace ghost run build:tsc

# Verify that critical JavaScript files were created
echo "Verifying build artifacts..."
if [ ! -f "ghost/core/core/server/services/identity-tokens/IdentityTokenService.js" ]; then
  echo "ERROR: IdentityTokenService.js missing - TypeScript compilation failed"
  exit 1
fi

if [ ! -d "ghost/admin/dist" ]; then
  echo "ERROR: Ghost Admin dist directory missing - Admin build failed"
  exit 1
fi

echo "Checking Ghost Admin build output..."
ls -la ghost/admin/dist/ | head -10

echo "Ghost core: TypeScript compiled successfully"
echo "Ghost admin: $(ls ghost/admin/dist/*.js 2>/dev/null | wc -l) JavaScript files built"
echo "Ghost assets: $(ls ghost/core/core/frontend/public/*.min.* 2>/dev/null | wc -l) minified assets"

echo "Build complete!"
