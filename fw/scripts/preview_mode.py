import logging
import asyncio
from cbor2 import dumps, loads
from typing import cast

import aiocoap

from lyfi_coap_client import *

logging.basicConfig(level=logging.INFO)



async def main():
    client = LyfiDeviceCoapClient('coap://192.168.1.13')

    await client.open()
    response = await client.get_wellknown_core()
    print("Wellknown-core:")
    print(response)

    print("General device status:")
    print(await client.get_status())

    print("LyFi Device status:")
    status = await client.get_lyfi_status()
    print(status)

    new_schedule = [
        #(2*3600 + 60*21, (0,0,0,0,0)),
        #(3*3600 + 60, (9, 9, 9, 9, 9)),
        #(3*3600 + 60*23, (99, 99, 99, 99, 99)),
        (3600 * 8, (0, 0, 0, 0, 0)),
        (3600 * 9, (90, 65, 70, 50, 20)),
        (3600 * 16, (90, 65, 70, 90, 20)),
        (3600 * 16 + (15 * 60), (0, 0, 0, 0, 0)),
    ]
    await client.set_schedule(new_schedule)
    print(await client.get_schedule())
    await client.set_current_mode(1)
    await asyncio.sleep(2)

    await client.set_current_mode(4)
    print(await client.get_lyfi_status())

    print("all done.")

if __name__ == "__main__":
    asyncio.get_event_loop().run_until_complete(main())
