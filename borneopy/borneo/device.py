import logging
import asyncio
import struct
import os
import hashlib
from cbor2 import dumps, loads
from urllib.parse import urljoin
import aiofiles

from aiocoap import *

logging.basicConfig(level=logging.INFO)


class BorneoError(RuntimeError):
    pass


class AbstractBorneoDeviceCoapClient:
    def __init__(self, address):
        self.address = address

    async def open(self):
        self._context = await Context.create_client_context()

    async def close(self):
        await self._context.shutdown()

    async def __aenter__(self):
        await self.open()
        return self

    async def __aexit__(self, exc_type, exc, tb):
        await self.close()

    async def get_wellknown_core(self):
        uri = self.address + '/.well-known/core'
        request = Message(code=GET, uri=uri)
        response = await self._context.request(request).response
        return response.payload

    async def get_on_off(self):
        uri = self.address + '/borneo/power'
        request = Message(code=GET, uri=uri)
        response = await self._context.request(request).response
        return loads(response.payload)

    async def set_on_off(self, on_off: bool):
        uri = self.address + '/borneo/power'
        payload = dumps(on_off)
        msg = Message(code=PUT, payload=payload, uri=uri)
        await self._context.request(msg).response

    async def factory_reset(self):
        uri = self.address + '/borneo/factory/reset'
        msg = Message(code=POST, uri=uri, mtype=NON, no_response=26)
        await self._context.request(msg).response

    async def factory_set_name(self, name: str):
        uri = self.address + '/borneo/factory/name'
        payload = dumps(name)
        msg = Message(code=PUT, payload=payload, uri=uri)
        await self._context.request(msg).response

    async def reboot(self):
        uri = self.address + '/borneo/reboot'
        msg = Message(code=POST, uri=uri, mtype=NON, no_response=26)
        await self._context.request(msg).response

    async def get_info(self):
        uri = self.address + '/borneo/info'
        request = Message(code=GET, uri=uri)
        response = await self._context.request(request).response
        return loads(response.payload)

    async def get_timezone(self):
        uri = self.address + '/borneo/settings/timezone'
        request = Message(code=GET, uri=uri)
        response = await self._context.request(request).response
        return loads(response.payload)

    async def set_timezone(self, tz: str):
        uri = self.address + '/borneo/settings/timezone'
        payload = dumps(tz)
        request = Message(code=PUT, payload=payload, uri=uri)
        await self._context.request(request).response

    async def get_upgrade_new_version(self):
        uri = self.address + '/borneo/upgrade/new-version'
        request = Message(code=GET, uri=uri)
        response = await self._context.request(request).response
        return loads(response.payload)

    async def get_upgrade_checking(self):
        uri = self.address + '/borneo/upgrade/checking'
        request = Message(code=GET, uri=uri)
        response = await self._context.request(request).response
        return loads(response.payload)

    async def set_upgrade_checking(self):
        uri = self.address + '/borneo/upgrade/checking'
        payload = dumps(True)
        request = Message(code=PUT, payload=payload, uri=uri)
        await self._context.request(request).response

    async def is_upgrading(self):
        uri = self.address + '/borneo/upgrade/upgrading'
        request = Message(code=GET, uri=uri)
        response = await self._context.request(request).response
        return loads(response.payload)

    async def begin_upgrade(self):
        uri = self.address + '/borneo/upgrade/upgrading'
        payload = dumps(True)
        request = Message(code=PUT, payload=payload, uri=uri)
        await self._context.request(request).response

    async def get_status(self):
        uri = self.address + '/borneo/status'
        request = Message(code=GET, uri=uri)
        response = await self._context.request(request).response
        return loads(response.payload)    # CoAP OTA functionality methods
    async def _calculate_file_checksum(self, firmware_path):
        """Calculate SHA256 checksum of the firmware file"""
        sha256 = hashlib.sha256()
        async with aiofiles.open(firmware_path, 'rb') as f:
            while True:
                data = await f.read(65536)  # 64KB chunks
                if not data:
                    break
                sha256.update(data)
        return sha256

    async def check_ota_status(self):
        """Check OTA server status"""
        uri = urljoin(self.address, "/borneo/ota/coap/status")
        request = Message(code=GET, uri=uri)
        try:
            response = await self._context.request(request).response
            if response.code.is_successful():
                status = loads(response.payload)
                return {
                    'success': True,
                    'current_partition': status.get('running_partition', 'unknown'),
                    'update_status': status.get('update_status', 'unknown'),
                    'bytes_received': status.get('bytes_received', 0)
                }
            else:
                return {'success': False, 'error': f'Status check failed: {response.code}'}
        except Exception as e:
            return {'success': False, 'error': f'Status check error: {str(e)}'}

    async def upload_firmware(self, firmware_path, progress_callback=None):
        """
        Upload firmware file for OTA update
        
        Args:
            firmware_path (str): Path to firmware file
            progress_callback (callable, optional): Progress callback function, receives (current, total) parameters
            
        Returns:
            dict: Dictionary containing operation result
        """
        if not os.path.exists(firmware_path):
            return {'success': False, 'error': f'Firmware file {firmware_path} does not exist'}

        file_size = os.path.getsize(firmware_path)
        sha256 = await self._calculate_file_checksum(firmware_path)
        file_checksum = sha256.digest()

        if progress_callback:
            progress_callback(0, file_size)

        try:
            # Read entire firmware file
            async with aiofiles.open(firmware_path, 'rb') as f:
                firmware_data = await f.read()

            if progress_callback:
                progress_callback(len(firmware_data), file_size)

            # Create CoAP PUT request
            uri = urljoin(self.address, "/borneo/ota/coap/download")
            request = Message(code=PUT, uri=uri, payload=firmware_data)
            request.remote.maximum_block_size_exp = 5  # 1024 bytes

            # Send request and wait for response
            response = await self._context.request(request).response

            # Process server response
            if response.code.is_successful():
                # Send POST request to complete update
                post_payload = dumps({
                    "checksum": file_checksum,
                })
                post_request = Message(code=POST, payload=post_payload, uri=uri)
                
                try:
                    post_response = await self._context.request(post_request).response
                    if post_response.code.is_successful():
                        result = loads(post_response.payload)
                        return {
                            'success': True,
                            'message': 'Firmware update successfully triggered',
                            'next_boot': result.get('next_boot', 'unknown'),
                            'checksum': sha256.hexdigest(),
                            'size': file_size
                        }
                    else:
                        return {'success': False, 'error': f'Update trigger failed: {post_response.code}'}
                except Exception as e:
                    return {'success': False, 'error': f'Error triggering update: {str(e)}'}
            else:
                return {'success': False, 'error': f'Upload failed, server returned code: {response.code}'}
                
        except Exception as e:
            return {'success': False, 'error': f'Request failed: {str(e)}'}

    async def perform_ota_update(self, firmware_path, progress_callback=None, status_callback=None):
        """
        Execute complete OTA update process
        
        Args:
            firmware_path (str): Path to firmware file
            progress_callback (callable, optional): Progress callback function
            status_callback (callable, optional): Status callback function
            
        Returns:
            dict: Dictionary containing operation result
        """
        try:
            # 1. Check server status
            if status_callback:
                status_callback("Checking server status...")
            
            status_result = await self.check_ota_status()
            if not status_result['success']:
                return status_result

            # 2. Upload firmware
            if status_callback:
                status_callback("Uploading firmware...")
            
            upload_result = await self.upload_firmware(firmware_path, progress_callback)
            if not upload_result['success']:
                return upload_result

            # 3. Wait for device reboot
            if status_callback:
                status_callback("Firmware update completed, device will reboot automatically...")

            return {
                'success': True,
                'message': 'Firmware update process completed, device should reboot automatically with new firmware',
                'details': upload_result
            }

        except Exception as e:
            return {'success': False, 'error': f'Error during OTA update process: {str(e)}'}

