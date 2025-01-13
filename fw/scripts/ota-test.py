import logging
import asyncio
from cbor2 import dumps, loads
from typing import cast

import aiocoap

from lyfi_coap_client import *

logging.basicConfig(level=logging.INFO)



async def main():
    client = LyfiDeviceCoapClient('coap://192.168.0.8')

    await client.open()
    response = await client.get_wellknown_core()
    print("Wellknown-core:")
    print(response)

    print("General device status:")
    print(await client.get_status())

    print("Checking new version....")
    await client.set_upgrade_checking()

    await asyncio.sleep(5)

    print("get-upgrade-new-version:")
    print(await client.get_upgrade_new_version())

    print("Start to upgrade...")
    await client.begin_upgrade()
    while await client.is_upgrading():
        print("upgrading...")
        await asyncio.sleep(1)

    await asyncio.sleep(1)
    print("Rebooting...")
    await client.reboot()

    print("all done.")

if __name__ == "__main__":
    asyncio.get_event_loop().run_until_complete(main())
