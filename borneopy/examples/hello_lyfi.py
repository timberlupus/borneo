import asyncio
import argparse
import json

from borneo import LyfiCoapClient

async def main(address):

    async with LyfiCoapClient(f'coap://{address}') as client:

        response = await client.get_wellknown_core()
        print(">>>>>>>>>>>>>>>>>>>>>>>>>> Wellknown-core:")
        print(response)

        print(">>>>>>>>>>>>>>>>>>>>>>>>>> Device information:")
        print(await client.get_info())

        print(">>>>>>>>>>>>>>>>>>>>>>>>>> Get current time zone:")
        print(await client.get_timezone())

        print(await client.get_info())

        print(">>>>>>>>>>>>>>>>>>>>>>>>>> LyFi information:")
        print(await client.get_lyfi_info())

        print(">>>>>>>>>>>>>>>>>>>>>>>>>> Current status:")
        print(await client.get_status())

        print(">>>>>>>>>>>>>>>>>>>>>>>>>> Current LyFi status:")
        print(await client.get_lyfi_status())

        print(">>>>>>>>>>>>>>>>>>>>>>>>>> LED controller schedule:")
        print(await client.get_schedule())

        print(">>>>>>>>>>>>>>>>>>>>>>>>>> LED controller manual color:")
        print(await client.get_color())
        print("All done.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Hello Buce Example")
    parser.add_argument('address', help='Address of the Borneo-IoT LyFi compatible device')
    args = parser.parse_args()
    asyncio.get_event_loop().run_until_complete(main(args.address))