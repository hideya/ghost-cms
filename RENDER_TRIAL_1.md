# Ghost CMS Deployment Guide

## Architecture Overview

This Ghost CMS setup uses a modern, serverless architecture that's completely free to start and scales smoothly:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│     Render      │    │      Neon       │    │  Cloudflare R2  │
│  (Ghost App)    │───▶│  (PostgreSQL)   │    │  (File Storage) │
│                 │    │                 │    │                 │
│ • Node.js host  │    │ • Database      │    │ • Images/files  │
│ • Free tier     │    │ • Free tier     │    │ • S3-compatible │
│ • Auto-deploy   │    │ • Branching     │    │ • Free tier     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Benefits

### 🆓 **Zero Cost to Start**
- All services offer generous free tiers
- No credit card required for initial setup
- Scale up only when needed

### 🔄 **Shared Environment**
- Local development uses same database and storage as production
- True dev/prod parity
- No data sync issues

### 🚀 **Modern Stack**
- Serverless PostgreSQL with database branching
- Global CDN for file delivery
- Auto-scaling and auto-deployment

### 🛠 **Developer-Friendly**
- Database branching for safe testing
- Hot reloading in development
- Easy deployment pipeline

## Quick Start

### 1. Install Dependencies

```bash
# Install S3 storage adapter
cd ghost/core
yarn add ghost-storage-adapter-s3

# Create adapter structure
mkdir -p content/adapters/storage/s3
echo "module.exports = require('ghost-storage-adapter-s3');" > content/adapters/storage/s3/index.js
```

### 2. Set Up Services

#### Neon PostgreSQL
1. Visit [Neon Console](https://console.neon.tech)
2. Create "New project"
3. **Important**: Choose **Region: AWS US West 2 (Oregon)** region (matches Render's free tier location)
4. Copy connection string via "Connect to your database": `postgresql://user:pass@ep-xyz.us-west-2.aws.neon.tech/neondb`

#### Cloudflare R2
1. Go to [Cloudflare Dashboard](https://dash.cloudflare.com) → R2
2. Create bucket (e.g., `your-ghost-uploads`)
3. **Important**: Choose **WNAM** (Western North America) region via "Provide a location hint (optional)" for optimal performance
4. Generate R2 API tokens (R2 Object Storage → API → Account API Tokens with Permission: "Admin Read & Write")
5. Note your Account ID for endpoint URL
6. Note your (R2 Object Storage → <buket-name> → Settings → Public Development URL)

#### Render
1. Go to [Render Dashboard](https://dashboard.render.com)
2. New Web Service → Connect GitHub repo
3. Configure build and start commands (see below)

### 3. Configure Ghost

#### **Production Configuration (Secure Approach)**

**⚠️ Important**: DO NOT commit production configuration files with secrets to Git!

**Recommended**: Use Render's **Secret Files** feature for secure configuration management.

#### **Ghost's Configuration Hierarchy**

Ghost loads configuration in this **order of precedence** (later sources override earlier ones):

1. **Default config** (lowest priority)
2. **config.production.json** 
3. **Environment variables** (highest priority) ← Overwrites config files!

**⚠️ Critical**: This means environment variables will **always override** config file settings, which can lead to confusion if both are present.

---

##### **Option 1: Render Secret Files (Recommended)**

1. **Create Template** (for documentation only):
Create `ghost/core/config.production.example.json`:
```json
{
    "_comment": "This is a template. Use Render Secret Files for actual config.",
    "url": "https://your-app.onrender.com",
    "database": {
        "client": "pg",
        "connection": {
            "connectionString": "postgresql://user:pass@ep-xyz.us-west-2.aws.neon.tech/neondb"
        }
    },
    "storage": {
        "active": "s3",
        "s3": {
            "endpoint": "https://account-id.r2.cloudflarestorage.com",
            "accessKeyId": "your-r2-access-key",
            "secretAccessKey": "your-r2-secret-key",
            "bucket": "your-bucket-name",
            "region": "auto",
            "forcePathStyle": true,
            "assetHost": "https://pub-HASH.r2.dev"
        }
    },
    "logging": {
        "level": "info",
        "transports": ["stdout"]
    }
}
```

2. **Configure in Render Dashboard**:
   - Go to your Render service → Environment
   - Click **Secret Files**
   - **Filename**: `config.production.json`
   - **Content**: Copy the template above with your real values
   - Save

3. **Update .gitignore**:
```bash
# Add to .gitignore
config.production.json
config.*.json
!config.*.example.json
```

##### **Option 2: Environment Variables (Ghost Native)**
Use Ghost's native environment variable support **without** any config files:

```bash
# Render Environment Variables (Ghost's double-underscore syntax)
NODE_ENV=production
url=https://your-app.onrender.com
database__client=pg
database__connection__connectionString=postgresql://user:pass@neon...
storage__active=s3
storage__s3__endpoint=https://account-id.r2.cloudflarestorage.com
storage__s3__accessKeyId=your-r2-key
storage__s3__secretAccessKey=your-r2-secret
storage__s3__bucket=your-bucket-name
storage__s3__region=auto
storage__s3__forcePathStyle=true
storage__s3__assetHost=https://pub-HASH.r2.dev
```

**⚠️ Important**: When using this approach, do **NOT** create a `config.production.json` file to avoid configuration conflicts.

##### **Option 3: Config File + Environment Variables**
Use a config file with environment variable substitution:

**Config File** (`config.production.json` in Secret Files):
```json
{
    "url": "${GHOST_URL}",
    "database": {
        "client": "pg",
        "connection": {
            "connectionString": "${DATABASE_URL}"
        }
    },
    "storage": {
        "active": "s3",
        "s3": {
            "endpoint": "${R2_ENDPOINT}",
            "accessKeyId": "${R2_ACCESS_KEY_ID}",
            "secretAccessKey": "${R2_SECRET_ACCESS_KEY}",
            "bucket": "${R2_BUCKET_NAME}",
            "region": "auto",
            "forcePathStyle": true,
            "assetHost": "${R2_PUBLIC_URL}"
        }
    },
    "logging": {
        "level": "info",
        "transports": ["stdout"]
    }
}
```

**Environment Variables**:
```bash
NODE_ENV=production
GHOST_URL=https://your-app.onrender.com
DATABASE_URL=postgresql://user:pass@neon...
R2_ENDPOINT=https://account-id.r2.cloudflarestorage.com
R2_ACCESS_KEY_ID=your-r2-key
R2_SECRET_ACCESS_KEY=your-r2-secret
R2_BUCKET_NAME=your-bucket-name
R2_PUBLIC_URL=https://pub-HASH.r2.dev
```

**Why Secret Files is Better**:
- ✅ Cleaner configuration structure
- ✅ Easier to manage complex nested config
- ✅ Version control friendly
- ✅ Better for team collaboration

#### **Configuration Approach Comparison**

| Approach | Config File | Env Variables | Pros | Cons |
|----------|-------------|---------------|------|------|
| **Option 1: Secret Files** | ✅ JSON in Render | ❌ None | Clean structure, secure | Requires Render dashboard |
| **Option 2: Ghost Native** | ❌ None | ✅ Double underscore | Simple, portable | Many env vars to manage |
| **Option 3: Hybrid** | ✅ JSON with ${} | ✅ Standard names | Flexible, clean names | More complex setup |

**⚠️ Critical**: **Never mix approaches!** Choose one and stick with it to avoid configuration conflicts.

#### Local Development Config (`ghost/core/config.local.json`)
```json
{
    "database": {
        "client": "pg",
        "connection": {
            "connectionString": "postgresql://user:pass@ep-xyz.us-east-1.aws.neon.tech/neondb"
        }
    },
    "storage": {
        "active": "s3",
        "s3": {
            "endpoint": "https://[account-id].r2.cloudflarestorage.com",
            "accessKeyId": "[your-r2-key]",
            "secretAccessKey": "[your-r2-secret]",
            "bucket": "[your-bucket-name]",
            "region": "auto",
            "forcePathStyle": true,
            "assetHost": "https://pub-HASH.r2.dev"
        }
    }
}
```

### 4. Render Configuration

#### Build Settings
- **Build Command**: `yarn && yarn build`
- **Start Command**: `cd ghost/core && node index.js`
- **Node Version**: 18+ (specified in package.json)

#### Configuration Management

**🔒 Secure Approach**: Use Render's Secret Files (recommended)
- **Filename**: `config.production.json`
- **Content**: Your complete Ghost configuration with real values
- **Location**: Render Dashboard → Environment → Secret Files

**⚙️ Alternative**: Environment Variables (Ghost's native syntax)
```bash
NODE_ENV=production
url=https://your-app.onrender.com
database__client=pg
database__connection__connectionString=postgresql://user:pass@neon...
storage__active=s3
storage__s3__endpoint=https://account-id.r2.cloudflarestorage.com
storage__s3__accessKeyId=your-r2-key
storage__s3__secretAccessKey=your-r2-secret
storage__s3__bucket=your-bucket-name
storage__s3__region=auto
storage__s3__forcePathStyle=true
storage__s3__assetHost=https://pub-HASH.r2.dev
```

**⚠️ Security Notes**:
- Never commit secrets to Git
- Use Secret Files for complex configuration
- Rotate API keys periodically
- Monitor access logs

## Development Workflow

### Local Development
```bash
# Start development server (uses shared Neon DB + R2)
yarn dev

# Access local instance
open http://localhost:2368
open http://localhost:2368/ghost/  # Admin panel
```

### Production Deployment
```bash
# Deploy to production (auto-deploys on push)
git add .
git commit -m "Update Ghost"
git push origin main
```

### Database Management

#### Using Neon's Database Branching
```bash
# Create a branch for testing (via Neon Console)
# Test migrations safely
# Merge back to main when ready
```

## Free Tier Limits

### Render
- ✅ **750 hours/month** (enough for always-on)
- ✅ **512MB RAM**
- ✅ **Auto-sleep after 15min** (wakes quickly)
- ⚠️ Custom domains require paid plan

### Neon
- ✅ **0.5GB database storage**
- ✅ **3 projects**
- ✅ **Database branching**
- ⚠️ Auto-pause after 1 month inactivity

### Cloudflare R2
- ✅ **10GB storage**
- ✅ **1 million Class A operations/month**
- ✅ **10 million Class B operations/month**
- ✅ **Global CDN included**

## Scaling Up

When you outgrow free tiers:

### Phase 1: Basic Scaling ($10-20/month)
- Render: Starter plan ($7/month)
- Neon: Pro plan ($19/month)
- R2: Pay-as-you-go (very affordable)

### Phase 2: Production Scale ($50-100/month)
- Render: Professional plan
- Neon: Scale plan with more storage
- Custom domain with SSL
- Advanced monitoring

### Phase 3: Enterprise
- Multiple environments
- Advanced backup strategies
- CDN optimization
- Performance monitoring

## Troubleshooting

### Common Issues

#### Connection Errors
```bash
# Check environment variables
echo $DATABASE_URL
echo $R2_ENDPOINT

# Test database connection
psql $DATABASE_URL
```

#### File Upload Issues
```bash
# Verify R2 credentials
# Check bucket permissions
# Confirm endpoint URL format
```

#### Build Failures
```bash
# Clear Render build cache
# Check Node.js version compatibility
# Verify all dependencies are in package.json
```

### Useful Commands

```bash
# Reset local development environment
yarn fix

# Run only Ghost core (no admin)
yarn dev --ghost

# Check Ghost logs
cd ghost/core && tail -f content/logs/ghost.log
```

## Security Notes

### Environment Variables
- Never commit secrets to git
- Use Render's environment variable encryption
- Rotate API keys periodically

### Database Security
- Neon provides automatic SSL encryption
- Use strong passwords
- Enable connection pooling for production

### File Storage Security
- R2 buckets are private by default
- Use signed URLs for sensitive content
- Configure CORS headers appropriately

## Additional Resources

- [Ghost Official Documentation](https://ghost.org/docs/)
- [Neon Documentation](https://neon.tech/docs)
- [Cloudflare R2 Documentation](https://developers.cloudflare.com/r2/)
- [Render Documentation](https://render.com/docs)

## Cost Calculator

Use this to estimate costs as you scale:

| Service | Free Tier | Paid Tier | Breaking Point |
|---------|-----------|-----------|----------------|
| Render | 750hrs, 512MB | $7/month | Always-on + custom domain |
| Neon | 0.5GB, 3 projects | $19/month | >500MB database |
| R2 | 10GB, 1M ops | ~$0.015/GB | >10GB files |

**Total monthly cost**: $0 → $26 → scales based on usage

---

## Quick Reference

### URLs
- **Local Dev**: http://localhost:2368
- **Production**: https://[your-app].onrender.com
- **Admin Panel**: Add `/ghost/` to either URL

### Key Files
- `ghost/core/config.production.example.json` - Production config template
- `ghost/core/config.local.json` - Local development config
- `ghost/core/content/adapters/storage/s3/` - Storage adapter
- **Render Secret Files**: `config.production.json` (actual production config)

### Security Best Practices
- ✅ Use Render Secret Files for production configuration
- ✅ Never commit secrets to Git (use .gitignore)
- ✅ Rotate API keys regularly
- ✅ Use environment-specific configurations
- ✅ Monitor access logs and usage

### Support Commands
```bash
yarn dev              # Full development environment
yarn dev --ghost      # Ghost core only
yarn build            # Build for production
yarn fix              # Reset dependencies
```

---

## Appendix: Development vs Production Architecture

### Understanding Ghost's Build Process

A common question: **"Does `node index.js` include the admin interface?"**

**Answer: Yes!** But it works differently than development mode.

#### Development Mode (`yarn dev`)
```
┌─────────────────┐    ┌─────────────────┐
│   4 Processes   │    │   What You Get  │
├─────────────────┤    ├─────────────────┤
│ Ghost Core      │───▶│ Backend API     │
│ Admin (Ember)   │───▶│ Admin Interface │
│ AdminX Apps     │───▶│ Modern Features │
│ AdminXDeps      │───▶│ Hot Reloading   │
└─────────────────┘    └─────────────────┘
```

- **4 separate processes** running concurrently
- **Hot reloading** for instant development feedback
- **Source files** served directly
- **Memory intensive** but great for development

#### Production Mode (`node index.js`)
```
┌─────────────────┐    ┌─────────────────┐
│   1 Process     │    │   What You Get  │
├─────────────────┤    ├─────────────────┤
│                 │───▶│ Backend API     │
│   Ghost Core    │───▶│ Admin Interface │
│   (with built   │───▶│ Modern Features │
│    assets)      │───▶│ Optimized Perf  │
└─────────────────┘    └─────────────────┘
```

- **1 single process** serves everything
- **Pre-built assets** (compiled during `yarn build`)
- **Optimized bundles** (minified, tree-shaken)
- **Memory efficient** and production-ready

### The Build Magic

When you run `yarn build`:

1. **Compiles Admin Interface**: Ember.js admin → static assets
2. **Bundles AdminX Components**: Modern React components → optimized bundles
3. **Optimizes Everything**: Minification, compression, tree-shaking
4. **Embeds in Ghost**: All assets become part of Ghost's serving capability

### What This Means for Render

```bash
# Build Command (runs once during deployment)
yarn && yarn build

# Start Command (runs continuously)
cd ghost/core && node index.js
```

**Result**: Single Node.js process serves:
- ✅ **Blog** at `https://your-app.onrender.com/`
- ✅ **Admin** at `https://your-app.onrender.com/ghost/`
- ✅ **API** for all admin functionality
- ✅ **All features** you had in development

### Performance Comparison

| Aspect | Development | Production |
|--------|-------------|------------|
| **Processes** | 4 separate | 1 unified |
| **Memory Usage** | ~200-400MB | ~100-200MB |
| **Startup Time** | 30-60 seconds | 5-15 seconds |
| **Asset Loading** | Source files | Optimized bundles |
| **Hot Reloading** | ✅ Yes | ❌ No (not needed) |
| **Admin Features** | ✅ Full | ✅ Full (same features) |

### Troubleshooting Production Admin

If admin doesn't work in production:

```bash
# Check if build completed successfully
yarn build

# Verify admin assets exist
ls ghost/core/core/built/admin/

# Check Ghost logs for errors
node index.js
```

**Key Point**: The admin interface is **fully functional** in production - it's just served as pre-built assets rather than live development servers.

---

## Appendix: Why Ghost Uses Multiple Development Processes

### The Framework Diversity Challenge

A common question: **"Why doesn't Ghost just use one development server like most apps?"**

**Answer**: Ghost's admin interface spans multiple incompatible frameworks that each require their own development tooling.

#### Ghost's Multi-Framework Architecture
```
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│   Ghost Core    │  │ Classic Admin   │  │   AdminX Apps   │
│   (Node.js)     │  │   (Ember.js)    │  │   (React/Vite)  │
│                 │  │                 │  │                 │
│ • Express       │  │ • Ember CLI     │  │ • Vite          │
│ • Handlebars    │  │ • Webpack       │  │ • React         │
│ • Custom build  │  │ • Ember tooling │  │ • Modern ESM    │
└─────────────────┘  └─────────────────┘  └─────────────────┘
     Process 1           Process 2         Processes 3-6
```

### Technical Impossibility of Unification

#### **Conflicting Build Systems**
- **Ember Admin**: Requires Ember CLI + Webpack with AMD modules
- **AdminX**: Uses Vite + modern ESM (incompatible with Ember)
- **Ghost Core**: Server-side Node.js with custom build pipeline

#### **Different Hot Reload Mechanisms**
```javascript
// Ember: Webpack-based HMR
if (module.hot) { 
  module.hot.accept('./component', () => {
    // Reload Ember component
  })
}

// Vite/React: Import.meta.hot
if (import.meta.hot) {
  import.meta.hot.accept((newModule) => {
    // Fast refresh React component
  })
}

// Node.js: Process restart
process.on('SIGHUP', () => {
  // Restart server process
})
```

#### **Port Requirements**
Each framework needs isolated development environments:
- **Ghost Core**: Port 2368 (main application)
- **Ember Admin**: Port 4200 (proxied through Ghost at `/ghost/`)
- **AdminX Settings**: Port 4175
- **AdminX Portal**: Port 4176
- **AdminX Comments**: Port 7173
- **And more...**

### Historical Evolution

Ghost's architecture evolved over time, creating this complexity:

#### **Phase 1: Simple Ghost (2013-2015)**
```
┌─────────────────┐
│   Ghost Core    │
│ • Basic admin   │
│ • Single process│
└─────────────────┘
```

#### **Phase 2: Ember Admin (2016-2020)**
```
┌─────────────────┐  ┌─────────────────┐
│   Ghost Core    │  │ Ember Admin     │
│ • Backend API   │  │ • Rich interface│
│ • Blog frontend │  │ • Separate build│
└─────────────────┘  └─────────────────┘
```

#### **Phase 3: Modern AdminX (2021-Present)**
```
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│   Ghost Core    │  │ Ember Admin     │  │   AdminX Apps   │
│ • Backend API   │  │ • Legacy parts  │  │ • Modern React  │
│ • Blog frontend │  │ • Still needed  │  │ • Incremental   │
└─────────────────┘  └─────────────────┘  └─────────────────┘
```

### Why Ghost Chose This Approach

#### **✅ Advantages**
1. **Best Developer Experience**: Each framework gets optimal tooling
2. **Incremental Migration**: Can gradually move from Ember to React
3. **Framework-Native Features**: Full Ember CLI, full Vite capabilities
4. **Independent Development**: Teams can work on different parts simultaneously
5. **Hot Reload Quality**: Sub-second updates for all frameworks

#### **❌ Disadvantages**
1. **Complex Development Setup**: Multiple processes to manage
2. **Resource Intensive**: Higher memory usage during development
3. **Learning Curve**: Developers need to understand multiple frameworks
4. **Build Complexity**: More moving parts in the build pipeline

### Alternative Approaches (And Why Ghost Didn't Use Them)

#### **Option 1: Single Framework Rewrite**
```
# Rewrite everything in React/Vue
┌─────────────────┐
│   Ghost Core    │
│ • Node.js API   │
│ • React Admin   │ ← Massive rewrite required
└─────────────────┘
```
**Why not**: 
- Years of development effort
- Would break existing themes/customizations
- Ember admin is mature and stable

#### **Option 2: Micro-Frontend Architecture**
```
# Module federation with single dev server
┌─────────────────┐
│ Webpack Module  │
│ Federation      │ ← Complex configuration
│ • All frameworks│ ← Framework compatibility issues
└─────────────────┘
```
**Why not**:
- Ember and Vite are fundamentally incompatible
- Would lose framework-native development experience
- Complex webpack configuration

#### **Option 3: Monolithic Build System**
```
# Single build tool for everything
┌─────────────────┐
│ Custom Builder  │ ← Would need to recreate
│ • Ember support │   Ember CLI + Vite features
│ • React support │
└─────────────────┘
```
**Why not**:
- Reinventing wheels (Ember CLI, Vite)
- Loss of ecosystem tooling
- Maintenance burden

### The Production Unification Strategy

Ghost solves the complexity through **build-time unification**:

```bash
# Development: Multiple processes
yarn dev
├── Ghost Core (Node.js)
├── Ember Admin (ember serve)
├── AdminX Settings (vite dev)
├── AdminX Portal (vite dev)
└── AdminX Dependencies (nx watch)

# Build: Compile everything
yarn build
├── Ember → Static assets
├── AdminX → Optimized bundles
└── Ghost → Embedded asset serving

# Production: Single process
node index.js
└── Serves everything from pre-built assets
```

### Lessons for Other Projects

Ghost's approach teaches us:

1. **Embrace Framework Strengths**: Don't force incompatible tools together
2. **Optimize for Developer Experience**: Complex dev setup is worth it for productivity
3. **Separate Development from Production**: Different optimization goals
4. **Incremental Migration**: You don't have to rewrite everything at once
5. **Build-Time Unification**: Solve complexity at build time, not runtime

**The genius**: Ghost prioritized **developer productivity** during development and **operational efficiency** in production - achieving both through strategic separation.

---

## Appendix: Ghost File System and Persistence Requirements

### Understanding Ghost's File Structure

When deploying Ghost, it's crucial to understand which files need to persist and which are ephemeral.

#### **Complete File Structure**
```
ghost/
└── core/
    ├── content/                    ← PERSISTENCE CRITICAL
    │   ├── data/                   ← Database files (if using SQLite)
    │   │   └── ghost.db           ← Your entire database!
    │   ├── images/                 ← Uploaded media files
    │   │   ├── 2025/
    │   │   └── size/              ← Auto-generated thumbnails
    │   ├── themes/                 ← Custom themes
    │   ├── settings/               ← Configuration files
    │   ├── logs/                   ← Application logs
    │   └── public/                 ← Generated assets
    ├── config.production.json      ← PERSISTENCE RECOMMENDED
    ├── config.local.json          ← PERSISTENCE RECOMMENDED
    └── node_modules/              ← Ephemeral (rebuilt on deploy)
```

### Persistence Requirements by Storage Strategy

#### **Strategy 1: SQLite + Local Files (Simple)**
```
Persistent Volume Requirements:
/app/ghost/core/content/          ← Mount entire content directory
├── data/ghost.db                ← Database
├── images/                      ← User uploads
├── themes/                      ← Custom themes
└── settings/                    ← Site configuration

Result: Everything in one place, easy backup
```

#### **Strategy 2: PostgreSQL + Local Files (Hybrid)**
```
Persistent Volume Requirements:
/app/ghost/core/content/
├── images/                      ← User uploads only
├── themes/                      ← Custom themes
└── settings/                    ← Site configuration

External: PostgreSQL database
Result: Separated database, files still local
```

#### **Strategy 3: PostgreSQL + Cloud Storage (Recommended)**
```
Persistent Volume Requirements:
/app/ghost/core/content/
├── themes/                      ← Custom themes only
└── settings/                    ← Site configuration

External: 
├── PostgreSQL database          ← Neon/Supabase
└── Cloud storage                ← R2/S3 for images

Result: Minimal local persistence
```

### File Categories Explained

#### **🔴 Critical - Must Persist**
```
content/data/ghost.db            ← Your entire database (SQLite only)
content/images/                  ← All uploaded photos/media
content/themes/                  ← Custom theme files
content/settings/                ← Site configuration
config.production.json           ← Production configuration
```
**Losing these = Data loss or broken site**

#### **🟡 Important - Should Persist**
```
content/logs/                    ← Debugging information
config.local.json               ← Development configuration
```
**Losing these = Inconvenience but recoverable**

#### **🟢 Ephemeral - Safe to Recreate**
```
node_modules/                    ← Rebuilt from package.json
content/public/                  ← Generated during build
core/built/                      ← Compiled admin assets
.nx/                            ← Build cache
```
**These are rebuilt on every deployment**

### Platform-Specific Persistence Setup

#### **Render Configuration**
```yaml
# render.yaml (optional)
services:
  - type: web
    name: ghost-blog
    env: node
    buildCommand: yarn && yarn build
    startCommand: cd ghost/core && node index.js
    disk:
      name: ghost-content
      mountPath: /opt/render/project/src/ghost/core/content
      sizeGB: 1
```

**Manual Setup via Dashboard:**
1. Create persistent disk: "ghost-content"
2. Mount path: `/opt/render/project/src/ghost/core/content`
3. Size: 1GB (sufficient for most blogs)

#### **Docker Configuration**
```dockerfile
# For Docker deployments
VOLUME ["/app/ghost/core/content"]

# Or with docker-compose
volumes:
  - ghost-content:/app/ghost/core/content
```

#### **Heroku Configuration**
```bash
# Heroku doesn't support persistent disks
# Must use external storage for everything:
# - Database: Heroku Postgres
# - Files: S3/Cloudinary
# - Themes: Git-based deployment
```

### Backup Strategy by Persistence Level

#### **Level 1: SQLite + Local Files**
```bash
# Backup everything
tar -czf ghost-backup-$(date +%Y%m%d).tar.gz ghost/core/content/

# Restore
tar -xzf ghost-backup-20251210.tar.gz
```
**Pros**: Simple, complete
**Cons**: Large backup size, includes logs

#### **Level 2: External Database + Local Files**
```bash
# Backup database
pg_dump $DATABASE_URL > ghost-db-$(date +%Y%m%d).sql

# Backup files
tar -czf ghost-files-$(date +%Y%m%d).tar.gz ghost/core/content/images/ ghost/core/content/themes/

# Restore
psql $DATABASE_URL < ghost-db-20251210.sql
tar -xzf ghost-files-20251210.tar.gz
```
**Pros**: Smaller file backups, database handled separately
**Cons**: Two-step process

#### **Level 3: External Everything**
```bash
# Database backup (automatic with managed services)
# Files backup (automatic with cloud storage)
# Themes backup (via Git)

# Manual theme backup
tar -czf ghost-themes-$(date +%Y%m%d).tar.gz ghost/core/content/themes/
```
**Pros**: Most backups automated, minimal manual work
**Cons**: Distributed across multiple services

### Common Persistence Mistakes

#### **❌ Mistake 1: Not Persisting Database**
```
# SQLite database gets wiped on every deploy
# Losing all content, users, settings
Result: Complete data loss
```

#### **❌ Mistake 2: Persisting Build Artifacts**
```
# Persisting node_modules or built assets
# Can cause version conflicts
Result: Build failures, broken deployments
```

#### **❌ Mistake 3: Wrong Mount Path**
```
# Mounting to wrong directory
Mount: /app/content  ← Wrong!
Should: /app/ghost/core/content  ← Correct!
Result: Ghost can't find files
```

#### **❌ Mistake 4: Insufficient Disk Size**
```
# 100MB disk for image-heavy blog
Result: Upload failures, broken site
Recommended: Start with 1GB, monitor usage
```

### Monitoring Disk Usage

#### **Check Current Usage**
```bash
# Overall content directory size
du -sh ghost/core/content/

# Break down by subdirectory
du -sh ghost/core/content/*/

# Find largest files
find ghost/core/content/ -type f -size +10M -ls
```

#### **Render Disk Monitoring**
```bash
# In your app console
df -h /opt/render/project/src/ghost/core/content

# Set up alerts when disk is 80% full
```

### Migration Between Persistence Strategies

#### **SQLite → PostgreSQL + Local Files**
```bash
# 1. Export Ghost data
cd ghost/core && node index.js export

# 2. Set up PostgreSQL config
# 3. Import data
cd ghost/core && node index.js import ghost-export.json

# Files remain in same location
```

#### **Local Files → Cloud Storage**
```bash
# 1. Configure cloud storage adapter
# 2. Upload existing files
aws s3 sync ghost/core/content/images/ s3://your-bucket/

# 3. Update Ghost config
# 4. Test uploads work
```

### Quick Reference: What to Persist

| File/Directory | SQLite Setup | PostgreSQL Setup | Cloud Storage Setup |
|----------------|--------------|------------------|-----------------|
| `content/data/` | ✅ Critical | ❌ Not used | ❌ Not used |
| `content/images/` | ✅ Critical | ✅ Critical | ❌ External |
| `content/themes/` | ✅ Important | ✅ Important | ✅ Important |
| `content/settings/` | ✅ Important | ✅ Important | ✅ Important |
| `content/logs/` | 🟡 Optional | 🟡 Optional | 🟡 Optional |
| `config.*.json` | ✅ Important | ✅ Important | ✅ Important |
| `node_modules/` | ❌ Rebuild | ❌ Rebuild | ❌ Rebuild |

**Pro Tip**: Always test your backup/restore process before going live!
