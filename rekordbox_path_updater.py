#!/usr/bin/env python3
"""
Rekordbox Path Updater

This script updates the root path of file locations in a Rekordbox backup XML file.
It extracts the filename from each Location tag, replaces the root path with a new one,
and verifies that the file exists at the new location.

Usage:
    python rekordbox_path_updater.py <xml_file> <new_root_path>

Example:
    python rekordbox_path_updater.py "rekordbox backup.xml" "/Volumes/External/Music/"
"""

import sys
import os
import xml.etree.ElementTree as ET
import urllib.parse
from pathlib import Path
import argparse
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed
from queue import Queue
import time
import logging
from datetime import datetime


def extract_filename_from_location(location_url):
    """
    Extract the filename from a file://localhost/ URL.
    
    Args:
        location_url (str): URL like "file://localhost/D:/Old%20Mix/song.mp3"
    
    Returns:
        str: The filename (e.g., "song.mp3")
    """
    # Remove the file://localhost/ prefix
    if location_url.startswith('file://localhost/'):
        file_path = location_url[17:]  # Remove "file://localhost/"
    else:
        file_path = location_url
    
    # URL decode the path
    decoded_path = urllib.parse.unquote(file_path)
    
    # Get just the filename
    filename = os.path.basename(decoded_path)
    
    return filename


def build_new_location(new_root_path, filename):
    """
    Build a new file://localhost/ URL with the new root path and filename.
    
    Args:
        new_root_path (str): The new root path (e.g., "/Volumes/External/Music/")
        filename (str): The filename to append
    
    Returns:
        str: New file://localhost/ URL
    """
    # Ensure the new root path ends with a separator
    if not new_root_path.endswith('/'):
        new_root_path += '/'
    
    # Build the full path using os.path.join for proper path handling
    full_path = os.path.join(new_root_path, filename)
    
    # URL encode the path
    encoded_path = urllib.parse.quote(full_path)
    
    # Build the file://localhost/ URL
    new_location = f"file://localhost/{encoded_path}"
    
    return new_location


def verify_file_exists(new_root_path, filename):
    """
    Verify that a file exists at the new location, searching all subdirectories.
    
    Args:
        new_root_path (str): The new root path
        filename (str): The filename to check
    
    Returns:
        tuple: (bool, str) - (True if found, path where found) or (False, None)
    """
    # Ensure the new root path ends with a separator
    if not new_root_path.endswith('/'):
        new_root_path += '/'
    
    # First check the root directory
    full_path = os.path.join(new_root_path, filename)
    if os.path.isfile(full_path):
        return True, full_path
    
    # If not found in root, search all subdirectories
    for root, dirs, files in os.walk(new_root_path):
        if filename in files:
            found_path = os.path.join(root, filename)
            return True, found_path
    
    return False, None


def setup_logging(xml_file_path, dry_run=False):
    """
    Setup logging to both console and file.
    
    Args:
        xml_file_path (str): Path to the XML file being processed
        dry_run (bool): Whether this is a dry run
    
    Returns:
        logging.Logger: Configured logger
    """
    # Create logs directory if it doesn't exist
    logs_dir = "logs"
    os.makedirs(logs_dir, exist_ok=True)
    
    # Create log filename with timestamp
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    xml_basename = os.path.splitext(os.path.basename(xml_file_path))[0]
    mode = "dry-run" if dry_run else "update"
    log_filename = f"{logs_dir}/{xml_basename}_{mode}_{timestamp}.log"
    
    # Configure logging
    logger = logging.getLogger(f"rekordbox_updater_{timestamp}")
    logger.setLevel(logging.INFO)
    
    # Create formatters
    console_formatter = logging.Formatter('%(levelname)s: %(message)s')
    file_formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
    
    # Console handler
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(logging.INFO)
    console_handler.setFormatter(console_formatter)
    
    # File handler
    file_handler = logging.FileHandler(log_filename, encoding='utf-8')
    file_handler.setLevel(logging.DEBUG)
    file_handler.setFormatter(file_formatter)
    
    # Add handlers
    logger.addHandler(console_handler)
    logger.addHandler(file_handler)
    
    return logger, log_filename


def get_optimal_worker_count(max_workers=None):
    """
    Calculate optimal number of worker threads based on system resources.
    
    Args:
        max_workers (int): User-specified worker count
    
    Returns:
        int: Optimal number of worker threads
    """
    if max_workers is not None:
        return max(1, min(max_workers, 64))  # Cap at 64, minimum 1
    
    # Get CPU count
    cpu_count = os.cpu_count() or 1
    
    # Get available memory (rough estimate)
    try:
        import psutil
        memory_gb = psutil.virtual_memory().total / (1024**3)
        # More memory = more threads possible
        memory_factor = min(2.0, memory_gb / 4.0)  # Cap at 2x for 8GB+
    except ImportError:
        memory_factor = 1.0  # Default if psutil not available
    
    # Calculate optimal workers
    # Base: CPU cores
    # Bonus: 50% more for I/O bound tasks (file system operations)
    # Memory factor: Adjust based on available RAM
    optimal_workers = int(cpu_count * 1.5 * memory_factor)
    
    # Apply reasonable bounds
    min_workers = max(2, cpu_count)  # At least 2, or CPU count
    max_workers = min(32, cpu_count * 4)  # Cap at 4x CPU count, max 32
    
    final_workers = max(min_workers, min(optimal_workers, max_workers))
    
    return final_workers


def verify_files_batch(file_list, new_root_path, max_workers=None):
    """
    Verify multiple files using multithreading for better performance.
    
    Args:
        file_list (list): List of (filename, location) tuples
        new_root_path (str): The new root path
        max_workers (int): Number of worker threads (auto-calculated if None)
    
    Returns:
        dict: {filename: (found, path)} mapping
    """
    optimal_workers = get_optimal_worker_count(max_workers)
    
    print(f"Using {optimal_workers} worker threads (CPU cores: {os.cpu_count() or 1})")
    
    results = {}
    
    def verify_single_file(args):
        filename, location = args
        found, found_path = verify_file_exists(new_root_path, filename)
        return filename, (found, found_path)
    
    with ThreadPoolExecutor(max_workers=optimal_workers) as executor:
        # Submit all verification tasks
        future_to_filename = {
            executor.submit(verify_single_file, (filename, location)): filename 
            for filename, location in file_list
        }
        
        # Collect results as they complete
        for future in as_completed(future_to_filename):
            filename, result = future.result()
            results[filename] = result
    
    return results


def update_rekordbox_xml(xml_file_path, new_root_path, dry_run=False, max_workers=None, logger=None):
    """
    Update the Rekordbox XML file with new file paths using multithreading.
    
    Args:
        xml_file_path (str): Path to the XML file
        new_root_path (str): New root path for files
        dry_run (bool): If True, don't modify the file, just report what would be changed
        max_workers (int): Number of worker threads for file verification
        logger: Logger instance for detailed logging
    
    Returns:
        tuple: (success_count, error_count, errors_list)
    """
    success_count = 0
    error_count = 0
    errors_list = []
    
    try:
        # Parse the XML file
        tree = ET.parse(xml_file_path)
        root = tree.getroot()
        
        # Collect all files to verify
        files_to_verify = []
        track_locations = {}  # filename -> track element mapping
        
        if logger:
            logger.info("Collecting files to verify...")
        print("Collecting files to verify...")
        
        for track in root.findall('.//TRACK'):
            location = track.get('Location')
            if location and location.startswith('file://localhost/'):
                filename = extract_filename_from_location(location)
                files_to_verify.append((filename, location))
                track_locations[filename] = track
        
        if not files_to_verify:
            if logger:
                logger.warning("No files found to verify.")
            print("No files found to verify.")
            return 0, 0, []
        
        if logger:
            logger.info(f"Found {len(files_to_verify)} files to verify. Starting multithreaded verification...")
        print(f"Found {len(files_to_verify)} files to verify. Starting multithreaded verification...")
        start_time = time.time()
        
        # Verify all files using multithreading
        verification_results = verify_files_batch(files_to_verify, new_root_path, max_workers)
        
        verification_time = time.time() - start_time
        if logger:
            logger.info(f"File verification completed in {verification_time:.2f} seconds")
        print(f"File verification completed in {verification_time:.2f} seconds")
        
        # Process results and update XML
        for filename, (found, found_path) in verification_results.items():
            track = track_locations[filename]
            
            if found:
                # Build new location with the actual found path
                new_location = build_new_location(new_root_path, filename)
                if not dry_run:
                    # Update the Location attribute
                    track.set('Location', new_location)
                success_count += 1
                relative_path = os.path.relpath(found_path, new_root_path) if found_path != os.path.join(new_root_path, filename) else "root"
                if logger:
                    logger.info(f"✓ Updated: {filename} (found in: {relative_path})")
                print(f"✓ Updated: {filename} (found in: {relative_path})")
            else:
                error_count += 1
                # Build the full path for error message using os.path.join
                full_path = os.path.join(new_root_path, filename)
                error_msg = f"File not found: {full_path} (searched all subdirectories)"
                errors_list.append(error_msg)
                if logger:
                    logger.error(f"✗ Error: {error_msg}")
                print(f"✗ Error: {error_msg}")
        
        # Save the modified XML if not a dry run
        if not dry_run and success_count > 0:
            # Create backup of original file
            backup_path = xml_file_path + '.backup'
            tree.write(backup_path, encoding='utf-8', xml_declaration=True)
            if logger:
                logger.info(f"Backup created: {backup_path}")
            print(f"\nBackup created: {backup_path}")
            
            # Write the updated XML
            tree.write(xml_file_path, encoding='utf-8', xml_declaration=True)
            if logger:
                logger.info(f"Updated XML file: {xml_file_path}")
            print(f"Updated XML file: {xml_file_path}")
        
        return success_count, error_count, errors_list
        
    except ET.ParseError as e:
        print(f"Error parsing XML file: {e}")
        return 0, 0, [f"XML parsing error: {e}"]
    except Exception as e:
        print(f"Unexpected error: {e}")
        return 0, 0, [f"Unexpected error: {e}"]


def generate_summary_report(logger, xml_file_path, new_root_path, success_count, error_count, 
                          errors_list, total_files, processing_time, dry_run=False):
    """
    Generate a comprehensive summary report.
    
    Args:
        logger: Logger instance
        xml_file_path (str): Path to the XML file
        new_root_path (str): New root path
        success_count (int): Number of successful updates
        error_count (int): Number of errors
        errors_list (list): List of error details
        total_files (int): Total number of files processed
        processing_time (float): Time taken to process
        dry_run (bool): Whether this was a dry run
    """
    mode = "DRY RUN" if dry_run else "UPDATE"
    
    # Calculate statistics
    success_rate = (success_count / total_files * 100) if total_files > 0 else 0
    error_rate = (error_count / total_files * 100) if total_files > 0 else 0
    
    # Log summary header
    logger.info("=" * 60)
    logger.info(f"REKORDBOX PATH UPDATER - {mode} SUMMARY")
    logger.info("=" * 60)
    
    # Basic information
    logger.info(f"XML File: {xml_file_path}")
    logger.info(f"New Root Path: {new_root_path}")
    logger.info(f"Processing Time: {processing_time:.2f} seconds")
    logger.info(f"Mode: {mode}")
    
    # Statistics
    logger.info("")
    logger.info("STATISTICS:")
    logger.info(f"  Total Files Processed: {total_files}")
    logger.info(f"  Successfully Updated: {success_count} ({success_rate:.1f}%)")
    logger.info(f"  Errors: {error_count} ({error_rate:.1f}%)")
    
    # Performance metrics
    if total_files > 0:
        files_per_second = total_files / processing_time
        logger.info(f"  Processing Speed: {files_per_second:.1f} files/second")
    
    # Error details
    if errors_list:
        logger.info("")
        logger.info("ERROR DETAILS:")
        for error in errors_list:
            logger.error(f"  - {error}")
    
    # Recommendations
    logger.info("")
    logger.info("RECOMMENDATIONS:")
    if error_count == 0:
        logger.info("  ✓ All files were successfully processed!")
    elif error_count < total_files * 0.1:  # Less than 10% errors
        logger.info("  ⚠ Some files were not found. Check the error list above.")
        logger.info("  ✓ Most files were successfully processed.")
    else:
        logger.warning("  ✗ Many files were not found. Please check:")
        logger.warning("    - File paths are correct")
        logger.warning("    - Files exist at the new location")
        logger.warning("    - File names match exactly (case-sensitive)")
    
    if dry_run:
        logger.info("")
        logger.info("DRY RUN COMPLETE:")
        logger.info("  No changes were made to your XML file.")
        logger.info("  To apply these changes, run without --dry-run flag.")
    
    logger.info("=" * 60)


def main():
    parser = argparse.ArgumentParser(
        description='Update file paths in Rekordbox backup XML file',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    
    parser.add_argument('xml_file', help='Path to the Rekordbox backup XML file')
    parser.add_argument('new_root_path', help='New root path for music files')
    parser.add_argument('--dry-run', action='store_true', 
                       help='Show what would be changed without modifying the file')
    parser.add_argument('--no-backup', action='store_true',
                       help='Skip creating a backup of the original file')
    parser.add_argument('--workers', type=int, default=None,
                       help='Number of worker threads (default: CPU count + 4)')
    
    args = parser.parse_args()
    
    # Check if XML file exists
    if not os.path.isfile(args.xml_file):
        print(f"Error: XML file '{args.xml_file}' not found.")
        sys.exit(1)
    
    # Check if new root path exists
    if not os.path.isdir(args.new_root_path):
        print(f"Error: New root path '{args.new_root_path}' is not a valid directory.")
        sys.exit(1)
    
    # Setup logging
    logger, log_filename = setup_logging(args.xml_file, args.dry_run)
    logger.info(f"Starting Rekordbox Path Updater")
    logger.info(f"XML File: {args.xml_file}")
    logger.info(f"New Root Path: {args.new_root_path}")
    logger.info(f"Dry Run: {args.dry_run}")
    logger.info(f"Workers: {args.workers}")
    
    print(f"Processing XML file: {args.xml_file}")
    print(f"New root path: {args.new_root_path}")
    if args.dry_run:
        print("DRY RUN MODE - No changes will be made")
    print("-" * 50)
    
    # Record start time
    start_time = time.time()
    
    # Update the XML file
    success_count, error_count, errors_list = update_rekordbox_xml(
        args.xml_file, args.new_root_path, args.dry_run, args.workers, logger
    )
    
    # Calculate processing time
    processing_time = time.time() - start_time
    total_files = success_count + error_count
    
    # Generate comprehensive summary
    generate_summary_report(
        logger, args.xml_file, args.new_root_path, 
        success_count, error_count, errors_list, 
        total_files, processing_time, args.dry_run
    )
    
    # Print log file location
    print(f"\nDetailed log saved to: {log_filename}")
    
    # Print summary
    print("-" * 50)
    print(f"Summary:")
    print(f"  Successfully processed: {success_count} files")
    print(f"  Errors: {error_count} files")
    
    if errors_list:
        print(f"\nFiles not found at new location:")
        for error in errors_list:
            print(f"  - {error}")
    
    if args.dry_run and success_count > 0:
        print(f"\nTo apply these changes, run without --dry-run flag")


if __name__ == "__main__":
    main() 