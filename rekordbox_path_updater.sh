#!/bin/bash

# Rekordbox Path Updater (Bash Version)
# Updates file paths in a Rekordbox backup XML file

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Function to show usage
show_usage() {
    cat << EOF
Rekordbox Path Updater (Bash Version)

Usage: $0 <xml_file> <new_root_path> [--dry-run]

Arguments:
    xml_file        Path to the Rekordbox backup XML file
    new_root_path   New root path for music files
    --dry-run       Show what would be changed without modifying the file

Example:
    $0 "rekordbox backup.xml" "/Volumes/External/Music/"
    $0 "rekordbox backup.xml" "/Volumes/External/Music/" --dry-run

EOF
}

# Function to URL decode a string
url_decode() {
    local url_encoded="${1//+/ }"
    printf '%b' "${url_encoded//%/\\x}"
}

# Function to URL encode a string
url_encode() {
    local string="${1}"
    local strlen=${#string}
    local encoded=""
    local pos c o

    for (( pos=0 ; pos<strlen ; pos++ )); do
        c=${string:$pos:1}
        case "$c" in
            [-_.~a-zA-Z0-9] ) o="${c}" ;;
            * )               printf -v o '%%%02x' "'$c"
        esac
        encoded+="${o}"
    done
    echo "${encoded}"
}

# Function to extract filename from location URL
extract_filename() {
    local location_url="$1"
    
    # Remove file://localhost/ prefix
    if [[ "$location_url" =~ ^file://localhost/(.*)$ ]]; then
        local file_path="${BASH_REMATCH[1]}"
    else
        local file_path="$location_url"
    fi
    
    # URL decode the path
    local decoded_path=$(url_decode "$file_path")
    
    # Get just the filename
    local filename=$(basename "$decoded_path")
    
    echo "$filename"
}

# Function to build new location URL
build_new_location() {
    local new_root_path="$1"
    local filename="$2"
    
    # Ensure the new root path ends with a separator
    if [[ ! "$new_root_path" =~ /$ ]]; then
        new_root_path="${new_root_path}/"
    fi
    
    # Build the full path using proper path joining
    local full_path="${new_root_path%/}/${filename}"
    
    # URL encode the path
    local encoded_path=$(url_encode "$full_path")
    
    # Build the file://localhost/ URL
    local new_location="file://localhost/${encoded_path}"
    
    echo "$new_location"
}

# Function to verify file exists
verify_file_exists() {
    local new_root_path="$1"
    local filename="$2"
    
    # Ensure the new root path ends with a separator
    if [[ ! "$new_root_path" =~ /$ ]]; then
        new_root_path="${new_root_path}/"
    fi
    
    # First check the root directory
    local full_path="${new_root_path%/}/${filename}"
    if [[ -f "$full_path" ]]; then
        echo "true:$full_path"
        return 0
    fi
    
    # If not found in root, search all subdirectories
    while IFS= read -r -d '' found_file; do
        if [[ "$(basename "$found_file")" == "$filename" ]]; then
            echo "true:$found_file"
            return 0
        fi
    done < <(find "$new_root_path" -type f -print0 2>/dev/null)
    
    echo "false:"
    return 1
}

# Function to update the XML file
update_xml() {
    local xml_file="$1"
    local new_root_path="$2"
    local dry_run="$3"
    
    local success_count=0
    local error_count=0
    local errors=()
    
    # Check if xmlstarlet is available
    if ! command -v xmlstarlet &> /dev/null; then
        print_error "xmlstarlet is required but not installed. Please install it first."
        print_warning "On macOS: brew install xmlstarlet"
        print_warning "On Ubuntu/Debian: sudo apt-get install xmlstarlet"
        exit 1
    fi
    
    # Create temporary file for processing
    local temp_file=$(mktemp)
    cp "$xml_file" "$temp_file"
    
    # Find all TRACK elements with Location attributes
    local track_count=0
    while IFS= read -r -d '' track_xml; do
        ((track_count++))
        
        # Extract the Location attribute
        local location=$(echo "$track_xml" | xmlstarlet sel -t -v "@Location" 2>/dev/null || echo "")
        
        if [[ -n "$location" && "$location" =~ ^file://localhost/ ]]; then
            # Extract filename from current location
            local filename=$(extract_filename "$location")
            
            # Build new location
            local new_location=$(build_new_location "$new_root_path" "$filename")
            
            # Verify file exists at new location (searches subdirectories)
            local verify_result=$(verify_file_exists "$new_root_path" "$filename")
            local found=$(echo "$verify_result" | cut -d: -f1)
            local found_path=$(echo "$verify_result" | cut -d: -f2-)
            
            if [[ "$found" == "true" ]]; then
                # Build new location with the actual found path
                local new_location=$(build_new_location "$new_root_path" "$filename")
                if [[ "$dry_run" != "true" ]]; then
                    # Update the Location attribute in the temporary file
                    xmlstarlet ed -u "//TRACK[@Location='$location']/@Location" -v "$new_location" "$temp_file" > "${temp_file}.new" 2>/dev/null
                    mv "${temp_file}.new" "$temp_file"
                fi
                ((success_count++))
                # Show relative path from root directory
                local relative_path=$(realpath --relative-to="$new_root_path" "$found_path" 2>/dev/null || echo "$filename")
                print_status "Updated: $filename (found in: $relative_path)"
            else
                ((error_count++))
                # Build the full path for error message using proper path joining
                local full_path="${new_root_path%/}/${filename}"
                local error_msg="File not found: ${full_path} (searched all subdirectories)"
                errors+=("$error_msg")
                print_error "$error_msg"
            fi
        fi
    done < <(xmlstarlet sel -t -c "//TRACK[@Location]" "$xml_file" 2>/dev/null | tr -d '\n' | sed 's/<\/TRACK>/\0\0/g' | tr '\0' '\n' | grep -v '^$')
    
    # Save the modified XML if not a dry run
    if [[ "$dry_run" != "true" && $success_count -gt 0 ]]; then
        # Create backup of original file
        local backup_path="${xml_file}.backup"
        cp "$xml_file" "$backup_path"
        print_status "Backup created: $backup_path"
        
        # Write the updated XML
        cp "$temp_file" "$xml_file"
        print_status "Updated XML file: $xml_file"
    fi
    
    # Clean up temporary file
    rm -f "$temp_file"
    
    # Return counts
    echo "$success_count $error_count"
}

# Main script
main() {
    # Check arguments
    if [[ $# -lt 2 ]]; then
        show_usage
        exit 1
    fi
    
    local xml_file="$1"
    local new_root_path="$2"
    local dry_run="false"
    
    # Check for dry-run flag
    if [[ "$3" == "--dry-run" ]]; then
        dry_run="true"
    fi
    
    # Check if XML file exists
    if [[ ! -f "$xml_file" ]]; then
        print_error "XML file '$xml_file' not found."
        exit 1
    fi
    
    # Check if new root path exists
    if [[ ! -d "$new_root_path" ]]; then
        print_error "New root path '$new_root_path' is not a valid directory."
        exit 1
    fi
    
    echo "Processing XML file: $xml_file"
    echo "New root path: $new_root_path"
    if [[ "$dry_run" == "true" ]]; then
        echo "DRY RUN MODE - No changes will be made"
    fi
    echo "--------------------------------------------------"
    
    # Update the XML file
    local result=$(update_xml "$xml_file" "$new_root_path" "$dry_run")
    local success_count=$(echo "$result" | cut -d' ' -f1)
    local error_count=$(echo "$result" | cut -d' ' -f2)
    
    # Print summary
    echo "--------------------------------------------------"
    echo "Summary:"
    echo "  Successfully processed: $success_count files"
    echo "  Errors: $error_count files"
    
    if [[ $error_count -gt 0 ]]; then
        echo ""
        echo "Files not found at new location:"
        for error in "${errors[@]}"; do
            echo "  - $error"
        done
    fi
    
    if [[ "$dry_run" == "true" && $success_count -gt 0 ]]; then
        echo ""
        echo "To apply these changes, run without --dry-run flag"
    fi
}

# Run main function with all arguments
main "$@" 