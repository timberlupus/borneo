import logging
import asyncio
from cbor2 import dumps, loads
from typing import cast

import aiocoap

from lyfi_coap_client import *

logging.basicConfig(level=logging.INFO)



async def main():
    client = LyfiDeviceCoapClient('coap://192.168.0.9')

    await client.open()
    response = await client.get_wellknown_core()
    print("Wellknown-core:")
    print(response)

    print("Device information:")
    print(await client.get_info())

    print("Current status:")
    print(await client.get_status())

    print("Current LyFi status:")
    print(await client.get_lyfi_status())

    print("Do Factory init")
    args = {
        "serno": "acdsee",
    }
    print(await client.factory_init(args))
    
    print("all done.")

if __name__ == "__main__":
    asyncio.get_event_loop().run_until_complete(main())
