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
yarn install && yarn build
popd

echo "Setting up storage adapter..."
mkdir -p content/adapters/storage/s3
cp /tmp/ghost-s3-adapter/index.js content/adapters/storage/s3/
cp /tmp/ghost-s3-adapter/package.json content/adapters/storage/s3/
cp -r /tmp/ghost-s3-adapter/node_modules content/adapters/storage/s3/

echo "Creating adapter copy for Ghost 5.x dev mode bug workaround..."
mkdir -p ghost/core/content/adapters/storage
cp -rf content/adapters/storage/s3 ghost/core/content/adapters/storage/

echo "Cleaning up /tmp/ghost-s3-adapter..."
rm -rf /tmp/ghost-s3-adapter

echo "Loading environment variables..."
set -a; source .env; set +a

echo "Environment check:"
echo "NODE_ENV: $NODE_ENV"
echo "PORT: $PORT"
echo "URL: $url"
echo "Database client: $database__client"
echo "Storage active: $storage__active"
# Note: Intentionally NOT showing passwords, API keys, or other secrets

# Set production environment
echo "Setting production environment..."
export NODE_ENV=production

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

echo "Build complete using Nx automatic dependency resolution!"
