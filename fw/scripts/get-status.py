import logging
import asyncio
from cbor2 import dumps, loads
from typing import cast

import aiocoap

from lyfi_coap_client import *

logging.basicConfig(level=logging.INFO)



async def main():
    async with LyfiDeviceCoapClient('coap://192.168.0.15') as client:

        response = await client.get_wellknown_core()
        print("Wellknown-core:")
        print(response)

        print("Device information:")
        print(await client.get_info())

        print("Get current time zone:")
        print(await client.get_timezone())

        print("Set time zone to CST-9")
        await client.set_timezone("CST-8")

        print("Get current time zone again:")
        print(await client.get_timezone())


        print(await client.get_info())

        print("LyFi information:")
        print(await client.get_lyfi_info())

        print("Current status:")
        print(await client.get_status())

        print("Current LyFi status:")
        print(await client.get_lyfi_status())

        print("LED controller schedule:")
        print(await client.get_schedule())

        print(await client.get_color())
        print("all done.")

if __name__ == "__main__":
    asyncio.get_event_loop().run_until_complete(main())
