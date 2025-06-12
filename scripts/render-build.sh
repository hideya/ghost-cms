#!/bin/bash
set -xe

echo "Start buiding Ghost..."
echo ".env settings:"
cat .env

echo "Installing dependencies..."
yarn install && yarn nx reset

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
yarn build

echo "Build complete!"
