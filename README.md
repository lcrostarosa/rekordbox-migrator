# Rekordbox Path Updater

A simple tool to update file paths in Rekordbox backup XML files. It helps you move your music library to a new location and update your Rekordbox database accordingly—no coding experience required!

---

## 🟢 For Non-Developers: Quick Start

### 1. Prerequisites
- **macOS or Linux** (Windows users: see [Windows Subsystem for Linux](https://learn.microsoft.com/en-us/windows/wsl/install))
- **Python 3.6+** (usually pre-installed on macOS)
- **[Homebrew](https://brew.sh/)** (recommended for installing tools)
- **[Oh My Zsh](https://ohmyz.sh/)** (optional, for a friendlier terminal experience)

#### Install Homebrew (if you don't have it):
```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```
[Homebrew Documentation](https://docs.brew.sh/)

#### (Optional) Install Oh My Zsh for a better terminal:
```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```
[Oh My Zsh Documentation](https://ohmyz.sh/)

---

### 2. Download This Project
- Click the green **Code** button above and choose **Download ZIP**
- Unzip it and open the folder in your Terminal

---

### 3. Install All Dependencies

**Option A: If you have `make` installed (most common):**
```sh
make deps
```

**Option B: If you don't have `make` installed:**
```sh
# First install make
brew install make

# Then run the setup
make deps
```

**Option C: Manual installation (if you prefer):**
```sh
# Install Homebrew (if you don't have it)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Python and xmlstarlet
brew install python xmlstarlet

# Make scripts executable
chmod +x rekordbox_path_updater.py
chmod +x rekordbox_path_updater.sh
```

**What this does:**
- Checks your Python version
- Installs Python (if needed)
- Installs Homebrew (if needed)
- Installs `xmlstarlet` (for advanced features)
- Makes sure everything is ready to go!

---

### 4. Run the Tool

**Preview what will change (safe!):**
```sh
make dry-run XML_FILE="rekordbox backup.xml" NEW_PATH="/Volumes/External/Music/"
```

**Actually update your file:**
```sh
make update XML_FILE="rekordbox backup.xml" NEW_PATH="/Volumes/External/Music/"
```

**Enable debug logging for troubleshooting:**
```sh
make update DEBUG=true XML_FILE="rekordbox backup.xml" NEW_PATH="/Volumes/External/Music/"
```

**Restore from backup if needed:**
```sh
make restore XML_FILE="rekordbox backup.xml"
```

---

## 🛠️ What Does This Tool Do?
- Finds all your music file paths in your Rekordbox backup
- Lets you move your music to a new folder or drive
- Updates the XML so Rekordbox can find your music again
- Makes a backup before changing anything
- Shows you a list of any missing files

---

## 🧑‍💻 For Developers & Power Users
- See the rest of this README for advanced usage, Makefile commands, and troubleshooting.
- All scripts are in Python or Bash, and you can run them directly if you prefer.

---

## 🔗 Useful Links
- [Homebrew Documentation](https://docs.brew.sh/)
- [Oh My Zsh](https://ohmyz.sh/)
- [Python Downloads](https://www.python.org/downloads/)
- [Rekordbox Official Site](https://rekordbox.com/)

---

## 🔧 Makefile Commands (for all users)

| Command         | What it does                                      |
|-----------------|---------------------------------------------------|
| `make deps`     | Installs all dependencies (Python, Homebrew, etc) |
| `make install`  | Prepares scripts (run after `make deps`)          |
| `make dry-run`  | Shows what will change, but does NOT edit files   |
| `make update`   | Updates your XML file (creates a backup first)    |
| `make debug`    | Runs with debug logging enabled                   |
| `make debug-dry-run` | Dry-run with debug logging enabled              |
| `make restore`  | Restores your XML from the backup                 |
| `make help`     | Shows all available commands                      |

---

## 📝 Safety Tips
- Always run `make dry-run` first!
- Your original XML is backed up automatically.
- If you get stuck, check the error messages or ask for help.

---

## 📬 Need Help?
- If you have any questions, open an issue on GitHub or ask a friend who knows the terminal.
- You can also check the [Homebrew](https://docs.brew.sh/) and [Oh My Zsh](https://ohmyz.sh/) docs for help with your terminal.

---

## 🏁 You're Ready!
Just follow the steps above and your Rekordbox library will be updated for your new music location—no coding required!

---

# (Advanced/Developer Info Below)

## 📋 Prerequisites

### System Requirements
- **macOS, Linux, or Windows** (with Python support)
- **Python 3.6 or higher**
- **Internet connection** (for dependency installation)

### What You Need
1. **Rekordbox XML file** - Your exported library
2. **New music directory path** - Where your music files are now located
3. **Music files** - The actual audio files that should exist at the new path

## 🛠️ Installation

### Automatic Installation (Recommended)
```bash
# Clone or download this repository
git clone <repository-url>
cd rekordbox-editor

# Install dependencies and verify setup
make install
make test
```

### Manual Installation
```bash
# Install Python dependencies
pip install -r requirements.txt

# Make scripts executable
chmod +x rekordbox_path_updater.py
chmod +x rekordbox_path_updater.sh
```

## 📖 Detailed Usage

### Understanding Your Rekordbox

Your Rekordbox XML contains entries like this:
```xml
<TRACK Location="file://localhost/D:/Old%20Mix/03%20Together%20We%20Stand.mp3" />
```

The tool will:
1. Extract `03%20Together%20We%20Stand.mp3` (URL decoded to `03 Together We Stand.mp3`)
2. Look for this file at your new path
3. Update the Location to point to the new location
4. Leave unchanged if the file doesn't exist

### Step-by-Step Process

#### 1. Prepare Your Files
```bash
# Ensure your music files are in the new location
ls "/Volumes/External/Music/"
# Should show your .mp3, .wav, .aiff, .m4a files
```

#### 2. Test with Dry Run
```bash
make dry-run XML_FILE="rekordbox.xml" NEW_PATH="/Volumes/External/Music/"
```

This will show you:
- ✓ Files that will be updated (found at new location)
- ✗ Files that won't be updated (not found at new location)
- Summary of what will happen

#### 3. Run the Actual Update
```bash
make update XML_FILE="rekordbox.xml" NEW_PATH="/Volumes/External/Music/"
```

This will:
- Create a of your original file (`rekordbox.xml.backup`)
- Update all found files
- Leave unchanged files that don't exist
- Show a detailed report

### Command Line Options

#### Python Version
```bash
python rekordbox_path_updater.py <xml_file> <new_root_path> [options]

Options:
  --dry-run     Preview changes without modifying the file
  --no-backup   Skip creating a file
  -h, --help    Show help message
```

#### Bash Version
```bash
./rekordbox_path_updater.sh <xml_file> <new_root_path> [--dry-run]
```

## 🔧 Makefile Commands

```bash
# Install dependencies
make install

# Test the installation
make test

# Run with dry-run (preview changes)
make dry-run XML_FILE="your_file.xml" NEW_PATH="/your/new/path/"

# Run the actual update
make update XML_FILE="your_file.xml" NEW_PATH="/your/new/path/"

# Enable debug logging
make update DEBUG=true XML_FILE="your_file.xml" NEW_PATH="/your/new/path/"

# Debug mode with dry-run
make debug-dry-run XML_FILE="your_file.xml" NEW_PATH="/your/new/path/"

# Clean up temporary files
make clean

# Show help
make help
```

## 📁 File Structure

```
rekordbox-editor/
├── README.md                    # This file
├── Makefile                     # Automated build and run commands
├── requirements.txt             # Python dependencies
├── rekordbox_path_updater.py   # Python version (recommended)
├── rekordbox_path_updater.sh   # Bash version
├── resources/
│   └── test_rekordbox.xml      # Sample Rekordbox XML for testing
├── tests/
│   └── debug_hanging.py        # Debug script for file system issues
└── logs/                       # Log files
```

## ⚠️ Important Notes

### Safety Features
- **Automatic**: Original file is always backed up before changes
- **Dry-run mode**: Test changes before applying them
- **File verification**: Only updates files that exist at new location
- **Error reporting**: Comprehensive list of files that couldn't be found

### What Gets Updated
- Files that exist at the new location → **Updated**
- Files that don't exist at new location → **Left unchanged**
- Non-music files → **Left unchanged**

### Supported File Formats
- `.mp3` - MP3 audio files
- `.wav` - WAV audio files
- `.aiff` - AIFF audio files
- `.m4a` - M4A audio files
- `.flac` - FLAC audio files
- And other audio formats

## 🐛 Troubleshooting

### Common Issues

#### "XML file not found"
```bash
# Check if the file exists and has the correct name
ls -la "rekordbox.xml"
```

#### "New root path is not a valid directory"
```bash
# Verify the directory exists and is accessible
ls -la "/Volumes/External/Music/"
```

#### "No files were updated"
This usually means:
1. Files don't exist at the new location
2. Filenames don't match exactly (case sensitivity)
3. Path is incorrect

#### "Permission denied"
```bash
# Make scripts executable
chmod +x rekordbox_path_updater.py
chmod +x rekordbox_path_updater.sh
```

### Getting Help

#### Check File Locations
```bash
# List files in your new music directory
find "/Volumes/External/Music/" -name "*.mp3" | head -10

# Check if specific files exist
ls "/Volumes/External/Music/03 Together We Stand.mp3"
```

#### Verify XML Structure
```bash
# Check if your XML file is valid
python -c "import xml.etree.ElementTree as ET; ET.parse('rekordbox.xml')"
```

## 📊 Example Output

### Dry Run Output
```
Processing XML file: rekordbox.xml
New root path: /Volumes/External/Music/
DRY RUN MODE - No changes will be made
--------------------------------------------------
✓ Updated: 03 Together We Stand.mp3
✓ Updated: Mirror Cluster.wav
✗ Error: File not found: /Volumes/External/Music/Missing Song.mp3
✓ Updated: Put You On.m4a
--------------------------------------------------
Summary:
  Successfully processed: 3 files
  Errors: 1 files

Files not found at new location:
  - File not found: /Volumes/External/Music/Missing Song.mp3

To apply these changes, run without --dry-run flag
```

### Actual Update Output
```
Processing XML file: rekordbox.xml
New root path: /Volumes/External/Music/
--------------------------------------------------
✓ Updated: 03 Together We Stand.mp3
✓ Updated: Mirror Cluster.wav
✗ Error: File not found: /Volumes/External/Music/Missing Song.mp3
✓ Updated: Put You On.m4a

Backup created: rekordbox.xml.backup
Updated XML file: rekordbox.xml
--------------------------------------------------
Summary:
  Successfully processed: 3 files
  Errors: 1 files
```

## 🔄 Restoring from

If something goes wrong, you can restore from the:
```bash
# Restore the original file
cp "rekordbox.xml.backup" "rekordbox.xml"

# Or use the makefile
make restore
```

## 🚀 Performance Features

### Smart Multithreading
Both scripts automatically calculate the optimal number of worker threads based on your system resources:

**Automatic Thread Calculation:**
- **CPU Cores**: Base calculation on available CPU cores
- **Memory Factor**: Adjusts based on available RAM (more RAM = more threads possible)
- **I/O Optimization**: Adds 50% more threads for file system operations
- **Smart Bounds**: Minimum 2 threads, maximum 32 threads or 4x CPU cores

**Python Script:**
```bash
# Let the script choose optimal thread count (recommended)
python3 rekordbox_path_updater.py "rekordbox backup.xml" "/new/path/"

# Override with custom thread count
python3 rekordbox_path_updater.py "rekordbox backup.xml" "/new/path/" --workers 16
```

**Bash Script:**
```bash
# Let the script choose optimal thread count (recommended)
./rekordbox_path_updater.sh "rekordbox backup.xml" "/new/path/"

# Override with custom thread count
./rekordbox_path_updater.sh "rekordbox backup.xml" "/new/path/" 8
```

**Makefile:**
```bash
# Let the script choose optimal thread count (recommended)
make update XML_FILE="rekordbox backup.xml" NEW_PATH="/new/path/"

# Override with custom worker count
make update XML_FILE="rekordbox backup.xml" NEW_PATH="/new/path/" WORKERS=16
```

**System Requirements for Optimal Performance:**
- **psutil** (optional): For better memory detection in Python script
- **bc** (optional): For better calculations in bash script
- **nproc/sysctl**: For CPU core detection

### Debug Mode
For troubleshooting and detailed analysis, use debug mode:

```bash
# Enable debug logging
python3 rekordbox_path_updater.py "rekordbox backup.xml" "/new/path/" --debug

# Debug with single-threaded mode
python3 rekordbox_path_updater.py "rekordbox backup.xml" "/new/path/" --debug --single-thread

# Debug with dry-run
python3 rekordbox_path_updater.py "rekordbox backup.xml" "/new/path/" --debug --dry-run
```

**Debug Features:**
- **File-by-file logging**: Every file processed is logged
- **Subdirectory tracking**: Shows which subdirectories are being searched
- **Detailed timing**: Each step is timed and logged
- **Error tracing**: Complete error paths and causes
- **Performance metrics**: Detailed processing statistics

### Performance Tips
- **Large Libraries**: For libraries with 10,000+ tracks, the smart threading can provide 3-5x speed improvement
- **SSD vs HDD**: Performance gains are more noticeable on slower storage
- **Memory**: More RAM allows for more concurrent file operations
- **Network Drives**: Consider using fewer threads for network-mounted storage

## 📊 Logging and Reporting

### Comprehensive Logging
Both scripts now provide detailed logging to help you track and troubleshoot:

**Log Files:**
- **Location**: `logs/` directory (created automatically)
- **Naming**: `{xml_filename}_{mode}_{timestamp}.log`
- **Example**: `rekordbox_backup_dry-run_20241201_143022.log`

**Log Contents:**
- Detailed processing steps
- File verification results
- Error messages with full paths
- Performance metrics
- Processing time and statistics

**Debug Log Features:**
- **File-by-file processing**: Every file is logged with its status
- **Subdirectory search tracking**: Shows which directories are being searched
- **Detailed timing**: Each operation is timed
- **Error tracing**: Complete error paths and stack traces
- **Performance breakdown**: Detailed statistics for each phase

### Summary Reports
Each run generates a comprehensive summary including:

**Statistics:**
- Total files processed
- Success/error counts and percentages
- Processing speed (files/second)
- Processing time

**Error Details:**
- Complete list of missing files
- Full file paths that were searched
- Recommendations for troubleshooting

**Recommendations:**
- Success rate analysis
- Suggestions for improving results
- Next steps for dry runs

### Example Log Output
```
============================================================
REKORDBOX PATH UPDATER - DRY RUN SUMMARY
============================================================
XML File: rekordbox backup.xml
New Root Path: /Volumes/External/Music/
Processing Time: 2.34 seconds
Mode: DRY RUN

STATISTICS:
  Total Files Processed: 1,247
  Successfully Updated: 1,198 (96.1%)
  Errors: 49 (3.9%)
  Processing Speed: 532.5 files/second

ERROR DETAILS:
  - File not found: /Volumes/External/Music/Missing Song.mp3
  - File not found: /Volumes/External/Music/Another Missing.mp3

RECOMMENDATIONS:
  ⚠ Some files were not found. Check the error list above.
  ✓ Most files were successfully processed.

DRY RUN COMPLETE:
  No changes were made to your XML file.
  To apply these changes, run without --dry-run flag.
============================================================
```

## 📝 License

This tool is provided as-is for educational and personal use. Always your Rekordbox library before making changes.

## 🤝 Contributing

Feel free to submit issues or pull requests to improve this tool! 