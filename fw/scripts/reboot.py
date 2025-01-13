import logging
import asyncio
from cbor2 import dumps, loads
from typing import cast

import aiocoap

from lyfi_coap_client import *

logging.basicConfig(level=logging.INFO)



async def main():
    async with LyfiDeviceCoapClient('coap://192.168.0.8') as client:

        await client.reboot()

    
    print("all done.")

if __name__ == "__main__":
    asyncio.get_event_loop().run_until_complete(main())

