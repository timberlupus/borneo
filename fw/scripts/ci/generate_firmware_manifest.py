#!/usr/bin/env python3
import json
import os
import sys
import shutil
import argparse

def main():
    parser = argparse.ArgumentParser(description='Generate firmware manifest and copy binary')
    parser.add_argument('base_path', help='The base directory path (e.g., ./borneo/fw/lyfi)')
    parser.add_argument('-o', '--output', help='Output directory (default: <base_path>/build)')
    args = parser.parse_args()

    base_dir = args.base_path

    if not os.path.exists(base_dir):
        print(f"Directory {base_dir} does not exist")
        sys.exit(1)

    if output_dir is None:
        output_dir = os.path.join(base_dir, "build")

    os.makedirs(output_dir, exist_ok=True)

    # Read version.txt
    version_file = os.path.join(base_dir, "version.txt")
    if not os.path.exists(version_file):
        print(f"Version file {version_file} does not exist")
        sys.exit(1)

    with open(version_file, 'r') as f:
        version = f.read().strip()

    # Read sdkconfig.json
    sdkconfig_file = os.path.join(base_dir, "build", "config", "sdkconfig.json")
    if not os.path.exists(sdkconfig_file):
        print(f"SDK config file {sdkconfig_file} does not exist")
        sys.exit(1)

    with open(sdkconfig_file, 'r') as f:
        sdkconfig = json.load(f)

    product_id = sdkconfig.get("BORNEO_PRODUCT_ID")
    idf_target = sdkconfig.get("IDF_TARGET")

    if not product_id or not idf_target:
        print("BORNEO_PRODUCT_ID or IDF_TARGET not found in sdkconfig.json")
        sys.exit(1)

    # Map IDF_TARGET to chipFamily
    chip_family_map = {
        "esp32": "ESP32",
        "esp32c3": "ESP32-C3",
        "esp32s2": "ESP32-S2",
        "esp32s3": "ESP32-S3",
        # Add more mappings as needed
    }
    chip_family = chip_family_map.get(idf_target.lower(), idf_target.upper())

    # Source binary
    source_bin = os.path.join(base_dir, "build", "merged-binary.bin")
    if not os.path.exists(source_bin):
        print(f"Source binary {source_bin} does not exist")
        sys.exit(1)

    # Destination binary name
    bin_name = f"{product_id.replace('/', '-')}_firmware_ce_v{version}.bin"
    dest_bin = os.path.join(output_dir, bin_name)

    # Copy the binary
    shutil.copy2(source_bin, dest_bin)
    print(f"Copied {source_bin} to {dest_bin}")

    # Generate manifest
    manifest = {
        "name": product_id,
        "version": version,
        "new_install_prompt_erase": True,
        "builds": [
            {
                "chipFamily": chip_family,
                "parts": [
                    {
                        "path": bin_name,
                        "offset": 0
                    }
                ]
            }
        ]
    }

    # Manifest file name
    manifest_name = f"{product_id.replace('/', '-')}_firmware_ce_v{version}.manifest.json"
    manifest_file = os.path.join(output_dir, manifest_name)

    with open(manifest_file, 'w') as f:
        json.dump(manifest, f, indent=4)

    print(f"Generated manifest {manifest_file}")

if __name__ == "__main__":
    main()