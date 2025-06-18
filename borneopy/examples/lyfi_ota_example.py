#!/usr/bin/env python3
"""
LyfiCoapClient OTA Usage Example

This example shows how to use the CoAP OTA functionality with LyfiCoapClient.
"""

import asyncio
import tempfile
import os
import sys

# Add borneo module path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from borneo.lyfi import LyfiCoapClient

def create_example_firmware():
    """Create an example firmware file for demonstration"""
    with tempfile.NamedTemporaryFile(mode='wb', suffix='.bin', delete=False) as f:
        # Create some dummy firmware data
        firmware_data = b'LYFI_FIRMWARE_v1.0.0_' + b'A' * 1024  # 1KB+ of data
        f.write(firmware_data)
        return f.name

async def demonstrate_ota_usage():
    """Demonstrate OTA usage with LyfiCoapClient"""
    print("=== LyfiCoapClient CoAP OTA Usage Example ===\n")
    
    # Create example firmware
    firmware_file = create_example_firmware()
    file_size = os.path.getsize(firmware_file)
    
    print(f"Created example firmware: {firmware_file}")
    print(f"File size: {file_size} bytes\n")
    
    # Example device URL (this won't actually connect)
    device_url = "coap://192.168.1.100"
    
    try:
        # Example 1: Basic OTA status check
        print("📋 Example 1: How to check OTA status")
        print("```python")
        print("async with LyfiCoapClient('coap://192.168.1.100') as lyfi:")
        print("    status = await lyfi.check_ota_status()")
        print("    if status['success']:")
        print("        print(f'Current partition: {status[\"current_partition\"]}')")
        print("        print(f'Update status: {status[\"update_status\"]}')")
        print("```\n")
        
        # Example 2: Firmware upload with progress
        print("📋 Example 2: How to upload firmware with progress tracking")
        print("```python")
        print("def progress_callback(current, total):")
        print("    percent = int((current / total) * 100)")
        print("    print(f'Progress: {percent}% ({current}/{total} bytes)')")
        print("")
        print("async with LyfiCoapClient('coap://192.168.1.100') as lyfi:")
        print("    result = await lyfi.upload_firmware('firmware.bin', progress_callback)")
        print("    if result['success']:")
        print("        print(f'Upload successful! Checksum: {result[\"checksum\"]}')")
        print("```\n")
        
        # Example 3: Complete OTA update process
        print("📋 Example 3: How to perform complete OTA update")
        print("```python")
        print("def progress_callback(current, total):")
        print("    percent = int((current / total) * 100)")
        print("    print(f'\\rUploading: {percent}%', end='', flush=True)")
        print("")
        print("def status_callback(message):")
        print("    print(f'Status: {message}')")
        print("")
        print("async with LyfiCoapClient('coap://192.168.1.100') as lyfi:")
        print("    result = await lyfi.perform_ota_update(")
        print("        'firmware.bin',")
        print("        progress_callback=progress_callback,")
        print("        status_callback=status_callback")
        print("    )")
        print("    ")
        print("    if result['success']:")
        print("        print('OTA update completed successfully!')")
        print("        print(f'Details: {result[\"details\"]}')")
        print("    else:")
        print("        print(f'OTA update failed: {result[\"error\"]}')")
        print("```\n")
        
        # Example 4: Error handling
        print("📋 Example 4: Error handling")
        print("```python")
        print("async with LyfiCoapClient('coap://192.168.1.100') as lyfi:")
        print("    try:")
        print("        result = await lyfi.perform_ota_update('firmware.bin')")
        print("        ")
        print("        if result['success']:")
        print("            print('Update successful!')")
        print("        else:")
        print("            print(f'Update failed: {result[\"error\"]}')")
        print("            ")
        print("    except Exception as e:")
        print("        print(f'Unexpected error: {e}')")
        print("```\n")
        
        # Show actual checksum calculation
        print("🔍 Demonstrating checksum calculation:")
        lyfi = LyfiCoapClient(device_url)
        sha256 = await lyfi._calculate_file_checksum(firmware_file)
        checksum = sha256.hexdigest()
        print(f"File checksum: {checksum}")
        print(f"File size: {file_size} bytes\n")
        
        # Command line usage
        print("🛠  Command Line Usage:")
        print(f"# Update firmware:")
        print(f"python examples/ota_update.py {device_url} {firmware_file}")
        print(f"")
        print(f"# Check status only:")
        print(f"python examples/ota_update.py {device_url}")
        print()
        
        print("✅ All examples demonstrated successfully!")
        
    except Exception as e:
        print(f"❌ Error during demonstration: {e}")
    finally:
        # Clean up
        if os.path.exists(firmware_file):
            os.unlink(firmware_file)
            print(f"🧹 Cleaned up example firmware file")

if __name__ == "__main__":
    asyncio.run(demonstrate_ota_usage())
