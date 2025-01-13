#!/bin/python

import os
import subprocess
import argparse
import sys

__LANGUAGES = [
    'en',
    'zh_CN',
]

# Function to run shell commands and check for errors
def run_command(command):
    print(f"Executing: {command}")
    result = subprocess.run(command, shell=True, text=True, capture_output=True)
    if result.returncode != 0:
        print(f"Error occurred: {result.stderr}", file=sys.stderr)
        exit(result.returncode)

# Function to find all .dart files and generate messages.pot
def generate_pot(project_path):
    lib_path = os.path.join(project_path, "lib")  # Dart source code path
    assets_path = os.path.join(project_path, "assets", "i18n")  # Translation files directory
    languages = __LANGUAGES

    # Step 1: Find all Dart files recursively
    dart_files = []
    for root, dirs, files in os.walk(lib_path):
        for file in files:
            if file.endswith(".dart"):
                dart_files.append(os.path.relpath(os.path.join(root, file), lib_path))

    if not dart_files:
        print(f"No Dart files found in {lib_path}!")
        exit(1)

    # Step 2: Sort Dart files lexicographically
    dart_files.sort()

    # Ensure assets directory exists
    os.makedirs(assets_path, exist_ok=True)

    # Step 3: Generate .pot file
    pot_output_path = os.path.join(assets_path, "messages.pot")
    dart_files_string = " ".join(dart_files)
    command = f"xgettext --from-code=UTF-8 -L Python --keyword=translate --output={pot_output_path} --directory={lib_path} {dart_files_string}"
    run_command(command)

    # Step 4: Use msginit to create .po files for each language
    for lang in languages:
        po_file = os.path.join(assets_path, f"{lang}.po")

        # Create .po file using msginit
        if not os.path.exists(po_file) :
            print(f"Creating new .po file for {lang} at {po_file}")
            command = f"msginit --no-translator --input={pot_output_path} --locale={lang}.UTF-8 --output={po_file}"
            run_command(command)
        else:
            # Update the .po file with new translations using msgmerge
            print(f"Updating .po file for {lang}...")
            update_command = f"msgmerge --backup=off --previous --update {po_file} {pot_output_path}"
            run_command(update_command)

    # Step 5: Compile .po files to .mo
    # for lang in languages:
    #     print(f"Compiling .mo file for {lang}...")
    #     po_file = os.path.join(assets_path, f"{lang}.po")
    #     mo_file = os.path.join(assets_path, f"{lang}.mo")
    #     compile_command = f"msgfmt {po_file} -o {mo_file}"
    #     run_command(compile_command)

    print("Translation update complete!")

# Main function to parse command line arguments
def main():
    parser = argparse.ArgumentParser(description="Generate and update translation files.")
    parser.add_argument('project_path', help="The path to the Flutter project")
    args = parser.parse_args()

    # Run the script with the provided project path
    generate_pot(args.project_path)

if __name__ == "__main__":
    main()
