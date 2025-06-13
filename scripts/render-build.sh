#!/bin/bash
set -xe

echo "Start buiding Ghost..."
echo ".env settings:"
cat .env

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

# First, ensure TypeScript compilation happens
echo "Compiling TypeScript files..."
yarn workspace ghost run build:tsc

# Check if TypeScript compilation succeeded
if [ ! -f "ghost/core/core/server/services/identity-tokens/IdentityTokenService.js" ]; then
  echo "ERROR: TypeScript compilation failed - IdentityTokenService.js not created"
  echo "Attempting alternative compilation..."
  cd ghost/core && npx tsc && cd ../..
fi

# Build assets and other components
echo "Building Ghost assets..."
yarn workspace ghost run build:assets

# Build the entire Ghost application (all workspaces)
echo "Building full Ghost application..."
yarn build

# Verify that critical JavaScript files were created
echo "Verifying build artifacts..."
if [ ! -f "ghost/core/core/server/services/identity-tokens/IdentityTokenService.js" ]; then
  echo "ERROR: IdentityTokenService.ts was not compiled to .js"
  echo "Listing files in identity-tokens directory:"
  ls -la ghost/core/core/server/services/identity-tokens/
  exit 1
fi

echo "Build complete and verified!"
