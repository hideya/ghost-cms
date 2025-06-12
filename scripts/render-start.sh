#!/bin/bash
set -xe

echo "Loading environment variables and starting Ghost..."
cat .env
set -a; source .env; set +a

node ghost/core/index.js
# yarn dev
