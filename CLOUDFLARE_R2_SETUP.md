# Ghost CMS Setup with Cloudflare R2 Storage

This document explains how to configure Ghost (version 5.122.0) to use Cloudflare R2 object storage system instead of local storage for media files.
It is a companion to AIVEN_MYSQL_SETUP.md, which describes setting up Ghost to work with a MySQL database hosted on Aiven.
This setup is essential for running multiple Ghost instances that share the same database and ensures that all instances can access the same uploaded files via cloud storage.

## Why Use Cloudflare R2?

- **Zero egress fees** - No charges for data transfer out
- **S3 compatible** - Works with existing S3 storage adapters
- **Generous free tier** - 10GB storage, 1M Class A operations, 10M Class B operations per month (permanent)
- **Global performance** - Leverages Cloudflare's 330+ data center network
- **Cost effective** - Often 90%+ cheaper than AWS S3 for many use cases
- **Battle-tested adapters** - Use proven S3 adapters with years of real-world usage
- **Future flexibility** - S3-compatible approach works with multiple storage providers

## Prerequisites

- Ghost CMS already set up and running (this guide assumes you followed AIVEN_MYSQL_SETUP.md)
- Cloudflare account with R2 enabled
- R2 bucket created with API token

## Setup Steps

### 1. Install the S3-Compatible Storage Adapter

We'll use the battle-tested `gumlet/ghost-s3-adapter` which works excellently with Cloudflare R2 and has years of real-world usage.

**Note:** The installation process below may seem complex, but it's designed to work with Ghost's plugin architecture.
See [Appendix: Why This Installation Process](#appendix-why-this-installation-process) for technical details.

Navigate to your Ghost installation directory and install the storage adapter:

```bash
# Navigate to your Ghost installation
cd /path/to/your/ghost-cms

# Build storage adapter from the repo that includes debug logging
# We work in /tmp to avoid yarn workspace conflicts:
# - Ghost uses yarn workspaces (monorepo structure)
# - Working in /tmp keeps Ghost's dependencies clean
# - Building from source ensures latest improvements
pushd /tmp
git clone https://github.com/hideya/ghost-s3-adapter.git
cd ghost-s3-adapter
yarn install
yarn build
popd

# Create storage adapter directory and copy built files
mkdir -p content/adapters/storage/s3
cp /tmp/ghost-s3-adapter/index.js content/adapters/storage/s3/
cp /tmp/ghost-s3-adapter/package.json content/adapters/storage/s3/
cp -r /tmp/ghost-s3-adapter/node_modules content/adapters/storage/s3/

# Verify installation
ls -la content/adapters/storage/s3/

# Create symbolic link for development mode (Ghost 5.x bug workaround)
# See: https://github.com/TryGhost/Ghost/issues/22883
mkdir -p ghost/core/content/adapters/storage
ln -sf $(pwd)/content/adapters/storage/s3 ghost/core/content/adapters/storage/s3

# Verify symbolic link
ls -la ghost/core/content/adapters/storage/

# Cleanup temporary files
rm -rf /tmp/ghost-s3-adapter
```

### 2. Configure Environment Variables

Add the following S3-compatible Cloudflare R2 configuration to your `.env` file in the Ghost project root:

```env
# Cloudflare R2 Storage Configuration (S3-Compatible)
storage__active=s3
storage__s3__accessKeyId=r2-access-key-id-from-your-api-token
storage__s3__secretAccessKey=r2-secret-access-key-from-your-api-token
storage__s3__region=auto
storage__s3__bucket=ghost-test
storage__s3__endpoint=https://some_specific_hash.r2.cloudflarestorage.com
storage__s3__forcePathStyle=true
# Required: Enable "Public Access" in your R2 bucket settings to get this public URL
storage__s3__assetHost=https://pub-some_specific_hash.r2.dev

# Optional: Configure for different media types
# storage__media__adapter=s3
# storage__files__adapter=s3

# Optional: S3/R2-specific settings
# storage__s3__pathPrefix=content
# storage__s3__acl=public-read
```

**Environment Variable Explanations:**
- **`storage__active`**: Sets the primary storage adapter to S3 (works with R2)
- **`storage__s3__accessKeyId`**: R2 Access Key ID from your API token
- **`storage__s3__secretAccessKey`**: R2 Secret Access Key from your API token
- **`storage__s3__region`**: Set to "auto" for R2 (required but not used)
- **`storage__s3__bucket`**: Your R2 bucket name
- **`storage__s3__endpoint`**: Your R2 jurisdiction-specific endpoint URL
- **`storage__s3__forcePathStyle`**: Uses path-style URLs (required for R2)
- **`storage__media__adapter`**: Configures media files (videos) to use S3/R2
- **`storage__files__adapter`**: Configures file uploads to use S3/R2
- **`storage__s3__assetHost`**: R2 public URL for serving files to browsers (requires enabling public access on bucket)

**Important Note**: You must enable public access on your R2 bucket to obtain the public URL for `storage__s3__assetHost`. See "Images Not Displaying (Authorization Errors)" in the Troubleshooting section for step-by-step instructions.
- **`storage__s3__pathPrefix`**: Optional prefix for organizing files
- **`storage__s3__acl`**: Access control level for uploaded files

### 3. Update Your Cloudflare R2 Configuration

Replace the placeholder values in your `.env` file with your actual R2 credentials:

```env
# Replace with your actual values:
storage__s3__bucket=ghost-test
storage__s3__endpoint=https://some_specific_hash.r2.cloudflarestorage.com
storage__s3__assetHost=https://pub-some_specific_hash.r2.dev
storage__s3__accessKeyId=r2-access-key-id-from-your-api-token
storage__s3__secretAccessKey=r2-secret-access-key-from-your-api-token
```

**Security Note**: The credentials shown above are examples. Never commit real credentials to version control.

### 4. Test the Configuration

Before starting Ghost, test that your environment variables are properly loaded:

```bash
# Load environment variables
set -a; source .env; set +a

# Verify R2 configuration is loaded
set | grep "storage__"
```

### 5. Start Ghost with R2 Storage

```bash
# Load environment variables and start Ghost
set -a; source .env; set +a
yarn dev
```

### 6. Verify R2 Integration

1. Access Ghost Admin: http://localhost:2368/ghost/
2. Create a new post
3. Upload an image or media file
4. Verify the file appears in your Cloudflare R2 bucket
5. Check that the image displays correctly in your post

The uploaded file URLs should follow this pattern:
```
https://pub-your-specific-hash.r2.dev/2025/06/your-image.jpg
```

## Important Notes

### Multi-Instance Considerations
- All Ghost instances sharing the database should use the **same R2 configuration**
- Ensure all instances have access to the same R2 bucket
- Files uploaded by one instance will be immediately available to all other instances

### Migration from Local Storage
If you have existing local files, you'll need to migrate them to R2:
1. Use Cloudflare's R2 migration tools
2. Upload existing files manually to maintain the same directory structure
3. Update database references if needed (usually not required)

### Performance Optimization
- Enable **Ghost's image optimization** with `ghostResize=true`
- Consider enabling **responsive images** for better performance
- Use **custom domains** with R2 for better branding and caching

### Security Considerations
- Keep your R2 credentials secure and never commit them to version control
- Use separate R2 buckets for different environments (development, staging, production)
- Consider implementing bucket policies for additional security
- Regularly rotate your API tokens

## Troubleshooting

### Images Not Displaying (Authorization Errors)

If uploaded images appear broken or show XML "Authorization" errors when accessed directly:

**Problem**: Your R2 bucket is not configured for public access. By default, R2 buckets are private and require authentication to access files.

**Solution**: Enable public access on your R2 bucket:

1. **Go to Cloudflare Dashboard → R2 Object Storage**
2. **Select your bucket** (e.g., `ghost-test`)
3. **Navigate to Settings → Public access**
4. **Click "Allow Access"** to enable public development URL
5. **Copy the generated public URL** (e.g., `https://pub-ff85e8926b6746088ce151658a310401.r2.dev`)
6. **Update your `.env` file** with the public URL:
   ```env
   storage__s3__assetHost=https://pub-ff85e8926b6746088ce151658a310401.r2.dev
   ```
7. **Restart Ghost** to apply the new configuration

**Note**: The public development URL allows direct browser access to your uploaded files, which is required for images to display properly in Ghost.

### Storage Adapter Not Found (Ghost 5.x Development Mode)

If you see an error like:
```
Unable to find storage adapter s3 in ,/path/to/ghost/core/content/adapters/,/path/to/ghost/core/core/server/adapters/
```

This is a [known bug in Ghost 5.x](https://github.com/TryGhost/Ghost/issues/22883) where development mode looks for adapters in the wrong location. The symbolic link step in our installation process should resolve this, but if you still have issues:

```bash
# Ensure the symbolic link exists and points to the right place
ls -la ghost/core/content/adapters/storage/s3

# If the link is broken, recreate it
rm -f ghost/core/content/adapters/storage/s3
ln -sf $(pwd)/content/adapters/storage/s3 ghost/core/content/adapters/storage/s3
```

### Storage Adapter Not Found
```bash
# Verify the adapter directory exists and has the correct structure
ls -la content/adapters/storage/s3/
# Should show: index.js, package.json, and other adapter files
```

### Upload Errors
```bash
# Check Ghost logs for specific error messages
tail -f content/logs/ghost.log

# Common issues:
# - Incorrect endpoint URL
# - Invalid credentials
# - Bucket doesn't exist
# - Insufficient permissions
```

### Environment Variables Not Loading
```bash
# Verify environment variables are set correctly
set | grep -E "storage__"

# If variables aren't showing, check:
# - .env file exists in project root
# - No syntax errors in .env file
# - Variables are properly exported: set -a; source .env; set +a
```

### Image URLs Not Working
- Verify bucket public access settings in Cloudflare dashboard
- Check that the R2 endpoint URL is correct
- Ensure the bucket name matches your configuration

### Permission Issues
```bash
# Fix file permissions if needed
sudo chown -R ghost:ghost content/adapters/storage/s3/
```

## Configuration File Alternative

Instead of environment variables, you can configure R2 in your Ghost config file. Add this to `config.production.js`:

```javascript
{
  // ... other config
  "storage": {
    "active": "s3",
    "s3": {
      "accessKeyId": "r2-access-key-id-from-your-api-token",
      "secretAccessKey": "r2-secret-access-key-from-your-api-token",
      "region": "auto",
      "bucket": "your-r2-bucket-name",
      "endpoint": "https://your-specific-hash.r2.cloudflarestorage.com",
      "forcePathStyle": true,
      "assetHost": "https://pub-your-specific-hash.r2.dev"
    },
    "media": {
      "adapter": "s3"
    },
    "files": {
      "adapter": "s3"
    }
  }
}
```

**Note**: Using environment variables is recommended for security and flexibility across environments.

## Cost Optimization Tips

### Free Tier Limits
Cloudflare R2 free tier includes:
- **10GB** storage (permanent)
- **1 million** Class A operations per month (PUT, POST, COPY, DELETE)
- **10 million** Class B operations per month (GET, HEAD)
- **Unlimited egress** (data transfer out)

### Monitoring Usage
1. Check your R2 usage in the Cloudflare dashboard
2. Set up alerts when approaching free tier limits
3. Monitor operation counts to optimize usage

### Optimization Strategies
- Enable Ghost image optimization to reduce storage needs
- Use appropriate image formats (WebP when supported)
- Implement proper caching headers
- Consider using Cloudflare's image optimization features

## Version Information

This setup was tested with:
- Ghost CMS version 5.122.0
- Cloudflare R2 (S3-compatible API)
- `gumlet/ghost-s3-adapter` (S3-compatible adapter)
- Node.js with Yarn package manager

## Quick Reference

For users who want to repeat the setup process:

```bash
# 1. Install improved S3 adapter for R2
cd /path/to/your/ghost-cms
# Build storage adapter from the repo that includes debug logging
pushd /tmp
git clone https://github.com/hideya/ghost-s3-adapter.git
cd ghost-s3-adapter && yarn install && yarn build
popd
mkdir -p content/adapters/storage/s3
cp /tmp/ghost-s3-adapter/index.js content/adapters/storage/s3/
cp /tmp/ghost-s3-adapter/package.json content/adapters/storage/s3/
cp -r /tmp/ghost-s3-adapter/node_modules content/adapters/storage/s3/
# Create symlink for Ghost 5.x dev mode bug workaround
mkdir -p ghost/core/content/adapters/storage
ln -sf $(pwd)/content/adapters/storage/s3 ghost/core/content/adapters/storage/s3
# Cleanup
rm -rf /tmp/ghost-s3-adapter

# 2. Configure environment (edit .env with your R2 credentials)
# Add storage__active=s3 and other S3/R2 settings
# Don't forget to enable public access on your R2 bucket!

# 3. Start Ghost
cd /path/to/ghost-cms
set -a; source .env; set +a
yarn dev

# 4. Test upload in Ghost Admin at http://localhost:2368/ghost/
```

## References

- [Cloudflare R2 Documentation](https://developers.cloudflare.com/r2/)
- [Ghost Storage Adapter Documentation](https://ghost.org/docs/config/#storage)
- [gumlet/ghost-s3-adapter GitHub Repository](https://github.com/gumlet/ghost-s3-adapter)
- [Cloudflare R2 S3 API Compatibility](https://developers.cloudflare.com/r2/api/s3/api/)
- [Cloudflare R2 vs AWS S3 Comparison](https://www.cloudflare.com/pg-cloudflare-r2-vs-aws-s3/)
- [Your AIVEN_MYSQL_SETUP.md](./AIVEN_MYSQL_SETUP.md) for database configuration

## Appendix: Why This Installation Process

### The Architecture Behind Ghost's Storage Adapters

If you're wondering why the storage adapter installation process seems complex compared to typical npm packages, it's due to Ghost's **plugin architecture design**. The architectural goal is to make Ghost's plugin system **"warm-pluggable"** - enabling easy plugin installation and switching without rebuilding the application, while maintaining clean separation between core and plugins.

Here's the technical reasoning:

### Ghost's Plugin System

**Directory-Based Discovery:**
- Ghost scans `content/adapters/storage/` at startup to discover available storage adapters
- Each adapter must be a self-contained directory with its own dependencies
- Ghost doesn't use npm's standard module resolution for storage adapters

**Configuration-Based Loading:**
- Storage adapters are loaded dynamically based on the `storage__active` configuration
- Ghost caches adapter references during startup
- **Configuration changes require restart** to take effect (confirmed by [official Ghost documentation](https://ghost.org/docs/config/))

### Why Not Just `yarn add`?

**Workspace Conflicts:**
- Ghost uses yarn workspaces (monorepo structure)
- Installing storage adapters in Ghost's main `package.json` would pollute the core dependencies
- Storage adapters should remain isolated from Ghost's core dependencies

**Runtime Loading Requirements:**
- Ghost expects adapters at specific paths: `content/adapters/storage/[adapter-name]/`
- Each adapter needs its own `node_modules` for dependency isolation
- Ghost loads adapters as independent modules, not as part of the main dependency tree

### Benefits of This Architecture

**"Warm-Pluggable" Design:**
- **No rebuild required** - Ghost binary stays the same
- **Simple deployment** - Copy files + restart (vs full recompilation)
- **Easy rollback** - Delete directory + restart
- **Dependency isolation** - Adapter bugs don't affect Ghost core
- **Flexibility** - Switch storage backends via configuration only

**Operational Simplicity:**
- Production servers don't need build environments
- Plugin management becomes a simple file operation
- No source code modifications required
- Multiple storage adapters can coexist

### The Installation Pattern Explained

1. **Work in `/tmp`** - Avoids yarn workspace conflicts entirely
2. **Install with dependencies** - `yarn add` downloads adapter + all dependencies
3. **Copy everything** - Includes pre-installed dependency tree
4. **Restart Ghost** - Required for adapter discovery and configuration loading

This approach transforms plugin installation from a **development task** (requiring build tools) into a **simple operations task** (copy files + restart).

### Evidence Sources

- [Ghost Official Configuration Documentation](https://ghost.org/docs/config/) - "changes to the file can be implemented using ghost restart"
- [Ghost Storage Adapter Paths](https://github.com/danmasta/ghost-gcs-adapter) - Documents expected directory structure
- [Community Evidence](https://forum.cloudron.io/topic/10650/adding-a-storage-adapter-in-ghost) - Real-world usage patterns

This architecture enables Ghost to maintain a **clean core** while supporting **extensive customization** through isolated, self-contained adapters.