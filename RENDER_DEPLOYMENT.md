# Ghost CMS Deployment on Render

This document provides the complete setup for deploying Ghost CMS to Render's free tier using Aiven MySQL and Cloudflare R2.

## Prerequisites

- Ghost CMS repository with Aiven MySQL and R2 configured (following AIVEN_MYSQL_SETUP.md and CLOUDFLARE_R2_SETUP.md)
- Render account
- GitHub repository connected to Render

## Render Configuration

### Node.js Version
Render will automatically detect Node.js version from `engines` in `ghost/core/package.json`:
- Supported: `^18.12.1 || ^20.11.1 || ^22.13.1`
- Recommended: Node.js 20.x (latest LTS)

### Storage Adapter & Render's Ephemeral Filesystem

**Important Note**: Although Render's free tier doesn't support persistent storage, the S3 storage adapter installation works perfectly because:

- **Build Time**: The S3 adapter gets downloaded, compiled, and "baked into" the deployment bundle during the build process
- **Runtime**: Ghost only reads the adapter code (no file modifications needed)
- **File Uploads**: All user files go directly to Cloudflare R2 (external storage)
- **Container Restarts**: The adapter remains available as part of the deployment bundle

This stateless architecture is ideal for Render's platform - no local file persistence required!

### Build Command
```bash
./scripts/render-build.sh
```

### Start Command
```bash
./scripts/render-start.sh
```

### Environment (Select)
- **Environment**: `Node.js`
- **Build Command**: `./scripts/render-build.sh`
- **Start Command**: `./scripts/render-start.sh`

## Secret Files Configuration

In Render dashboard → Your Service → Environment:

**Add Secret File:**
- **Filename**: `.env`
- **Contents**:
```env
# Production Environment
NODE_ENV=production

# Ghost Version (fix for monorepo version mismatch)
GHOST_VERSION=5.122.0

# Server Configuration
server__host=0.0.0.0
server__port=$PORT
url=https://your-project-name-xxxx.onrender.com

# Database Configuration
database__client=mysql2
database__connection__host=your-mysql-instance.aivencloud.com
database__connection__port=25426
database__connection__user=your-username
database__connection__password=your-password
database__connection__database=ghost
database__connection__charset=utf8mb4
database__connection__ssl__rejectUnauthorized=false

# Cloudflare R2 Storage Configuration
storage__active=s3
storage__s3__accessKeyId=your-r2-access-key-id
storage__s3__secretAccessKey=your-r2-secret-access-key
storage__s3__region=auto
storage__s3__bucket=your-r2-bucket-name
storage__s3__endpoint=https://your-specific-hash.r2.cloudflarestorage.com
storage__s3__forcePathStyle=true
storage__s3__assetHost=https://pub-your-specific-hash.r2.dev
```

**Important**: Replace all placeholder values with your actual credentials and URLs.

## Deployment Process

1. **Connect the render branch of your GitHub repo** to Render
2. **Configure the service** with the build/start commands above
3. **Add the `.env` secret file** with production values
4. **Deploy** - Render will automatically build and start your Ghost instance

## Post-Deployment

After successful deployment:
1. **Access your Ghost site**: `https://your-project-name-xxxx.onrender.com`
2. **Access Ghost Admin**: `https://your-project-name-xxxx.onrender.com/ghost/`
3. **Verify file uploads work** by creating a post with images
4. **Check that images are served from R2** (URLs should show your R2 domain)

## Troubleshooting

### Build Failures
- Check Render build logs for specific errors
- Verify all secret files are properly configured
- Ensure GitHub repository has the build scripts

### TypeScript Compilation Issues
If you see `Cannot find module './IdentityTokenService'` error:
- This indicates TypeScript files weren't compiled to JavaScript during build
- The updated `render-build.sh` script includes explicit TypeScript compilation steps
- Check build logs for TypeScript compilation errors
- Verify that `IdentityTokenService.js` exists after build in `ghost/core/core/server/services/identity-tokens/`

### Ghost Admin Version Mismatch
If you see `Client request for 5.122 does not match server version 0.0.0` error:
- This indicates Ghost is reading the version from the wrong package.json file  
- Ghost is reading from the root monorepo package.json (version "0.0.0-private") instead of ghost/core/package.json (version "5.122.0")
- **Fix**: Add `GHOST_VERSION=5.122.0` to your `.env` secret file in Render
- This explicitly tells Ghost what version to report to the admin interface
- After adding this environment variable, redeploy your Ghost service
- The updated build script now includes `yarn workspace ghost-admin run build`
- Check build logs to ensure Ghost Admin build completes successfully
- Verify that `ghost/admin/dist/` directory exists after build

### Admin-X Components Build Issues
If you see `ENOENT: no such file or directory, open '../../apps/admin-x-settings/dist/admin-x-settings.js'` error:
- This indicates Admin-X components weren't built before Ghost Admin tried to use them
- The updated build script now explicitly builds Admin-X components first
- Check build logs to ensure all Admin-X components build successfully
- Verify that `apps/admin-x-settings/dist/admin-x-settings.js` and other Admin-X dist files exist

### Database Connection Issues
- Verify Aiven MySQL credentials in secret file
- Check that Aiven allows connections from Render's IP ranges
- Test database connectivity from local environment first

### Storage Issues
- Verify R2 bucket has public access enabled
- Check R2 credentials and endpoint URLs
- Ensure `storage__s3__assetHost` matches your public R2 URL

### Service Won't Start
- Check that `server__port=$PORT` is set correctly
- Verify `server__host=0.0.0.0` for Render compatibility
- Check start command logs in Render dashboard

## Cost Breakdown (All Free Tier)

- **Render**: 750 hours/month free
- **Aiven MySQL**: Permanent free tier
- **Cloudflare R2**: 10GB storage + unlimited egress
- **Total monthly cost**: $0

This setup provides a production-ready Ghost CMS deployment without any recurring costs!
