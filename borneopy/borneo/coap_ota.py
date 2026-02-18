"""CoAP OTA helpers for Borneo devices.

This module contains `CoAPFirmwareUpdater` and `perform_coap_ota`.
It is a direct rename of the previous `borneo.ota` implementation.
"""
from __future__ import annotations

import hashlib
import logging
import os
from typing import Any, Dict, Optional
from urllib.parse import urljoin

# runtime (third-party) dependencies — expected to be installed when OTA is used
import aiofiles
import cbor2
from aiocoap import Context, Message, Code
from aiocoap.numbers.constants import MAX_REGULAR_BLOCK_SIZE_EXP

logger = logging.getLogger(__name__)


class CoAPFirmwareUpdater:
    """Asynchronous CoAP firmware uploader.

    Usage example::

        updater = CoAPFirmwareUpdater("coap://192.168.1.10", "fw.bin")
        async with Context.create_client_context() as ctx:                # aiocoap Context
            status = await updater.check_server_status(ctx)
            result = await updater.send_firmware(ctx)

    All methods use logging and return structured results or raise
    exceptions — they never print.
    """

    def __init__(self, target_url: str, firmware_path: str, block_size: int = 512, logger: Optional[logging.Logger] = None) -> None:
        self.target_url = target_url.rstrip('/')
        self.firmware_path = firmware_path
        self.block_size = block_size
        self.block_exp = self._calculate_block_exp(block_size)
        self.logger = logger or logging.getLogger(__name__)

    @staticmethod
    def _calculate_block_exp(size: int) -> int:
        szx_map = {16: 0, 32: 1, 64: 2, 128: 3, 256: 4, 512: 5, 1024: 6}
        if size not in szx_map:
            raise ValueError(f"Unsupported block size: {size}")
        return szx_map[size]

    async def _calculate_file_checksum(self) -> bytes:
        """Return SHA256 digest (raw bytes) for the firmware file."""
        if not os.path.exists(self.firmware_path):
            raise FileNotFoundError(f"Firmware file not found: {self.firmware_path}")

        sha256 = hashlib.sha256()
        async with aiofiles.open(self.firmware_path, 'rb') as f:
            while True:
                chunk = await f.read(65536)
                if not chunk:
                    break
                sha256.update(chunk)
        return sha256.digest()

    async def check_server_status(self, context: Any) -> Optional[Dict[str, Any]]:
        """Query `/borneo/ota/coap/status` and return parsed CBOR payload.

        Returns the parsed dict on success or ``None`` on error/empty.
        """
        uri = urljoin(self.target_url + '/', "borneo/ota/coap/status")
        self.logger.debug("Checking server status: %s", uri)

        request = Message(code=Code.GET, uri=uri)
        try:
            response = await context.request(request).response
        except Exception as exc:
            self.logger.debug("Status request failed: %s", exc)
            return None

        if not response.code.is_successful():
            self.logger.debug("Status request returned non-success code: %s", response.code)
            return None

        if not response.payload:
            return {}

        try:
            status = cbor2.loads(response.payload)
            return status
        except Exception as exc:
            self.logger.debug("Failed to parse status payload: %s", exc)
            return None

    async def send_firmware(self, context: Optional[Any] = None) -> Dict[str, Any]:
        """Upload firmware and trigger update.

        If `context` is not provided the method will create and shutdown a
        client context internally. Returns a result dict containing at
        least the boolean ``'success'`` key and optional details.
        """
        if not os.path.exists(self.firmware_path):
            raise FileNotFoundError(f"Firmware file not found: {self.firmware_path}")

        file_size = os.path.getsize(self.firmware_path)
        sha256_digest = await self._calculate_file_checksum()

        created_context = False
        if context is None:
            context = await Context.create_client_context()
            created_context = True

        # cap to aiocoap supported maximum
        if self.block_exp > MAX_REGULAR_BLOCK_SIZE_EXP:
            self.block_exp = MAX_REGULAR_BLOCK_SIZE_EXP

        result: Dict[str, Any] = {"success": False}

        # load firmware into memory (keeps behaviour from example)
        async with aiofiles.open(self.firmware_path, 'rb') as f:
            firmware_data = await f.read()

        uri = urljoin(self.target_url + '/', "borneo/ota/coap/download")
        request = Message(code=Code.PUT, uri=uri, payload=firmware_data)

        # prefer to set block size if remote object is accessible
        try:
            request.remote.maximum_block_size_exp = self.block_exp
        except Exception:
            # older aiocoap versions may not expose `remote` until sending
            pass

        try:
            resp = await context.request(request).response
        except Exception as exc:
            result["error"] = f"PUT request failed: {exc}"
            self.logger.debug(result["error"])
            if created_context:
                try:
                    await context.shutdown()
                except Exception:
                    pass
            return result

        if not resp.code.is_successful():
            result["error"] = f"Server returned non-success response for PUT: {resp.code}"
            result["response_code"] = str(resp.code)
            if created_context:
                try:
                    await context.shutdown()
                except Exception:
                    pass
            return result

        # now POST checksum to trigger update
        post_payload = cbor2.dumps({"checksum": sha256_digest})
        post_req = Message(code=Code.POST, payload=post_payload, uri=uri)
        try:
            resp2 = await context.request(post_req).response
        except Exception as exc:
            result["error"] = f"POST trigger failed: {exc}"
            self.logger.debug(result["error"])
            if created_context:
                try:
                    await context.shutdown()
                except Exception:
                    pass
            return result

        if not resp2.code.is_successful():
            result["error"] = f"Server returned non-success response for POST: {resp2.code}"
            result["response_code"] = str(resp2.code)
            if created_context:
                try:
                    await context.shutdown()
                except Exception:
                    pass
            return result

        # parse response payload (may contain next_boot etc.)
        details: Dict[str, Any] = {}
        try:
            if resp2.payload:
                details = cbor2.loads(resp2.payload)
        except Exception as exc:
            self.logger.debug("Failed to parse POST response payload: %s", exc)

        result.update({
            "success": True,
            "sha256": sha256_digest.hex(),
            "next_boot": details.get("next_boot") if isinstance(details, dict) else None,
            "details": details,
        })

        if created_context:
            try:
                await context.shutdown()
            except Exception:
                pass

        return result


async def perform_coap_ota(target_url: str, firmware_path: str, block_size: int = 512, status_only: bool = False, logger: Optional[logging.Logger] = None) -> Dict[str, Any]:
    """High-level helper that checks status and (optionally) uploads firmware.

    Returns a dict with keys ``'success'``, ``'status'`` (server status if
    available) and ``'result'`` (upload result if performed).
    """
    updater = CoAPFirmwareUpdater(target_url, firmware_path, block_size=block_size, logger=logger)

    context = await Context.create_client_context()
    try:
        status = await updater.check_server_status(context)
        if status_only:
            return {"success": bool(status is not None), "status": status}

        # proceed to upload even if status is missing (caller decides)
        upload_result = await updater.send_firmware(context)
        return {"success": bool(upload_result.get("success")), "status": status, "result": upload_result}
    finally:
        try:
            await context.shutdown()
        except Exception:
            pass


__all__ = ["CoAPFirmwareUpdater", "perform_coap_ota"]