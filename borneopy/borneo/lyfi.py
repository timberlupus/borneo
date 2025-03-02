import logging
import asyncio
import struct
from cbor2 import dumps, loads
from borneo.device import AbstractBorneoDeviceCoapClient, BorneoError

from aiocoap import *

logging.basicConfig(level=logging.INFO)

from enum import Enum

class LedMode(Enum):
    NORMAL = 0
    DIMMING = 1
    NIGHTLIGHT = 2
    PREVIEW = 3

class LyfiCoapClient(AbstractBorneoDeviceCoapClient):

    async def get_lyfi_info(self):
        uri = self.address + '/borneo/lyfi/info'
        request = Message(code=GET, uri=uri)
        response = await self._context.request(request).response
        return loads(response.payload)

    async def get_lyfi_status(self):
        uri = self.address + '/borneo/lyfi/status'
        request = Message(code=GET, uri=uri)
        response = await self._context.request(request).response
        return loads(response.payload)

    async def get_color(self):
        uri = self.address + '/borneo/lyfi/color'
        request = Message(code=GET, uri=uri)
        response = await self._context.request(request).response
        return loads(response.payload)

    async def set_color(self, color):
        uri = self.address + '/borneo/lyfi/color'
        payload = dumps(color)
        request = Message(code=PUT, payload=payload, uri=uri)
        await self._context.request(request).response

    async def get_schedule(self):
        uri = self.address + '/borneo/lyfi/schedule'
        request = Message(code=GET, uri=uri)
        response = await self._context.request(request).response
        return loads(response.payload)

    async def set_schedule(self, schedule):
        uri = self.address + '/borneo/lyfi/schedule'
        payload = dumps(schedule)
        request = Message(code=PUT, payload=payload, uri=uri)
        await self._context.request(request).response

    async def enable_scheduler(self, is_enabled: bool):
        uri = self.address + '/borneo/lyfi/scheduler-enbaled'
        payload = dumps(is_enabled)
        request = Message(code=PUT, payload=payload, uri=uri)
        await self._context.request(request).response

    async def get_current_mode(self) -> LedMode:
        uri = self.address + '/borneo/lyfi/mode'
        request = Message(code=GET, uri=uri)
        response = await self._context.request(request).response
        return LedMode(loads(response.payload))

    async def set_current_mode(self, mode: LedMode):
        uri = self.address + '/borneo/lyfi/mode'
        payload = dumps(mode.value)
        request = Message(code=PUT, payload=payload, uri=uri)
        await self._context.request(request).response

    async def set_fan_power(self, power: int):
        uri = self.address + '/borneo/lyfi/fan/power'
        payload = dumps(power)
        request = Message(code=PUT, payload=payload, uri=uri)
        await self._context.request(request).response

    async def set_thermal_pid(self, kp: int, ki: int, kd: int):
        uri = self.address + '/borneo/lyfi/thermal/pid'
        payload = dumps([kp, ki, kd], canonical=True)
        request = Message(code=PUT, payload=payload, uri=uri)
        response = await self._context.request(request).response

    async def get_thermal_pid(self) -> int:
        uri = self.address + '/borneo/lyfi/thermal/pid'
        request = Message(code=GET, uri=uri)
        response = await self._context.request(request).response
        return loads(response.payload)

    async def set_keep_temp(self, kp: int):
        uri = self.address + '/borneo/lyfi/thermal/keep-temp'
        payload = dumps(kp)
        request = Message(code=PUT, payload=payload, uri=uri)
        response = await self._context.request(request).response

    async def get_keep_temp(self) -> int:
        uri = self.address + '/borneo/lyfi/thermal/keep-temp'
        request = Message(code=GET, uri=uri)
        response = await self._context.request(request).response
        return loads(response.payload)
