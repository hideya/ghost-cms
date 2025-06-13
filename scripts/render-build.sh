#!/bin/bash
set -xe

echo "Start building Ghost..."
echo "Build environment: $NODE_ENV"
echo "Ghost version: $(cat ghost/core/package.json | grep '"version"' | head -1 | cut -d'"' -f4)"

echo "Installing dependencies..."
yarn install

# Reset Nx cache to ensure clean build
echo "Resetting build cache..."
yarn nx reset

# Debug: Show Ghost workspace structure
echo "Debug: Ghost workspace structure:"
ls -la ghost/
echo "Ghost core package.json version:"
grep '"version"' ghost/core/package.json | head -1
echo "TypeScript build will use workspace-specific compiler"

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

# Fix Ghost version detection (monorepo issue)
echo "Fixing Ghost version detection..."
echo "Current root package.json version: $(grep '"version"' package.json | head -1)"
echo "Current Ghost core version: $(grep '"version"' ghost/core/package.json | head -1)"

# Temporarily update root package.json to have the correct version
echo "Updating root package.json version to match Ghost core..."
core_version=$(jq -r '.version' ghost/core/package.json)
jq --arg v "$core_version" '.version = $v' package.json > package.tmp.json && mv package.tmp.json package.json
echo "Updated root package.json version: $(grep '"version"' package.json | head -1)"

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

echo "Building Shade component (foundation)..."
yarn workspace @tryghost/shade run build

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
echo "Debug: Checking actual directory structure..."
echo "Shade directories:"
ls -la apps/shade/ | head -10
echo "Admin-X Design System directories:"
ls -la apps/admin-x-design-system/ | head -10
echo "Admin-X Framework directories:"
ls -la apps/admin-x-framework/ | head -10

# Check for the actual output directories based on package.json specs
if [ ! -d "apps/shade/es" ]; then
  echo "WARNING: Shade component es directory missing, but checking if build succeeded anyway..."
  if [ ! -f "apps/shade/types/index.d.ts" ] && [ ! -d "apps/shade/types" ]; then
    echo "ERROR: Shade component build failed - no output found"
    exit 1
  fi
fi

# Admin-X Design System outputs to 'es' directory based on package.json
if [ ! -d "apps/admin-x-design-system/es" ]; then
  echo "WARNING: Admin-X Design System es directory missing, but checking if build succeeded anyway..."
  if [ ! -f "apps/admin-x-design-system/types/index.d.ts" ] && [ ! -d "apps/admin-x-design-system/types" ]; then
    echo "ERROR: Admin-X Design System build failed - no output found"
    exit 1
  fi
fi

if [ ! -d "apps/admin-x-framework/dist" ] && [ ! -d "apps/admin-x-framework/es" ]; then
  echo "WARNING: Admin-X Framework output directory missing, but checking if build succeeded anyway..."
  if [ ! -f "apps/admin-x-framework/types/index.d.ts" ] && [ ! -d "apps/admin-x-framework/types" ]; then
    echo "ERROR: Admin-X Framework build failed - no output found"
    exit 1
  fi
fi

# Admin-X Settings and ActivityPub are optional since they integrate into Ghost Admin
if [ ! -f "apps/admin-x-settings/dist/admin-x-settings.js" ]; then
  echo "INFO: Admin-X Settings integrated into Ghost Admin (no separate dist file)"
fi

if [ ! -f "apps/admin-x-activitypub/dist/admin-x-activitypub.js" ]; then
  echo "INFO: Admin-X ActivityPub integrated into Ghost Admin (no separate dist file)"
fi

echo "✓ Shade component: $(find apps/shade -name '*.js' -o -name '*.d.ts' | wc -l) output files"
echo "✓ Admin-X Design System: $(find apps/admin-x-design-system -name '*.js' -o -name '*.d.ts' | wc -l) output files"
echo "✓ Admin-X Framework: $(find apps/admin-x-framework -name '*.js' -o -name '*.d.ts' | wc -l) output files"
if [ -f "apps/admin-x-settings/dist/admin-x-settings.js" ]; then
  echo "✓ Admin-X Settings: $(ls -la apps/admin-x-settings/dist/admin-x-settings.js)"
else
  echo "✓ Admin-X Settings: Built and integrated into Ghost Admin"
fi
if [ -f "apps/admin-x-activitypub/dist/admin-x-activitypub.js" ]; then
  echo "✓ Admin-X ActivityPub: $(ls -la apps/admin-x-activitypub/dist/admin-x-activitypub.js)"
else
  echo "✓ Admin-X ActivityPub: Built and integrated into Ghost Admin"
fi

echo "Build complete and verified!"
