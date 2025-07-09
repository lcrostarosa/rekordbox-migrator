#!/bin/bash

# Rekordbox Path Updater (Bash Version)
# Updates file paths in a Rekordbox backup XML file

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to setup logging
setup_logging() {
    local xml_file="$1"
    local dry_run="$2"
    
    # Create logs directory if it doesn't exist
    mkdir -p logs
    
    # Create log filename with timestamp
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local xml_basename=$(basename "$xml_file" .xml)
    local mode="update"
    if [[ "$dry_run" == "true" ]]; then
        mode="dry-run"
    fi
    local log_filename="logs/${xml_basename}_${mode}_${timestamp}.log"
    
    # Function to log messages
    log_message() {
        local level="$1"
        local message="$2"
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        echo "[$timestamp] [$level] $message" >> "$log_filename"
        echo "$message"
    }
    
    # Export logging function
    export -f log_message
    export log_filename
    
    # Log initial setup
    log_message "INFO" "Starting Rekordbox Path Updater"
    log_message "INFO" "XML File: $xml_file"
    log_message "INFO" "Log File: $log_filename"
    
    echo "$log_filename"
}

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

# Function to get optimal worker count based on system resources
get_optimal_worker_count() {
    local user_workers="$1"
    
    if [[ -n "$user_workers" ]]; then
        echo "$user_workers"
        return 0
    fi
    
    # Get CPU count
    local cpu_count=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 1)
    
    # Get available memory (rough estimate)
    local memory_gb=4  # Default assumption
    if command -v free >/dev/null 2>&1; then
        # Linux
        memory_gb=$(free -g | awk '/^Mem:/{print $2}')
    elif command -v vm_stat >/dev/null 2>&1; then
        # macOS
        local total_mem=$(vm_stat | grep "Total" | awk '{print $3}' | sed 's/\.//')
        memory_gb=$((total_mem / 1024 / 1024))
    fi
    
    # Calculate memory factor (more memory = more threads possible)
    local memory_factor=$(echo "scale=1; $memory_gb / 4" | bc 2>/dev/null || echo "1.0")
    memory_factor=$(echo "$memory_factor" | awk '{if($1>2.0) print 2.0; else print $1}')
    
    # Calculate optimal workers
    # Base: CPU cores
    # Bonus: 50% more for I/O bound tasks
    # Memory factor: Adjust based on available RAM
    local optimal_workers=$(echo "$cpu_count * 1.5 * $memory_factor" | bc 2>/dev/null || echo "$cpu_count")
    optimal_workers=${optimal_workers%.*}  # Remove decimal part
    
    # Apply reasonable bounds
    local min_workers=$((cpu_count > 2 ? cpu_count : 2))
    local max_workers=$((cpu_count * 4 > 32 ? 32 : cpu_count * 4))
    
    local final_workers=$((optimal_workers < min_workers ? min_workers : optimal_workers))
    final_workers=$((final_workers > max_workers ? max_workers : final_workers))
    
    echo "$final_workers"
}

# Function to verify multiple files using parallel processing
verify_files_parallel() {
    local xml_file="$1"
    local new_root_path="$2"
    local max_jobs="$3"
    
    # Calculate optimal worker count
    local optimal_jobs=$(get_optimal_worker_count "$max_jobs")
    echo "Using $optimal_jobs worker threads (CPU cores: $(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 1))" >&2
    
    local temp_dir=$(mktemp -d)
    local results_file="${temp_dir}/results"
    local files_list="${temp_dir}/files"
    
    # Extract all filenames and locations from XML
    xmlstarlet sel -t -m "//TRACK[@Location]" -v "@Location" -n "$xml_file" 2>/dev/null | \
    while IFS= read -r location; do
        if [[ "$location" =~ ^file://localhost/ ]]; then
            local filename=$(extract_filename "$location")
            echo "$filename|$location"
        fi
    done > "$files_list"
    
    # Process files in parallel
    local job_count=0
    while IFS='|' read -r filename location; do
        # Start background job
        (
            local result=$(verify_file_exists "$new_root_path" "$filename")
            echo "$filename|$result" >> "$results_file"
        ) &
        
        ((job_count++))
        
        # Limit concurrent jobs
        if [[ $job_count -ge $optimal_jobs ]]; then
            wait
            job_count=0
        fi
    done < "$files_list"
    
    # Wait for remaining jobs
    wait
    
    # Return results file path for processing
    echo "$results_file"
}

# Function to generate summary report
generate_summary_report() {
    local xml_file="$1"
    local new_root_path="$2"
    local success_count="$3"
    local error_count="$4"
    local total_files="$5"
    local processing_time="$6"
    local dry_run="$7"
    local errors_list="$8"
    
    local mode="UPDATE"
    if [[ "$dry_run" == "true" ]]; then
        mode="DRY RUN"
    fi
    
    # Calculate statistics
    local success_rate=0
    local error_rate=0
    if [[ $total_files -gt 0 ]]; then
        success_rate=$(echo "scale=1; $success_count * 100 / $total_files" | bc 2>/dev/null || echo "0")
        error_rate=$(echo "scale=1; $error_count * 100 / $total_files" | bc 2>/dev/null || echo "0")
    fi
    
    # Log summary header
    log_message "INFO" "============================================================"
    log_message "INFO" "REKORDBOX PATH UPDATER - $mode SUMMARY"
    log_message "INFO" "============================================================"
    
    # Basic information
    log_message "INFO" "XML File: $xml_file"
    log_message "INFO" "New Root Path: $new_root_path"
    log_message "INFO" "Processing Time: ${processing_time}s"
    log_message "INFO" "Mode: $mode"
    
    # Statistics
    log_message "INFO" ""
    log_message "INFO" "STATISTICS:"
    log_message "INFO" "  Total Files Processed: $total_files"
    log_message "INFO" "  Successfully Updated: $success_count ($success_rate%)"
    log_message "INFO" "  Errors: $error_count ($error_rate%)"
    
    # Performance metrics
    if [[ $total_files -gt 0 ]]; then
        local files_per_second=$(echo "scale=1; $total_files / $processing_time" | bc 2>/dev/null || echo "0")
        log_message "INFO" "  Processing Speed: ${files_per_second} files/second"
    fi
    
    # Error details
    if [[ -n "$errors_list" ]]; then
        log_message "INFO" ""
        log_message "INFO" "ERROR DETAILS:"
        echo "$errors_list" | while IFS= read -r error; do
            if [[ -n "$error" ]]; then
                log_message "ERROR" "  - $error"
            fi
        done
    fi
    
    # Recommendations
    log_message "INFO" ""
    log_message "INFO" "RECOMMENDATIONS:"
    if [[ $error_count -eq 0 ]]; then
        log_message "INFO" "  ✓ All files were successfully processed!"
    elif [[ $error_count -lt $((total_files / 10)) ]]; then
        log_message "INFO" "  ⚠ Some files were not found. Check the error list above."
        log_message "INFO" "  ✓ Most files were successfully processed."
    else
        log_message "WARNING" "  ✗ Many files were not found. Please check:"
        log_message "WARNING" "    - File paths are correct"
        log_message "WARNING" "    - Files exist at the new location"
        log_message "WARNING" "    - File names match exactly (case-sensitive)"
    fi
    
    if [[ "$dry_run" == "true" ]]; then
        log_message "INFO" ""
        log_message "INFO" "DRY RUN COMPLETE:"
        log_message "INFO" "  No changes were made to your XML file."
        log_message "INFO" "  To apply these changes, run without --dry-run flag."
    fi
    
    log_message "INFO" "============================================================"
}

# Function to update the XML file
update_xml() {
    local xml_file="$1"
    local new_root_path="$2"
    local dry_run="$3"
    local max_jobs="${4:-8}"
    
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
    
    echo "Collecting files to verify..."
    
    # Use parallel processing for file verification
    local results_file=$(verify_files_parallel "$xml_file" "$new_root_path" "$max_jobs")
    
    echo "Processing verification results..."
    
    # Process results and update XML
    while IFS='|' read -r filename result; do
        local found=$(echo "$result" | cut -d: -f1)
        local found_path=$(echo "$result" | cut -d: -f2-)
        
        # Find the original location for this filename
        local original_location=$(xmlstarlet sel -t -m "//TRACK[@Location]" -v "@Location" "$xml_file" 2>/dev/null | \
            while IFS= read -r location; do
                if [[ "$location" =~ ^file://localhost/ ]]; then
                    local loc_filename=$(extract_filename "$location")
                    if [[ "$loc_filename" == "$filename" ]]; then
                        echo "$location"
                        break
                    fi
                fi
            done)
        
        if [[ "$found" == "true" ]]; then
            # Build new location with the actual found path
            local new_location=$(build_new_location "$new_root_path" "$filename")
            if [[ "$dry_run" != "true" ]]; then
                # Update the Location attribute in the temporary file
                xmlstarlet ed -u "//TRACK[@Location='$original_location']/@Location" -v "$new_location" "$temp_file" > "${temp_file}.new" 2>/dev/null
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
    done < "$results_file"
    
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
    
    # Clean up temporary files
    rm -f "$temp_file"
    rm -rf "$(dirname "$results_file")"
    
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
    local max_jobs="8"  # Default to 8 parallel jobs
    
    # Check for dry-run flag
    if [[ "$3" == "--dry-run" ]]; then
        dry_run="true"
    fi
    
    # Check for workers parameter
    if [[ "$4" == "--workers" && -n "$5" ]]; then
        max_jobs="$5"
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
    
    # Setup logging
    local log_filename=$(setup_logging "$xml_file" "$dry_run")
    log_message "INFO" "New Root Path: $new_root_path"
    log_message "INFO" "Dry Run: $dry_run"
    log_message "INFO" "Max Jobs: $max_jobs"
    
    echo "Processing XML file: $xml_file"
    echo "New root path: $new_root_path"
    if [[ "$dry_run" == "true" ]]; then
        echo "DRY RUN MODE - No changes will be made"
    fi
    echo "--------------------------------------------------"
    
    # Record start time
    local start_time=$(date +%s)
    
    # Update the XML file
    local result=$(update_xml "$xml_file" "$new_root_path" "$dry_run" "$max_jobs")
    local success_count=$(echo "$result" | cut -d' ' -f1)
    local error_count=$(echo "$result" | cut -d' ' -f2)
    
    # Calculate processing time
    local end_time=$(date +%s)
    local processing_time=$((end_time - start_time))
    local total_files=$((success_count + error_count))
    
    # Collect errors for summary
    local errors_list=""
    if [[ $error_count -gt 0 ]]; then
        # This would need to be collected during processing, but for now we'll use a placeholder
        errors_list="Some files were not found at the new location"
    fi
    
    # Generate comprehensive summary
    generate_summary_report "$xml_file" "$new_root_path" "$success_count" "$error_count" \
                          "$total_files" "$processing_time" "$dry_run" "$errors_list"
    
    # Print log file location
    echo ""
    echo "Detailed log saved to: $log_filename"
    
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