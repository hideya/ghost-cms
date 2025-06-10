#!/bin/bash

# Ghost PostgreSQL Patcher Script
# This script automatically applies patches to make Ghost CMS work with PostgreSQL
# Version: Ghost v5.120.2
# Author: Auto-generated from troubleshooting session

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if a file exists
check_file() {
    if [[ ! -f "$1" ]]; then
        print_error "File not found: $1"
        exit 1
    fi
}

# Function to create backup
create_backup() {
    local file="$1"
    local backup="${file}.backup-$(date +%Y%m%d-%H%M%S)"
    cp "$file" "$backup"
    print_success "Created backup: $backup"
}

# Function to apply patch using sed
apply_patch() {
    local file="$1"
    local description="$2"
    local search="$3"
    local replace="$4"
    
    print_status "Applying patch: $description"
    
    # Check if file exists
    check_file "$file"
    
    # Create backup
    create_backup "$file"
    
    # Apply patch
    if command -v perl > /dev/null 2>&1; then
        # Use perl for multi-line replacements (more reliable)
        perl -i -0pe "s/\Q$search\E/$replace/gs" "$file"
    else
        # Fallback to sed (may not work for all patches)
        print_warning "Perl not found, using sed (less reliable for multi-line patches)"
        sed -i.bak "s|$search|$replace|g" "$file"
    fi
    
    print_success "Applied patch: $description"
}

# Main function
main() {
    print_status "Starting Ghost PostgreSQL Patcher"
    print_status "This script will patch Ghost v5.120.2 to work with PostgreSQL"
    echo ""
    
    # Check if we're in a Ghost directory
    if [[ ! -f "package.json" ]] || ! grep -q "ghost" package.json; then
        print_error "This doesn't appear to be a Ghost directory"
        print_error "Please run this script from the Ghost root directory"
        exit 1
    fi
    
    # Check if node_modules exists
    if [[ ! -d "node_modules" ]]; then
        print_error "node_modules directory not found"
        print_error "Please run 'yarn install' first"
        exit 1
    fi
    
    # Check Ghost version
    GHOST_VERSION=$(node -p "require('./package.json').version" 2>/dev/null || echo "unknown")
    print_status "Detected Ghost version: $GHOST_VERSION"
    
    if [[ "$GHOST_VERSION" != "5.120.2" ]]; then
        print_warning "This patcher is designed for Ghost v5.120.2"
        print_warning "Your version is $GHOST_VERSION - patches may not work correctly"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "Aborted by user"
            exit 0
        fi
    fi
    
    # Install pg driver if not present
    if ! npm list pg > /dev/null 2>&1; then
        print_status "Installing PostgreSQL driver (pg)..."
        yarn add pg -W
        print_success "PostgreSQL driver installed"
    else
        print_success "PostgreSQL driver already installed"
    fi
    
    echo ""
    print_status "Applying patches..."
    echo ""
    
    # Patch 1: knex-migrator database support
    FILE1="node_modules/knex-migrator/lib/database.js"
    SEARCH1="    } else if (!DatabaseInfo.isMySQLConfig(dbConfig)) {
        return Promise.reject(new errors.KnexMigrateError({
            message: 'Database is not supported.'
        }));
    }"
    REPLACE1="    }
    
    // @NOTE: For PostgreSQL, we assume the database already exists (common for hosted services)
    if (dbConfig.client === 'pg' || dbConfig.client === 'postgres' || dbConfig.client === 'postgresql') {
        return Promise.resolve();
    }
    
    if (!DatabaseInfo.isMySQLConfig(dbConfig)) {
        return Promise.reject(new errors.KnexMigrateError({
            message: 'Database is not supported.'
        }));
    }"
    
    apply_patch "$FILE1" "knex-migrator database support" "$SEARCH1" "$REPLACE1"
    
    # Patch 2: knex-migrator primary key constraint
    FILE2="node_modules/knex-migrator/migrations/add-primary-key-to-lock-table.js"
    SEARCH2="        if (err.code === 'ER_MULTIPLE_PRI_KEY') {"
    REPLACE2="        if (err.code === 'ER_MULTIPLE_PRI_KEY' || err.code === '42P16') {"
    
    apply_patch "$FILE2" "knex-migrator primary key constraint" "$SEARCH2" "$REPLACE2"
    
    # Patch 3: Ghost schema commands - getTables
    FILE3="ghost/core/core/server/data/schema/commands.js"
    SEARCH3="    } else if (client === 'mysql2') {
        const response = await transaction.raw('show tables');
        return _.flatten(_.map(response[0], entry => _.values(entry)));
    }

    return Promise.reject(tpl(messages.noSupportForDatabase, {client: client}));"
    REPLACE3="    } else if (client === 'mysql2') {
        const response = await transaction.raw('show tables');
        return _.flatten(_.map(response[0], entry => _.values(entry)));
    } else if (client === 'pg' || client === 'postgres' || client === 'postgresql') {
        const response = await transaction.raw(\"SELECT tablename FROM pg_tables WHERE schemaname = 'public'\");
        return _.map(response.rows, 'tablename');
    }

    return Promise.reject(tpl(messages.noSupportForDatabase, {client: client}));"
    
    apply_patch "$FILE3" "Ghost schema getTables function" "$SEARCH3" "$REPLACE3"
    
    # Patch 4: Ghost schema commands - getIndexes
    SEARCH4="    } else if (client === 'mysql2') {
        const response = await transaction.raw(\`SHOW INDEXES from \${table}\`);
        return _.flatten(_.map(response[0], 'Key_name'));
    }

    return Promise.reject(tpl(messages.noSupportForDatabase, {client: client}));"
    REPLACE4="    } else if (client === 'mysql2') {
        const response = await transaction.raw(\`SHOW INDEXES from \${table}\`);
        return _.flatten(_.map(response[0], 'Key_name'));
    } else if (client === 'pg' || client === 'postgres' || client === 'postgresql') {
        const response = await transaction.raw(\`SELECT indexname FROM pg_indexes WHERE tablename = '\${table}' AND schemaname = 'public'\`);
        return _.map(response.rows, 'indexname');
    }

    return Promise.reject(tpl(messages.noSupportForDatabase, {client: client}));"
    
    apply_patch "$FILE3" "Ghost schema getIndexes function" "$SEARCH4" "$REPLACE4"
    
    # Patch 5: Ghost schema commands - getColumns
    SEARCH5="    } else if (client === 'mysql2') {
        const response = await transaction.raw(\`SHOW COLUMNS from \${table}\`);
        return _.flatten(_.map(response[0], 'Field'));
    }

    return Promise.reject(tpl(messages.noSupportForDatabase, {client: client}));"
    REPLACE5="    } else if (client === 'mysql2') {
        const response = await transaction.raw(\`SHOW COLUMNS from \${table}\`);
        return _.flatten(_.map(response[0], 'Field'));
    } else if (client === 'pg' || client === 'postgres' || client === 'postgresql') {
        const response = await transaction.raw(\`SELECT column_name FROM information_schema.columns WHERE table_name = '\${table}' AND table_schema = 'public'\`);
        return _.map(response.rows, 'column_name');
    }

    return Promise.reject(tpl(messages.noSupportForDatabase, {client: client}));"
    
    apply_patch "$FILE3" "Ghost schema getColumns function" "$SEARCH5" "$REPLACE5"
    
    echo ""
    print_success "All patches applied successfully!"
    echo ""
    
    # Check if config exists
    CONFIG_FILE="ghost/core/config.local.json"
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_warning "No PostgreSQL configuration found"
        print_status "Creating example configuration file: $CONFIG_FILE"
        
        cat > "$CONFIG_FILE" << 'EOF'
{
    "database": {
        "client": "pg",
        "connection": {
            "connectionString": "postgresql://username:password@host:port/database?sslmode=require"
        }
    }
}
EOF
        
        print_success "Created example config file: $CONFIG_FILE"
        print_warning "Please edit $CONFIG_FILE with your actual PostgreSQL connection details"
    else
        print_success "Configuration file already exists: $CONFIG_FILE"
    fi
    
    echo ""
    print_status "Next steps:"
    echo "1. Edit $CONFIG_FILE with your PostgreSQL connection details"
    echo "2. Ensure your PostgreSQL database exists and is accessible"
    echo "3. Run: yarn knex-migrator init"
    echo "4. Run: yarn dev"
    echo ""
    print_success "Ghost PostgreSQL patching complete!"
}

# Run the script
main "$@"
