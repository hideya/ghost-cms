# Ghost CMS Setup with Aiven MySQL

This document describes how to set up Ghost CMS (version 5.122.0) to work with a MySQL database hosted on Aiven. This process differs from the standard Ghost installation documented at https://ghost.org/docs/install/source/, particularly because we skip the `yarn setup` step that would normally configure a local MySQL instance running in Docker.

## Prerequisites

- Node.js and Yarn installed
- Aiven MySQL database instance configured and running
- Database connection details from Aiven

## Setup Steps

### 1. Clone and Install Dependencies

```bash
# Clone the Ghost repository
git clone https://github.com/TryGhost/Ghost.git ghost-cms
cd ghost-cms

# Install dependencies
yarn install
```

### 2. Configure Environment Variables

Instead of using a config file, Ghost can be configured using environment variables. Create a `.env` file in the project root:

```bash
# Create .env file from template in project root
cp .env.template .env
```

**Note**: The `.env` file has been added to `.gitignore` and will not be committed to version control.

Edit `.env` with your Aiven MySQL connection details:

```env
# Database Configuration
database__client=mysql2
database__connection__host=your-mysql-instance.aivencloud.com
database__connection__port=25426
database__connection__user=your-username
database__connection__password=your-password
database__connection__database=ghost
database__connection__charset=utf8mb4
database__connection__ssl__rejectUnauthorized=false

# Server Configuration
server__host=0.0.0.0
server__port=2368
url=http://localhost:2368
```

**Environment Variable Explanations**:
- **`database__client`**: Specifies mysql2 driver for Ghost
- **`database__connection__host`**: Your Aiven MySQL instance hostname
- **`database__connection__port`**: Aiven MySQL port (typically 25426)
- **`database__connection__user`** and **`database__connection__password`**: Your Aiven database credentials
- **`database__connection__database`**: Database name (usually 'ghost')
- **`database__connection__charset`**: Ensures full Unicode support including emojis (recommended)
- **`database__connection__ssl__rejectUnauthorized`**: Set to false for Aiven connections
- **`server__host`**: Allows external connections to the development server
- **`server__port`**: Port for Ghost to run on
- **`url`**: The URL where Ghost will be accessible

**Note**: Ghost uses **double underscores** (`__`) to represent nested configuration properties in environment variables. This means `database__connection__host` corresponds to the `database.connection.host` property in a JSON config file.

**Loading Environment Variables**: Before running Ghost, you need to load and export these environment variables:

```bash
# Load and export environment variables (run this in project root)
set -a; source .env; set +a
```

This command:
- `set -a`: Enables automatic export of all variables
- `source .env`: Loads variables from the .env file  
- `set +a`: Disables automatic export

### 3. Reset Nx Cache (Preventive Measure)

```bash
# Reset Nx cache to prevent build conflicts
yarn nx reset
```

This step ensures that any running Nx daemon processes don't interfere with the build process.

### 4. Build Ghost

```bash
# Build the Ghost application (this can take several minutes)
yarn build
```

This step compiles all assets and prepares Ghost for running. On modern machines, this typically takes 2-3 minutes to complete.

### 5. Initialize Database

**Choose the appropriate option based on your database situation:**

#### Option A: New/Fresh Database Setup
If you're setting up a new Ghost installation with a dedicated database:

**Important**: The following commands will completely reset and reinitialize the database specified in `database__connection__database`. All existing data in that database will be permanently deleted.

```bash
# Reset and initialize the database schema and default data (this can take several minutes)
yarn knex-migrator reset
yarn knex-migrator init
```

The initialization process sets up all database tables, indexes, and default content. This typically takes 2-4 minutes to complete.

**Why both commands are needed**:
- `knex-migrator reset`: Drops all existing tables and data from the database
- `knex-migrator init`: Creates fresh Ghost database schema and inserts default data
- `init` requires a completely empty database to work properly

#### Option B: Connecting to Existing Ghost Database
If you're connecting to a MySQL database that already contains Ghost tables (shared instance, reconnecting to existing data, etc.), **skip the reset and init commands entirely**. The database already has the necessary schema and data.

```bash
# Skip database initialization - proceed directly to starting Ghost
# (No knex-migrator commands needed)
```

### 6. Start Development Server

```bash
# Load environment variables and start Ghost in development mode
set -a; source .env; set +a
yarn dev
```

### 7. Access Ghost

After starting the development server, Ghost needs a few moments to complete its initialization (asset regeneration, etc.).

Open your browser and navigate to:
- **Frontend**: http://localhost:2368/
- **Admin Panel**: http://localhost:2368/ghost/

**First-time Setup**: If this is a fresh Ghost installation, you'll need to create an admin user by visiting the admin panel URL. Ghost will guide you through the initial setup process including:
- Creating your admin account
- Setting up your site title and description
- Configuring basic settings

**Note**: The admin panel may take a minute or two to load initially while Ghost completes background initialization tasks.

## Important Notes

### Security Considerations
- Never commit `.env` files with real credentials to version control
- Add `.env` to your `.gitignore` file to prevent accidental commits
- Use different `.env` files for different environments (development, staging, production)
- The `DB_SSL_REJECT_UNAUTHORIZED=false` setting is for development convenience with Aiven

### Database Management
- The `knex-migrator init` command sets up the complete Ghost database schema
- Use `knex-migrator reset` carefully as it will destroy all existing data
- Always backup your database before running reset commands

### Troubleshooting

**Build fails with Nx errors**:
- Run `yarn nx reset` and try building again
- Ensure no other Nx processes are running

**Database connection issues**:
- Verify your Aiven MySQL instance is running
- Check firewall settings and allowed IP addresses in Aiven console
- Confirm database credentials are correct
- Verify environment variables are properly loaded:
  ```bash
  # Check if environment variables are set correctly
  set | grep -E "(database__|server__)"
  ```
- Test the connection manually using the loaded environment variables:
  ```bash
  # Make sure environment variables are loaded first:
  set -a; source .env; set +a
  
  # Test MySQL connection using the same variables Ghost will use
  mysql -h ${database__connection__host} -P ${database__connection__port} -u ${database__connection__user} -p${database__connection__password}
  ```

## Version Information

This setup was tested with:
- Ghost CMS version 5.122.0
- Aiven MySQL service
- Node.js with Yarn package manager

## Quick Reference

For users who want to repeat the setup process, here are the essential commands:

```bash
# 1. Setup environment
cp .env.template .env
# (edit .env with your Aiven MySQL credentials)

# 2. Build and initialize
yarn install
set -a; source .env; set +a
yarn nx reset
yarn build
yarn knex-migrator reset && yarn knex-migrator init

# 3. Start Ghost
yarn dev
# Open http://localhost:2368/ghost/ for admin setup
```

## References

- [Official Ghost Source Installation Guide](https://ghost.org/docs/install/source/)
- [Aiven MySQL Documentation](https://aiven.io/docs/products/mysql)
- [Ghost Configuration Documentation](https://ghost.org/docs/config/)