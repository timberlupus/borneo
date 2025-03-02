import logging
import asyncio
import struct
from cbor2 import dumps, loads

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
        return loads(response.payload)

