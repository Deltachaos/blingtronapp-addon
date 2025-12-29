# Blingtron.app - World of Warcraft AddOn

A World of Warcraft addon for managing guild officer notes and public notes from CSV data.

## Features

- Import CSV data to set guild officer notes and/or public notes
- Support for clearing notes for guild members not in the CSV
- Simple and intuitive interface
- Efficient processing that iterates through guild members once

## Installation

1. Download or clone this repository
2. Copy the `BlingtronApp` folder to your World of Warcraft `_retail_\Interface\AddOns\` directory
3. Restart World of Warcraft or reload your UI (`/reload`)
4. The addon should now appear in your AddOns list

## Usage

### Opening the AddOn

Type one of the following commands in chat:
- `/blingtron`
- `/blingtronapp`

### CSV Format

The CSV file should be in the following format:
```
charname-realmname,note
```

Where:
- `charname-realmname` is the character name and realm (e.g., `PlayerName-RealmName`)
- `note` is the note to set (can contain commas)

**Example:**
```
John-Dalaran,This is a note, with commas
Jane-Stormrage,Another note
Bob-Tichondrius,Simple note
```

### Setting Notes

1. Paste your CSV data into the text area
2. Select which note types to set:
   - **Set officer note**: Sets the officer note for matching guild members
   - **Set public note**: Sets the public note for matching guild members
   - **Clear missing**: Clears notes for guild members not in the CSV (optional)
3. Click "Process CSV" to apply the changes

### Notes

- You must be a guild officer with permission to set notes
- The addon requires you to be in a guild
- Character names are matched case-insensitively
- At least one note type checkbox must be selected before processing

## Requirements

- World of Warcraft Retail (Interface version 100105)
- Guild membership
- Officer permissions to set notes

## License

This addon is licensed under the GNU General Public License v3.0. See the LICENSE file for details.

## Version

Current version: 1.0.0

