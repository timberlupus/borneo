import asyncio
import aiocoap
import cbor2
from datetime import datetime


async def main():
    protocol = await aiocoap.Context.create_client_context()
    request = aiocoap.Message(
        code=aiocoap.GET, uri="coap://192.168.0.17/borneo/heartbeat", observe=0)

    pr = protocol.request(request)
    r = await pr.response
    async for msg in pr.observation:
        try:
            result = cbor2.loads(msg.payload)
            print(f"Received: {result}")
        except Exception as e:
            print(f"Error decoding CBOR: {e}")

if __name__ == "__main__":
    asyncio.run(main())
