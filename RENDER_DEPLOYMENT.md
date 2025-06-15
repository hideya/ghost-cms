# Ghost CMS Deployment on Render

This document provides the complete setup for deploying Ghost CMS to Render's free tier using Aiven MySQL and Cloudflare R2.

## Prerequisites

- Ghost CMS repository with Aiven MySQL and R2 configured (following AIVEN_MYSQL_SETUP.md and CLOUDFLARE_R2_SETUP.md)
- Email service configured for Ghost admin authentication (Gmail SMTP recommended - see Email Configuration section below)
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

**Note**: The build script includes explicit ordering of Admin-X component builds. See "Appendix: Why Explicit Admin-X Component Ordering is Required" for technical details.

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

# Email Configuration (Required for admin login)
mail__transport=SMTP
mail__from=your-email@gmail.com
mail__options__service=Gmail
mail__options__auth__user=your-email@gmail.com
mail__options__auth__pass="your gmail app password"
```

**Important**: Replace all placeholder values with your actual credentials and URLs.

## Deployment Process

1. **Connect the render branch of your GitHub repo** to Render
2. **Configure the service** with the build/start commands above
3. **Add the `.env` secret file** with production values
4. **Deploy** - Render will automatically build and start your Ghost instance.
   This process can take more than 10 minutes.

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
- **Fix**: The updated build and start scripts now automatically fix this by updating the root package.json version during deployment
- The scripts temporarily change the root package.json version from "0.0.0-private" to "5.122.0"
- This ensures Ghost reports the correct version to the admin interface
- After redeploying with the updated scripts, the admin interface should work properly

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

## Email Configuration

Ghost requires email functionality for admin authentication when connecting to existing databases. When you try to log into Ghost Admin, it sends a "magic link" to your email instead of using password-based login.

### Recommended: Gmail SMTP (Free)

Gmail provides 100 emails/day permanently free, which is perfect for Ghost admin use.

**Setup Steps:**
1. **Enable 2-Step Verification (2FA)** on your Gmail account
   - Go to https://myaccount.google.com/signinoptions/twosv and follow the instructions
2. **Generate App Password**:
   - Go to https://myaccount.google.com/apppasswords and follow the instructions
3. **Use the credentials** in your `.env` file as shown above

### Alternative: Brevo (formerly Sendinblue)

If you prefer a dedicated transactional email service:
- **Free tier**: 300 emails/day permanently
- **Setup**: Sign up at [brevo.com](https://www.brevo.com) and get SMTP credentials
- **Configuration**:
```env
mail__transport=SMTP
mail__from=noreply@yourdomain.com
mail__options__host=smtp-relay.brevo.com
mail__options__port=587
mail__options__auth__user=your-brevo-login-email
mail__options__auth__pass=your-brevo-smtp-key
```

### Alternative: Resend

For a modern developer-focused service:
- **Free tier**: 3,000 emails/month permanently
- **Setup**: Sign up at [resend.com](https://resend.com) and get API key
- **Configuration**: Requires API-based setup (more complex)

**Note**: Without email configuration, you won't be able to log into Ghost Admin on Render, as the system will try to send magic link emails and fail.

## Cost Breakdown (All Free Tier)

- **Render**: 750 hours/month free
- **Aiven MySQL**: Permanent free tier
- **Cloudflare R2**: 10GB storage + unlimited egress
- **Gmail SMTP**: 100 emails/day permanently free
- **Total monthly cost**: $0

This setup provides a production-ready Ghost CMS deployment without any recurring costs!

## Appendix: Why Explicit Admin-X Component Ordering is Required

### The Core Issue

The most complex aspect of building Ghost from source for production deployment is the **explicit ordering of Admin-X component builds** in `render-build.sh`. This complexity stems from a fundamental difference in build environments:

**Ghost's Standard Build Process:**
- Runs **locally** on development machines or dedicated build servers
- Has **full Nx daemon functionality** with automatic dependency resolution
- Can leverage **complete Nx toolchain** for build orchestration
- Builds locally, then deploys pre-built artifacts

**Our Containerized Build Process:**
- Runs **inside Docker containers** (Render's build environment)
- **Nx daemon is disabled in Docker containers** ([GitHub Issue #14126](https://github.com/nrwl/nx/issues/14126))
- **No automatic dependency resolution** → must manually specify build order
- Must build and deploy directly from the container

### Why This Matters for Admin-X Components

**Ghost Admin (Ember.js) requires pre-built Admin-X components:**
```
Ghost Admin expects these files to exist:
├── apps/admin-x-settings/dist/admin-x-settings.js
├── apps/admin-x-activitypub/dist/admin-x-activitypub.js
├── apps/posts/dist/posts.js
└── apps/stats/dist/stats.js
```

**Without explicit ordering, builds fail with:**
```
ENOENT: no such file or directory, open '../../apps/admin-x-settings/dist/admin-x-settings.js'
```

**This happens because:**
1. **Nx daemon** would normally handle dependency resolution automatically
2. **In containers**, daemon is disabled so no automatic ordering occurs
3. **Ghost Admin builds first** but can't find the Admin-X components it needs
4. **Build fails** unless we manually ensure Admin-X components are built first

### Our Solution: Manual Dependency Resolution

```bash
# Manually replicate what Nx daemon would do automatically:
yarn workspace @tryghost/shade run build
yarn workspace @tryghost/admin-x-design-system run build
yarn workspace @tryghost/admin-x-framework run build
yarn workspace @tryghost/admin-x-settings run build
yarn workspace @tryghost/admin-x-activitypub run build
yarn workspace @tryghost/posts run build
yarn workspace @tryghost/stats run build
yarn workspace ghost-admin run build  # Now has all dependencies
```

### Why This Approach Works

- **Replicates Nx daemon functionality** manually in containerized environments
- **Uses official component build scripts** (same as Ghost's internal process)
- **Ensures correct dependency order** for Admin-X → Ghost Admin
- **Enables PaaS deployment** where container builds are required
- **Future-proof** as it follows Ghost's component architecture

### Conclusion

The explicit ordering isn't a flaw in our approach - it's **adapting Ghost's local build process to work in containerized environments**. We're manually providing the dependency resolution that Nx daemon would handle automatically in Ghost's standard builds.

This complexity will remain necessary until either:
1. Nx enables daemon functionality in Docker containers, or  
2. Ghost provides official containerized build support for source deployments

For now, this manual approach seems the most reliable way to deploy custom Ghost builds to container-based PaaS platforms like Render.
