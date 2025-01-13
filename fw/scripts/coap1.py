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



    #print("Set fan power")
    #await client.set_fan_power(100)
    #print(await client.get_lyfi_status())
    
    new_schedule = [
        #(2*3600 + 60*21, (0,0,0,0,0)),
        #(3*3600 + 60, (9, 9, 9, 9, 9)),
        #(3*3600 + 60*23, (99, 99, 99, 99, 99)),
        (3600 * 8, (0, 0, 0, 0, 0)),
        (3600 * 8 + 30 * 60, (90, 65, 70, 50, 20)),
        (3600 * 23 - 30 * 60, (90, 65, 70, 50, 20)),
        (3600 * 23, (0, 0, 0, 0, 0)),
    ]
    new_schedule = []
    await client.set_schedule(new_schedule)

    #await client.set_auto_mode(True)
    print("set color")
    print(await client.set_color((70, 80, 60, 45, 15)))
    print(await client.get_color())
    print("all done.")

if __name__ == "__main__":
    asyncio.get_event_loop().run_until_complete(main())
