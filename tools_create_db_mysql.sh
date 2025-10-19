#!/bin/bash

# ==============================================================================
# Script: tools_create_db_mysql.sh
# Description: Tools sederhana untuk membuat user dan database pada mysql
# Author: Salman Mustapa
# ==============================================================================

# --- Configuration ---

# Check if running as root, which might simplify things
if [[ $EUID -ne 0 ]]; then
    SUDO_CMD="sudo"
else
    SUDO_CMD=""
fi

# --- Helper Functions ---

# Function to display colored output
print_color() {
    case "$1" in
        "green") echo -e "\e[32m$2\e[0m" ;; 
        "red") echo -e "\e[31m$2\e[0m" ;; 
        "yellow") echo -e "\e[33m$2\e[0m" ;; 
        "blue") echo -e "\e[34m$2\e[0m" ;; 
        *) echo "$2" ;; 
    esac
}

# Function to check if a database exists
# $1: Database name
db_exists() {
    local db_name=$1
    # The -s (silent) and -N (no headers) flags are used for clean output.
    # The query returns the db name if it exists, otherwise nothing.
    local check=$($SUDO_CMD mysql -u root -sN -e "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = '$db_name'")
    if [ "$check" == "$db_name" ]; then
        return 0 # True, exists
    else
        return 1 # False, does not exist
    fi
}

# Function to check if a user exists
# $1: Username
user_exists() {
    local user_name=$1
    local check=$($SUDO_CMD mysql -u root -sN -e "SELECT User FROM mysql.user WHERE User = '$user_name' AND Host = 'localhost'")
    if [ "$check" == "$user_name" ]; then
        return 0 # True, exists
    else
        return 1 # False, does not exist
    fi
}

# Function to show non-system users
# $1: Optional argument. If "id", it will show with numbered IDs.
show_users() {
    print_color "yellow" "\n--- Current Users ---"
    USER_QUERY="SELECT user FROM mysql.user WHERE host = 'localhost' AND user NOT IN ('root', 'mysql.sys', 'mysql.session', 'debian-sys-maint');"
    USER_LIST=$($SUDO_CMD mysql -u root -N -e "$USER_QUERY")

    if [ -z "$USER_LIST" ]; then
        print_color "red" "No non-system users found."
        return 1
    fi

    if [ "$1" == "id" ]; then
        echo "$USER_LIST" | cat -n
    else
        echo "$USER_LIST"
    fi
    echo "---------------------"
    return 0
}

# --- Main Script ---

print_color "blue" "MySQL Database and User Management Tool"
print_color "blue" "======================================="
echo

# Main loop
while true; do
    print_color "yellow" "\nPlease choose an option:"
    echo "1. Create a new Database and a new User"
    echo "2. Create a new User for an EXISTING Database"
    echo "3. Delete a Database (and its associated User)"
    echo "4. Delete a User ONLY (by ID)"
    echo "5. Exit"
    read -p "Enter your choice (1-5): " choice
    echo

    case $choice in
        1)
            # --- Option 1: Create New Database and User ---
            print_color "blue" "--- Create New Database and User ---"
            read -p "Enter the name for the new database: " DB_NAME
            if [ -z "$DB_NAME" ]; then print_color "red" "Error: Database name cannot be empty."; continue; fi
            if db_exists "$DB_NAME"; then print_color "red" "Error: Database '$DB_NAME' already exists."; continue; fi

            read -p "Enter the username for the new database user: " DB_USER
            if [ -z "$DB_USER" ]; then print_color "red" "Error: Username cannot be empty."; continue; fi
            if user_exists "$DB_USER"; then print_color "red" "Error: User '$DB_USER' already exists."; continue; fi

            read -sp "Enter the password for '$DB_USER': " DB_PASS; echo
            if [ -z "$DB_PASS" ]; then print_color "red" "Error: Password cannot be empty."; continue; fi
            
            echo
            SQL_QUERIES="CREATE DATABASE \"
$DB_NAME
\"; CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS'; GRANT ALL PRIVILEGES ON 
$DB_NAME
.* TO '$DB_USER'@'localhost'; FLUSH PRIVILEGES;"
            $SUDO_CMD mysql -u root -e "$SQL_QUERIES"
            ;; 
        2)
            # --- Option 2: Create User for Existing Database ---
            print_color "blue" "--- Create User for an Existing Database ---"
            read -p "Show list of existing users first? (y/N): " show
            if [[ "$show" == "y" || "$show" == "Y" ]]; then show_users; fi

            DB_LIST=$($SUDO_CMD mysql -u root -e "SHOW DATABASES;" | grep -vE '^(Database|information_schema|mysql|performance_schema|sys)$')
            echo "Available databases:"; print_color "green" "$DB_LIST"; print_color "yellow" "You can also type '*' to grant access to ALL databases."; echo
            read -p "Enter the name of the database to grant access to: " SELECTED_DB
            if [ -z "$SELECTED_DB" ]; then print_color "red" "Error: Database selection cannot be empty."; continue; fi
            
            DB_TO_GRANT=""
            if [ "$SELECTED_DB" == "*" ]; then 
                DB_TO_GRANT="*.*"
            else 
                if ! db_exists "$SELECTED_DB"; then print_color "red" "Error: Database '$SELECTED_DB' does not exist."; continue; fi
                DB_TO_GRANT="\
$SELECTED_DB
.*"
            fi

            read -p "Enter the new username: " DB_USER
            if [ -z "$DB_USER" ]; then print_color "red" "Error: Username cannot be empty."; continue; fi
            if user_exists "$DB_USER"; then print_color "red" "Error: User '$DB_USER' already exists."; continue; fi

            read -sp "Enter the password for '$DB_USER': " DB_PASS; echo
            if [ -z "$DB_PASS" ]; then print_color "red" "Error: Password cannot be empty."; continue; fi

            echo
            SQL_QUERIES="CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS'; GRANT ALL PRIVILEGES ON $DB_TO_GRANT TO '$DB_USER'@'localhost'; FLUSH PRIVILEGES;"
            $SUDO_CMD mysql -u root -e "$SQL_QUERIES"
            ;; 
        3)
            # --- Option 3: Delete Database and User ---
            print_color "blue" "--- Delete a Database and its User ---"
            DB_LIST=$($SUDO_CMD mysql -u root -e "SHOW DATABASES;" | grep -vE '^(Database|information_schema|mysql|performance_schema|sys)$')
            echo "Available databases:"; print_color "green" "$DB_LIST"; echo
            read -p "Enter the name of the database to DELETE: " DB_NAME
            if [ -z "$DB_NAME" ]; then print_color "red" "Error: Database name cannot be empty."; continue; fi
            if ! db_exists "$DB_NAME"; then print_color "red" "Error: Database '$DB_NAME' does not exist."; continue; fi

            print_color "yellow" "\nFinding users with access to '$DB_NAME' நான"
            RELATED_USERS=$($SUDO_CMD mysql -u root -N -e "SELECT user FROM mysql.db WHERE db = '$DB_NAME' AND host = 'localhost';")
            if [ -n "$RELATED_USERS" ]; then print_color "green" "Users with specific access to this database:"; echo "$RELATED_USERS"; else print_color "yellow" "No users found with *specific* access to this database."; fi
            echo "----------------------------------------"

            read -p "Enter the name of the associated user to DELETE (optional, press Enter to skip): " USER_NAME
            
            CONFIRM_MSG="Are you sure you want to permanently delete the database '$DB_NAME'"
            SQL_QUERIES="DROP DATABASE 
$DB_NAME
;"

            if [ -n "$USER_NAME" ]; then
                if ! user_exists "$USER_NAME"; then print_color "red" "Warning: User '$USER_NAME' does not exist. Only the database will be deleted."; USER_NAME=""; else
                    SQL_QUERIES+=" DROP USER '$USER_NAME'@'localhost';"
                    CONFIRM_MSG+=" AND the user '$USER_NAME'"
                fi
            fi

            read -p "$CONFIRM_MSG? (y/N): " confirm
            if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then echo "Aborted."; continue; fi
            
            $SUDO_CMD mysql -u root -e "$SQL_QUERIES"
            ;; 
        4)
            # --- Option 4: Delete User Only by ID ---
            print_color "blue" "--- Delete a User Only by ID ---"
            show_users "id"
            if [ $? -ne 0 ]; then continue; fi

            USER_LIST=$($SUDO_CMD mysql -u root -N -e "SELECT user FROM mysql.user WHERE host = 'localhost' AND user NOT IN ('root', 'mysql.sys', 'mysql.session', 'debian-sys-maint');")
            USER_COUNT=$(echo "$USER_LIST" | wc -l)

            read -p "Enter the ID of the user to DELETE: " USER_ID
            if ! [[ "$USER_ID" =~ ^[0-9]+$ ]] || [ "$USER_ID" -lt 1 ] || [ "$USER_ID" -gt "$USER_COUNT" ]; then print_color "red" "Invalid ID."; continue; fi

            USER_TO_DELETE=$(echo "$USER_LIST" | sed -n "${USER_ID}p")
            
            read -p "Are you sure you want to permanently delete the user '$USER_TO_DELETE'? (y/N): " confirm
            if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then echo "Aborted."; continue; fi
            
            SQL_QUERIES="DROP USER '$USER_TO_DELETE'@'localhost';"
            $SUDO_CMD mysql -u root -e "$SQL_QUERIES"
            ;; 
        5)
            # --- Option 5: Exit ---
            print_color "green" "Exiting program."
            break
            ;; 
        *)
            print_color "red" "Invalid choice. Please enter a number between 1 and 5."
            ;; 
    esac

    # --- Execution Feedback ---
    if [ $? -eq 0 ]; then
        print_color "green" "\nOperation completed successfully!"
    else
        # MySQL errors are now shown directly, which is often more informative.
        print_color "red" "\nAn error occurred during the SQL execution."
    fi
done

exit 0
