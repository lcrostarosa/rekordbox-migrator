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
    Verify that a file exists at the new location.
    
    Args:
        new_root_path (str): The new root path
        filename (str): The filename to check
    
    Returns:
        bool: True if file exists, False otherwise
    """
    # Ensure the new root path ends with a separator
    if not new_root_path.endswith('/'):
        new_root_path += '/'
    
    # Build the full path using os.path.join for proper path handling
    full_path = os.path.join(new_root_path, filename)
    
    # Check if file exists
    return os.path.isfile(full_path)


def update_rekordbox_xml(xml_file_path, new_root_path, dry_run=False):
    """
    Update the Rekordbox XML file with new file paths.
    
    Args:
        xml_file_path (str): Path to the XML file
        new_root_path (str): New root path for files
        dry_run (bool): If True, don't modify the file, just report what would be changed
    
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
        
        # Find all elements with Location attributes
        # The Location attribute is typically on TRACK elements
        for track in root.findall('.//TRACK'):
            location = track.get('Location')
            if location and location.startswith('file://localhost/'):
                # Extract filename from current location
                filename = extract_filename_from_location(location)
                
                # Build new location
                new_location = build_new_location(new_root_path, filename)
                
                # Verify file exists at new location
                if verify_file_exists(new_root_path, filename):
                    if not dry_run:
                        # Update the Location attribute
                        track.set('Location', new_location)
                    success_count += 1
                    print(f"✓ Updated: {filename}")
                else:
                    error_count += 1
                    # Build the full path for error message using os.path.join
                    full_path = os.path.join(new_root_path, filename)
                    error_msg = f"File not found: {full_path}"
                    errors_list.append(error_msg)
                    print(f"✗ Error: {error_msg}")
        
        # Save the modified XML if not a dry run
        if not dry_run and success_count > 0:
            # Create backup of original file
            backup_path = xml_file_path + '.backup'
            tree.write(backup_path, encoding='utf-8', xml_declaration=True)
            print(f"\nBackup created: {backup_path}")
            
            # Write the updated XML
            tree.write(xml_file_path, encoding='utf-8', xml_declaration=True)
            print(f"Updated XML file: {xml_file_path}")
        
        return success_count, error_count, errors_list
        
    except ET.ParseError as e:
        print(f"Error parsing XML file: {e}")
        return 0, 0, [f"XML parsing error: {e}"]
    except Exception as e:
        print(f"Unexpected error: {e}")
        return 0, 0, [f"Unexpected error: {e}"]


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
    
    args = parser.parse_args()
    
    # Check if XML file exists
    if not os.path.isfile(args.xml_file):
        print(f"Error: XML file '{args.xml_file}' not found.")
        sys.exit(1)
    
    # Check if new root path exists
    if not os.path.isdir(args.new_root_path):
        print(f"Error: New root path '{args.new_root_path}' is not a valid directory.")
        sys.exit(1)
    
    print(f"Processing XML file: {args.xml_file}")
    print(f"New root path: {args.new_root_path}")
    if args.dry_run:
        print("DRY RUN MODE - No changes will be made")
    print("-" * 50)
    
    # Update the XML file
    success_count, error_count, errors_list = update_rekordbox_xml(
        args.xml_file, args.new_root_path, args.dry_run
    )
    
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