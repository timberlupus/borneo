# borneo.py

A open-source Python client library for devices under the Borneo-IoT Project.

## Features

- Basic device control (power on/off, reboot, factory reset, etc.)
- Device information queries
- Timezone settings
- Firmware upgrade checking
- CoAP OTA firmware updates

## Installation

```bash
pip install -r requirements.txt
```

## Usage Examples

### Basic Device Control

```python
import asyncio
from borneo.lyfi import LyfiCoapClient

async def main():
    async with LyfiCoapClient("coap://192.168.1.100") as device:
        # Get device information
        info = await device.get_info()
        print(f"Device info: {info}")
        
        # Control device power
        await device.set_on_off(True)
        status = await device.get_on_off()
        print(f"Device status: {status}")

if __name__ == "__main__":
    asyncio.run(main())
```

### CoAP OTA Firmware Update

```python
import asyncio
from borneo.lyfi import LyfiCoapClient

async def update_firmware():
    device_url = "coap://192.168.1.100"
    firmware_path = "firmware.bin"
    
    def progress_callback(current, total):
        percent = int((current / total) * 100)
        print(f"Upload progress: {percent}%")
    
    def status_callback(message):
        print(f"Status: {message}")
    
    async with LyfiCoapClient(device_url) as device:
        # Check OTA status
        status = await device.check_ota_status()
        if status['success']:
            print(f"Current partition: {status['current_partition']}")
        
        # Execute OTA update
        result = await device.perform_ota_update(
            firmware_path,
            progress_callback=progress_callback,
            status_callback=status_callback
        )
        
        if result['success']:
            print("Firmware update successful!")
        else:
            print(f"Update failed: {result['error']}")

if __name__ == "__main__":
    asyncio.run(update_firmware())
```

## Command Line Tools

### OTA Update Tool

```bash
# Execute OTA firmware update
python examples/ota_update.py coap://192.168.1.100 firmware.bin

# Check device OTA status only
python examples/ota_update.py coap://192.168.1.100
```

## API Documentation

### CoAP OTA Methods

#### `check_ota_status()`
Check device OTA status.

**Returns:**
```python
{
    'success': bool,
    'current_partition': str,      # Current running partition
    'update_status': str,          # Update status
    'bytes_received': int          # Bytes received
}
```

#### `upload_firmware(firmware_path, progress_callback=None)`
Upload firmware file to device.

**Parameters:**
- `firmware_path`: Path to firmware file
- `progress_callback`: Optional progress callback function `callback(current, total)`

**Returns:**
```python
{
    'success': bool,
    'message': str,
    'next_boot': str,              # Next boot partition
    'checksum': str,               # File checksum
    'size': int                    # File size
}
```

#### `perform_ota_update(firmware_path, progress_callback=None, status_callback=None)`
Execute complete OTA update process.

**Parameters:**
- `firmware_path`: Path to firmware file
- `progress_callback`: Optional progress callback function `callback(current, total)`
- `status_callback`: Optional status callback function `callback(message)`

**Returns:**
```python
{
    'success': bool,
    'message': str,
    'details': dict                # Detailed result information
}
```

## Dependencies

- `aiocoap>=0.4.12` - CoAP protocol support
- `cbor2>=5.6.5` - CBOR data format support
- `aiofiles` - Async file operations
