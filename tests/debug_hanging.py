#!/usr/bin/env python3
"""
Debug script to test file system access and identify hanging issues
"""

import os
import time
import sys

def test_directory_access(path):
    """Test basic directory access"""
    print(f"Testing directory access: {path}")
    
    # Check if directory exists
    if not os.path.exists(path):
        print(f"ERROR: Directory does not exist: {path}")
        return False
    
    if not os.path.isdir(path):
        print(f"ERROR: Path is not a directory: {path}")
        return False
    
    print(f"✓ Directory exists: {path}")
    
    # Test read access
    try:
        files = os.listdir(path)
        print(f"✓ Read access OK - found {len(files)} items")
        return True
    except Exception as e:
        print(f"✗ Read access failed: {e}")
        return False

def test_file_walk(path, max_files=100):
    """Test os.walk on the directory"""
    print(f"Testing os.walk on: {path}")
    
    start_time = time.time()
    file_count = 0
    
    try:
        for root, dirs, files in os.walk(path):
            file_count += len(files)
            if file_count >= max_files:
                print(f"✓ Walk test OK - found {file_count} files (stopped at {max_files})")
                break
                
            # Add a small delay to prevent overwhelming the system
            time.sleep(0.001)
            
    except Exception as e:
        print(f"✗ Walk test failed: {e}")
        return False
    
    elapsed = time.time() - start_time
    print(f"✓ Walk test completed in {elapsed:.2f} seconds")
    return True

def test_file_exists(path, filename):
    """Test individual file existence check"""
    print(f"Testing file existence: {filename}")
    
    start_time = time.time()
    
    # First check root
    full_path = os.path.join(path, filename)
    if os.path.isfile(full_path):
        elapsed = time.time() - start_time
        print(f"✓ File found in root: {filename} ({elapsed:.3f}s)")
        return True
    
    # Then check subdirectories
    try:
        for root, dirs, files in os.walk(path):
            if filename in files:
                found_path = os.path.join(root, filename)
                elapsed = time.time() - start_time
                print(f"✓ File found in subdirectory: {found_path} ({elapsed:.3f}s)")
                return True
    except Exception as e:
        print(f"✗ File search failed: {e}")
        return False
    
    elapsed = time.time() - start_time
    print(f"✗ File not found: {filename} ({elapsed:.3f}s)")
    return False

def main():
    if len(sys.argv) != 2:
        print("Usage: python debug_hanging.py <directory_path>")
        sys.exit(1)
    
    path = sys.argv[1]
    
    print("=" * 60)
    print("DEBUGGING FILE SYSTEM ACCESS")
    print("=" * 60)
    
    # Test 1: Basic directory access
    if not test_directory_access(path):
        print("Basic directory access failed. Cannot proceed.")
        sys.exit(1)
    
    print()
    
    # Test 2: Directory walk
    if not test_file_walk(path):
        print("Directory walk failed. This might cause hanging.")
        sys.exit(1)
    
    print()
    
    # Test 3: Sample file existence checks
    print("Testing sample file existence checks...")
    
    # Get a few sample files from the directory
    try:
        sample_files = []
        for root, dirs, files in os.walk(path):
            sample_files.extend(files[:5])  # Take first 5 files
            if len(sample_files) >= 5:
                break
        
        if sample_files:
            print(f"Testing {len(sample_files)} sample files...")
            for filename in sample_files[:3]:  # Test first 3
                test_file_exists(path, filename)
                print()
        else:
            print("No files found to test")
            
    except Exception as e:
        print(f"Error during sample file testing: {e}")
    
    print("=" * 60)
    print("DEBUG COMPLETE")
    print("=" * 60)

if __name__ == "__main__":
    main() 