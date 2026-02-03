import logging
import asyncio
import struct
from cbor2 import dumps, loads
from borneo.device import AbstractBorneoDeviceCoapClient, BorneoError

from aiocoap import *

logging.basicConfig(level=logging.INFO)

from enum import Enum

class LedState(Enum):
    NORMAL = 0
    DIMMING = 1
    NIGHTLIGHT = 2
    PREVIEW = 3

class LyfiCoapClient(AbstractBorneoDeviceCoapClient):

    async def get_lyfi_info(self):
        """Get Lyfi device info including nominal power, channel count, and channel details."""
        uri = self.address + '/borneo/lyfi/info'
        request = Message(code=GET, uri=uri)
        try:
            response = await self._context.request(request).response
            if not response.code.is_successful():
                raise BorneoError(f"Request failed with code {response.code}")
            return loads(response.payload)
        except Exception as e:
            raise BorneoError(f"Error getting lyfi info: {str(e)}")

    async def get_lyfi_status(self):
        """Get Lyfi device status including state, mode, temperature, and power."""
        uri = self.address + '/borneo/lyfi/status'
        request = Message(code=GET, uri=uri)
        try:
            response = await self._context.request(request).response
            if not response.code.is_successful():
                raise BorneoError(f"Request failed with code {response.code}")
            return loads(response.payload)
        except Exception as e:
            raise BorneoError(f"Error getting lyfi status: {str(e)}")

    async def get_color(self):
        """Get the current LED color as a list of integers (one per channel)."""
        uri = self.address + '/borneo/lyfi/color'
        request = Message(code=GET, uri=uri)
        try:
            response = await self._context.request(request).response
            if not response.code.is_successful():
                raise BorneoError(f"Request failed with code {response.code}")
            return loads(response.payload)
        except Exception as e:
            raise BorneoError(f"Error getting color: {str(e)}")

    async def set_color(self, color):
        """Set the LED color. Color should be a list of integers (one per channel)."""
        uri = self.address + '/borneo/lyfi/color'
        payload = dumps(color)
        request = Message(code=PUT, payload=payload, uri=uri)
        try:
            response = await self._context.request(request).response
            if not response.code.is_successful():
                raise BorneoError(f"Request failed with code {response.code}")
        except Exception as e:
            raise BorneoError(f"Error setting color: {str(e)}")

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

    async def get_state(self) -> LedState:
        uri = self.address + '/borneo/lyfi/state'
        request = Message(code=GET, uri=uri)
        response = await self._context.request(request).response
        return LedState(loads(response.payload))
        uri = self.address + '/borneo/lyfi/state'
        request = Message(code=GET, uri=uri)
        response = await self._context.request(request).response
        return LedState(loads(response.payload))

    async def switch_state(self, state: LedState):
        uri = self.address + '/borneo/lyfi/state'
        payload = dumps(state.value)
        request = Message(code=PUT, payload=payload, uri=uri)
        await self._context.request(request).response

    async def set_fan_power(self, power: int):
        uri = self.address + '/borneo/lyfi/fan/power'
        payload = dumps(power)
        request = Message(code=PUT, payload=payload, uri=uri)
        await self._context.request(request).response

    async def set_keep_temp(self, kp: int):
        uri = self.address + '/borneo/lyfi/thermal/temp/keep'
        payload = dumps(kp)
        request = Message(code=PUT, payload=payload, uri=uri)
        response = await self._context.request(request).response

    async def get_keep_temp(self) -> int:
        uri = self.address + '/borneo/lyfi/thermal/temp/keep'
        request = Message(code=GET, uri=uri)
        response = await self._context.request(request).response
        return loads(response.payload)

    async def get_current_temp(self):
        uri = self.address + '/borneo/lyfi/thermal/temp/current'
        request = Message(code=GET, uri=uri)
        response = await self._context.request(request).response
        return loads(response.payload)

    async def get_thermal_settings(self):
        uri = self.address + '/borneo/lyfi/thermal/settings'
        request = Message(code=GET, uri=uri)
        response = await self._context.request(request).response
        return loads(response.payload)

    async def get_fan_mode(self):
        uri = self.address + '/borneo/lyfi/thermal/fan/mode'
        request = Message(code=GET, uri=uri)
        response = await self._context.request(request).response
        return loads(response.payload)

    async def set_fan_mode(self, mode: str):
        uri = self.address + '/borneo/lyfi/thermal/fan/mode'
        payload = dumps(mode)
        request = Message(code=PUT, payload=payload, uri=uri)
        await self._context.request(request).response

    async def get_manual_fan(self):
        uri = self.address + '/borneo/lyfi/thermal/fan/manual'
        request = Message(code=GET, uri=uri)
        response = await self._context.request(request).response
        return loads(response.payload)

    async def set_manual_fan(self, power: int):
        uri = self.address + '/borneo/lyfi/thermal/fan/manual'
        payload = dumps(power)
        request = Message(code=PUT, payload=payload, uri=uri)
        await self._context.request(request).response

    async def get_sun_schedule(self):
        uri = self.address + '/borneo/lyfi/sun/schedule'
        request = Message(code=GET, uri=uri)
        response = await self._context.request(request).response
        return loads(response.payload)

    async def get_sun_curve(self):
        uri = self.address + '/borneo/lyfi/sun/curve'
        request = Message(code=GET, uri=uri)
        response = await self._context.request(request).response
        return loads(response.payload)

    async def get_overheated_temp(self):
        uri = self.address + '/borneo/lyfi/protection/overheated-temp'
        request = Message(code=GET, uri=uri)
        response = await self._context.request(request).response
        return loads(response.payload)

    async def get_power_meas(self):
        uri = self.address + '/lyfi/power/meas/power'
        request = Message(code=GET, uri=uri)
        response = await self._context.request(request).response
        return loads(response.payload)

    async def get_temperature(self):
        uri = self.address + '/borneo/lyfi/temperature'
        request = Message(code=GET, uri=uri)
        response = await self._context.request(request).response
        return loads(response.payload)

    async def get_mode(self):
        uri = self.address + '/borneo/lyfi/mode'
        request = Message(code=GET, uri=uri)
        response = await self._context.request(request).response
        return loads(response.payload)

    async def set_mode(self, mode: int):
        uri = self.address + '/borneo/lyfi/mode'
        payload = dumps(mode)
        request = Message(code=PUT, payload=payload, uri=uri)
        await self._context.request(request).response

    async def get_correction_method(self):
        uri = self.address + '/borneo/lyfi/correction-method'
        request = Message(code=GET, uri=uri)
        response = await self._context.request(request).response
        return loads(response.payload)

    async def set_correction_method(self, method):
        uri = self.address + '/borneo/lyfi/correction-method'
        payload = dumps(method)
        request = Message(code=PUT, payload=payload, uri=uri)
        await self._context.request(request).response

    async def get_temporary_duration(self):
        uri = self.address + '/borneo/lyfi/temporary-duration'
        request = Message(code=GET, uri=uri)
        response = await self._context.request(request).response
        return loads(response.payload)

    async def set_temporary_duration(self, duration: int):
        uri = self.address + '/borneo/lyfi/temporary-duration'
        payload = dumps(duration)
        request = Message(code=PUT, payload=payload, uri=uri)
        await self._context.request(request).response

    async def get_geo_location(self):
        uri = self.address + '/borneo/lyfi/geo-location'
        request = Message(code=GET, uri=uri)
        response = await self._context.request(request).response
        return loads(response.payload)

    async def set_geo_location(self, location):
        uri = self.address + '/borneo/lyfi/geo-location'
        payload = dumps(location)
        request = Message(code=PUT, payload=payload, uri=uri)
        await self._context.request(request).response

    async def get_tz_enabled(self):
        uri = self.address + '/borneo/lyfi/tz/enabled'
        request = Message(code=GET, uri=uri)
        response = await self._context.request(request).response
        return loads(response.payload)

    async def set_tz_enabled(self, enabled: bool):
        uri = self.address + '/borneo/lyfi/tz/enabled'
        payload = dumps(enabled)
        request = Message(code=PUT, payload=payload, uri=uri)
        await self._context.request(request).response

    async def get_tz_offset(self):
        uri = self.address + '/borneo/lyfi/tz/offset'
        request = Message(code=GET, uri=uri)
        response = await self._context.request(request).response
        return loads(response.payload)

    async def set_tz_offset(self, offset: int):
        uri = self.address + '/borneo/lyfi/tz/offset'
        payload = dumps(offset)
        request = Message(code=PUT, payload=payload, uri=uri)
        await self._context.request(request).response

    async def get_cloud_enabled(self):
        uri = self.address + '/borneo/lyfi/cloud/enabled'
        request = Message(code=GET, uri=uri)
        response = await self._context.request(request).response
        return loads(response.payload)

    async def set_cloud_enabled(self, enabled: bool):
        uri = self.address + '/borneo/lyfi/cloud/enabled'
        payload = dumps(enabled)
        request = Message(code=PUT, payload=payload, uri=uri)
        await self._context.request(request).response

    async def get_acclimation(self):
        uri = self.address + '/borneo/lyfi/acclimation'
        request = Message(code=GET, uri=uri)
        response = await self._context.request(request).response
        return loads(response.payload)

    async def publish_acclimation(self, data):
        uri = self.address + '/borneo/lyfi/acclimation'
        payload = dumps(data)
        request = Message(code=POST, payload=payload, uri=uri)
        await self._context.request(request).response
