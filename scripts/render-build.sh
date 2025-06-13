#!/bin/bash
set -xe

echo "Start building Ghost..."
echo "Build environment: $NODE_ENV"
echo "Ghost version: $(cat ghost/core/package.json | grep '"version"' | head -1 | cut -d'"' -f4)"
# Do NOT display .env contents in logs for security

echo "Installing dependencies..."
yarn install

# Reset Nx cache to ensure clean build
echo "Resetting build cache..."
yarn nx reset

# Debug: Show TypeScript version and Ghost workspace structure
echo "Debug: TypeScript information:"
echo "TypeScript version: $(yarn --silent typescript --version || echo 'TypeScript not found in PATH')"
echo "Ghost workspace structure:"
ls -la ghost/
echo "Ghost core package.json:"
cat ghost/core/package.json | grep -A5 -B5 "scripts\|typescript"

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
ls -al content/adapters/storage/s3

echo "Creating symlink for Ghost 5.x dev mode bug workaround..."
mkdir -p ghost/core/content/adapters/storage
# ln -sf $(pwd)/content/adapters/storage/s3 ghost/core/content/adapters/storage/s3
cp -rf content/adapters/storage/s3 ghost/core/content/adapters/storage/
ls -al ghost/core/content/adapters/storage/s3/

echo "Cleaning up /tmp/ghost-s3-adapter..."
rm -rf /tmp/ghost-s3-adapter

echo "Loading environment variables and building Ghost..."
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

# Production optimizations
echo "Setting production environment..."
export NODE_ENV=production

# Clear any existing builds
echo "Cleaning previous builds..."
yarn build:clean || echo "No previous builds to clean"

# First, ensure TypeScript compilation happens
echo "Compiling TypeScript files..."
yarn workspace ghost run build:tsc

# Check if TypeScript compilation succeeded
if [ ! -f "ghost/core/core/server/services/identity-tokens/IdentityTokenService.js" ]; then
  echo "ERROR: TypeScript compilation failed - IdentityTokenService.js not created"
  echo "Attempting alternative compilation..."
  cd ghost/core && npx tsc && cd ../..
fi

# Build Admin-X components in correct dependency order
echo "Building Admin-X components in dependency order..."

echo "Building Admin-X Design System (foundation)..."
yarn workspace @tryghost/admin-x-design-system run build

echo "Building Admin-X Framework (core)..."
yarn workspace @tryghost/admin-x-framework run build

echo "Building Admin-X Settings..."
yarn workspace @tryghost/admin-x-settings run build

echo "Building Admin-X ActivityPub..."
yarn workspace @tryghost/admin-x-activitypub run build

echo "Building Posts component..."
yarn workspace @tryghost/posts run build

echo "Building Stats component..."
yarn workspace @tryghost/stats run build

# Build Ghost Admin (Ember.js frontend)
echo "Building Ghost Admin interface..."
yarn workspace ghost-admin run build

# Build assets and other components
echo "Building Ghost assets..."
yarn workspace ghost run build:assets

# Build the entire Ghost application (all workspaces)
echo "Building full Ghost application..."
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

echo "Checking Admin-X components were built..."
if [ ! -d "apps/admin-x-design-system/dist" ]; then
  echo "ERROR: Admin-X Design System build failed - missing dist directory"
  exit 1
fi

if [ ! -d "apps/admin-x-framework/dist" ]; then
  echo "ERROR: Admin-X Framework build failed - missing dist directory"
  exit 1
fi

if [ ! -f "apps/admin-x-settings/dist/admin-x-settings.js" ]; then
  echo "ERROR: Admin-X Settings build failed - missing admin-x-settings.js"
  exit 1
fi

if [ ! -f "apps/admin-x-activitypub/dist/admin-x-activitypub.js" ]; then
  echo "ERROR: Admin-X ActivityPub build failed - missing admin-x-activitypub.js"
  exit 1
fi

echo "✓ Admin-X Design System: $(ls -la apps/admin-x-design-system/dist/ | wc -l) files"
echo "✓ Admin-X Framework: $(ls -la apps/admin-x-framework/dist/ | wc -l) files"
echo "✓ Admin-X Settings: $(ls -la apps/admin-x-settings/dist/admin-x-settings.js)"
echo "✓ Admin-X ActivityPub: $(ls -la apps/admin-x-activitypub/dist/admin-x-activitypub.js)"

echo "Build complete and verified!"
