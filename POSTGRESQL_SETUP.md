# Ghost CMS with PostgreSQL Setup Guide

## Overview

This guide documents how to set up Ghost CMS (v5.120.2) with PostgreSQL instead of the officially supported MySQL/SQLite. Ghost officially dropped PostgreSQL support in v1.0, but with some targeted patches, it's possible to make it work.

**⚠️ Important Disclaimer**: This is an unofficial modification. Ghost officially only supports MySQL 8 in production. Use at your own risk and test thoroughly before deploying to production.

## Quick Start (TL;DR)

If you just want to get Ghost working with PostgreSQL quickly:

```bash
# 1. Setup Ghost
git clone https://github.com/TryGhost/Ghost.git ghost-test
cd ghost-test
yarn install && yarn build

# 2. Apply PostgreSQL patches
chmod +x patch-ghost-postgresql.sh
./patch-ghost-postgresql.sh

# 3. Configure your database connection
nano ghost/core/config.local.json  # Edit with your PostgreSQL details

# 4. Initialize and run
yarn knex-migrator init
yarn dev
```

Ghost will be running at `http://localhost:2368` with PostgreSQL! 🎉

---

## Prerequisites

- Node.js (v18.12.1+ or v20.11.1+ or v22.13.1+)
- PostgreSQL database (local or hosted, e.g., Neon, Supabase, etc.)
- Yarn package manager
- Ghost source code (development setup)

## Step 1: Initial Setup

1. **Clone and set up Ghost**:
   ```bash
   git clone https://github.com/TryGhost/Ghost.git ghost-test
   cd ghost-test
   yarn install
   yarn build
   ```

2. **Install PostgreSQL driver**:
   ```bash
   yarn add pg -W
   ```

3. **Create PostgreSQL configuration**:
   Create `ghost/core/config.local.json`:
   ```json
   {
       "database": {
           "client": "pg",
           "connection": {
               "connectionString": "postgresql://username:password@host:port/database?sslmode=require"
           }
       }
   }
   ```

## Step 2: Apply Patches

### Option A: Automated Script (Recommended)

The easiest way to apply all patches is using the automated script:

1. **Download and run the patcher script**:
   ```bash
   # Make the script executable
   chmod +x patch-ghost-postgresql.sh
   
   # Run the patcher (from Ghost root directory)
   ./patch-ghost-postgresql.sh
   ```

2. **Edit the generated config file**:
   ```bash
   # Edit with your actual PostgreSQL connection details
   nano ghost/core/config.local.json
   ```

3. **Initialize the database**:
   ```bash
   yarn knex-migrator init
   ```

That's it! The script automatically:
- ✅ Installs the PostgreSQL driver
- ✅ Creates backups of all files before patching
- ✅ Applies all 5 required patches
- ✅ Creates an example configuration file
- ✅ Provides clear next steps

### Option B: Manual Patches

If you prefer to apply patches manually, the following patches are needed to make Ghost work with PostgreSQL:

### Patch 1: knex-migrator Database Support

**File**: `node_modules/knex-migrator/lib/database.js`

**Location**: Around line 112, in the `createDatabaseIfNotExist` function

**Original**:
```javascript
} else if (!DatabaseInfo.isMySQLConfig(dbConfig)) {
    return Promise.reject(new errors.KnexMigrateError({
        message: 'Database is not supported.'
    }));
}
```

**Replace with**:
```javascript
}

// @NOTE: For PostgreSQL, we assume the database already exists (common for hosted services)
if (dbConfig.client === 'pg' || dbConfig.client === 'postgres' || dbConfig.client === 'postgresql') {
    return Promise.resolve();
}

if (!DatabaseInfo.isMySQLConfig(dbConfig)) {
    return Promise.reject(new errors.KnexMigrateError({
        message: 'Database is not supported.'
    }));
}
```

### Patch 2: knex-migrator Primary Key Constraint

**File**: `node_modules/knex-migrator/migrations/add-primary-key-to-lock-table.js`

**Location**: Around line 39, in the catch block

**Original**:
```javascript
}).catch((err) => {
    if (err.code === 'ER_MULTIPLE_PRI_KEY') {
        debug(`Primary key constraint for: ${columns} already exists for table: ${tableName}`);
        return;
    }
    throw err;
});
```

**Replace with**:
```javascript
}).catch((err) => {
    if (err.code === 'ER_MULTIPLE_PRI_KEY' || err.code === '42P16') {
        debug(`Primary key constraint for: ${columns} already exists for table: ${tableName}`);
        return;
    }
    throw err;
});
```

### Patch 3: Ghost Schema Commands - getTables

**File**: `ghost/core/core/server/data/schema/commands.js`

**Location**: Around line 508, in the `getTables` function

**Original**:
```javascript
async function getTables(transaction = db.knex) {
    const client = transaction.client.config.client;

    if (client === 'sqlite3') {
        const response = await transaction.raw('select * from sqlite_master where type = "table"');
        return _.reject(_.map(response, 'tbl_name'), name => name === 'sqlite_sequence');
    } else if (client === 'mysql2') {
        const response = await transaction.raw('show tables');
        return _.flatten(_.map(response[0], entry => _.values(entry)));
    }

    return Promise.reject(tpl(messages.noSupportForDatabase, {client: client}));
}
```

**Replace with**:
```javascript
async function getTables(transaction = db.knex) {
    const client = transaction.client.config.client;

    if (client === 'sqlite3') {
        const response = await transaction.raw('select * from sqlite_master where type = "table"');
        return _.reject(_.map(response, 'tbl_name'), name => name === 'sqlite_sequence');
    } else if (client === 'mysql2') {
        const response = await transaction.raw('show tables');
        return _.flatten(_.map(response[0], entry => _.values(entry)));
    } else if (client === 'pg' || client === 'postgres' || client === 'postgresql') {
        const response = await transaction.raw("SELECT tablename FROM pg_tables WHERE schemaname = 'public'");
        return _.map(response.rows, 'tablename');
    }

    return Promise.reject(tpl(messages.noSupportForDatabase, {client: client}));
}
```

### Patch 4: Ghost Schema Commands - getIndexes

**File**: `ghost/core/core/server/data/schema/commands.js`

**Location**: Around line 529, in the `getIndexes` function

**Original**:
```javascript
async function getIndexes(table, transaction = db.knex) {
    const client = transaction.client.config.client;

    if (client === 'sqlite3') {
        const response = await transaction.raw(`pragma index_list("${table}")`);
        return _.flatten(_.map(response, 'name'));
    } else if (client === 'mysql2') {
        const response = await transaction.raw(`SHOW INDEXES from ${table}`);
        return _.flatten(_.map(response[0], 'Key_name'));
    }

    return Promise.reject(tpl(messages.noSupportForDatabase, {client: client}));
}
```

**Replace with**:
```javascript
async function getIndexes(table, transaction = db.knex) {
    const client = transaction.client.config.client;

    if (client === 'sqlite3') {
        const response = await transaction.raw(`pragma index_list("${table}")`);
        return _.flatten(_.map(response, 'name'));
    } else if (client === 'mysql2') {
        const response = await transaction.raw(`SHOW INDEXES from ${table}`);
        return _.flatten(_.map(response[0], 'Key_name'));
    } else if (client === 'pg' || client === 'postgres' || client === 'postgresql') {
        const response = await transaction.raw(`SELECT indexname FROM pg_indexes WHERE tablename = '${table}' AND schemaname = 'public'`);
        return _.map(response.rows, 'indexname');
    }

    return Promise.reject(tpl(messages.noSupportForDatabase, {client: client}));
}
```

### Patch 5: Ghost Schema Commands - getColumns

**File**: `ghost/core/core/server/data/schema/commands.js`

**Location**: Around line 550, in the `getColumns` function

**Original**:
```javascript
async function getColumns(table, transaction = db.knex) {
    const client = transaction.client.config.client;

    if (client === 'sqlite3') {
        const response = await transaction.raw(`pragma table_info("${table}")`);
        return _.flatten(_.map(response, 'name'));
    } else if (client === 'mysql2') {
        const response = await transaction.raw(`SHOW COLUMNS from ${table}`);
        return _.flatten(_.map(response[0], 'Field'));
    }

    return Promise.reject(tpl(messages.noSupportForDatabase, {client: client}));
}
```

**Replace with**:
```javascript
async function getColumns(table, transaction = db.knex) {
    const client = transaction.client.config.client;

    if (client === 'sqlite3') {
        const response = await transaction.raw(`pragma table_info("${table}")`);
        return _.flatten(_.map(response, 'name'));
    } else if (client === 'mysql2') {
        const response = await transaction.raw(`SHOW COLUMNS from ${table}`);
        return _.flatten(_.map(response[0], 'Field'));
    } else if (client === 'pg' || client === 'postgres' || client === 'postgresql') {
        const response = await transaction.raw(`SELECT column_name FROM information_schema.columns WHERE table_name = '${table}' AND table_schema = 'public'`);
        return _.map(response.rows, 'column_name');
    }

    return Promise.reject(tpl(messages.noSupportForDatabase, {client: client}));
}
```

## Step 3: Database Initialization

1. **Ensure your PostgreSQL database exists and is accessible**:
   ```bash
   # Test connection
   psql "your-connection-string" -c "SELECT version();"
   ```

2. **Run the database initialization**:
   ```bash
   yarn knex-migrator init
   ```

   This should complete successfully and create all Ghost tables in your PostgreSQL database.

## Step 4: Running Ghost

After successful initialization, you can start Ghost:

```bash
yarn dev
```

Ghost should now be accessible at `http://localhost:2368` with PostgreSQL as the backend database.

## Verification

Check that tables were created successfully:

```sql
-- Connect to your PostgreSQL database
SELECT tablename FROM pg_tables WHERE schemaname = 'public';
```

You should see all Ghost tables including `posts`, `users`, `settings`, `members`, etc.

## What These Patches Do

1. **knex-migrator database support**: Allows knex-migrator to recognize PostgreSQL as a supported database client
2. **knex-migrator primary key**: Handles PostgreSQL-specific error codes when attempting to create duplicate primary keys
3. **Ghost schema commands**: Adds PostgreSQL support to Ghost's internal database introspection functions using PostgreSQL system tables and information schema

## Limitations & Considerations

- **Unofficial support**: This is not officially supported by Ghost
- **Version specific**: These patches are for Ghost v5.120.2 and may need adjustment for other versions
- **Testing required**: Thoroughly test all Ghost features with PostgreSQL
- **Migrations**: Future Ghost updates may require reapplying these patches
- **Performance**: Some Ghost optimizations are MySQL-specific and may not apply to PostgreSQL

## Troubleshooting

### Common Issues

1. **Connection errors**: Verify your PostgreSQL connection string format
2. **Permission errors**: Ensure your PostgreSQL user has CREATE, DROP, and ALTER permissions
3. **SSL errors**: For hosted databases, ensure SSL mode is correctly configured
4. **Patch conflicts**: If Ghost updates, you may need to reapply patches

### Getting Help

- Check PostgreSQL logs for detailed error messages
- Verify all patches were applied correctly
- Test each patch individually if issues persist

## Alternative Approaches

- **Use Ghost's official MySQL support**: The most stable and supported option
- **Database proxy**: Tools like PgBouncer could potentially help with connection management
- **Fork Ghost**: For production use, consider maintaining a fork with these changes

---

**Remember**: This guide enables PostgreSQL support through unofficial patches. Always test thoroughly and consider the maintenance overhead before using in production environments.
