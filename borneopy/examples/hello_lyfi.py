import asyncio
import argparse
import json
from pprint import pprint

from borneo import LyfiCoapClient, LedMode

def pretty_print(response: dict):
    def bytes_serializer(obj: object):
        if isinstance(obj, bytes):
            return obj.hex().upper()
        raise TypeError(f"Object of type {obj.__class__.__name__} is not JSON serializable")
    print(json.dumps(response, indent=4, default=bytes_serializer))

async def main(address):

    async with LyfiCoapClient(f'coap://{address}') as client:

        response = await client.get_wellknown_core()
        print(">>>>>>>>>>>>>>>>>>>>>>>>>> Wellknown-core:")
        pprint(response, indent=4)

        print(">>>>>>>>>>>>>>>>>>>>>>>>>> Borneo-IoT device general information:")
        device_info = await client.get_info()
        pprint(device_info, indent=4)

        print(">>>>>>>>>>>>>>>>>>>>>>>>>> Get current time zone:")
        tz = await client.get_timezone()
        pprint(tz)

        print(">>>>>>>>>>>>>>>>>>>>>>>>>> LyFi device information:")
        lyfi_info = await client.get_lyfi_info()
        pprint(lyfi_info, indent=4)

        print(">>>>>>>>>>>>>>>>>>>>>>>>>> Current general status:")
        status = await client.get_status()
        pprint(status, indent=4)

        print(">>>>>>>>>>>>>>>>>>>>>>>>>> Current LyFi status:")
        status = await client.get_lyfi_status()
        pprint(status, indent=4)

        # Make sure the device is powered on
        print(">>>>>>>>>>>>>>>>>>>>>>>>>> LED Powered on:")
        powered_on = await client.get_on_off()
        pprint(powered_on, indent=4)

        if not powered_on:
            print(">>>>>>>>>>>>>>>>>>>>>>>>>> Turning the power on...")
            await client.set_on_off(True)


        print(">>>>>>>>>>>>>>>>>>>>>>>>>> LED controller schedule:")
        sch = await client.get_schedule()
        pprint(sch, indent=4)

        print(">>>>>>>>>>>>>>>>>>>>>>>>>> LED controller manual color:")
        color = await client.get_color()
        pprint(color, indent=4)

        print(">>>>>>>>>>>>>>>>>>>>>>>>>> Dimming demo:")
        mode = await client.get_current_mode()
        print(f"Current mode: { mode }")

        print(f"Switching the device to the dimming mode...")
        mode = await client.set_current_mode(LedMode.DIMMING)

        if device_info['modelID'] == 1: # BLC06MK1
            await client.set_color([10, 15, 10, 20, 15, 10])

        await asyncio.sleep(3)

        print(f"Switching the device to the normal mode...")
        mode = await client.set_current_mode(LedMode.NORMAL)

        print("\nAll done.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Hello Buce Example")
    parser.add_argument('address', help='Address of the Borneo-IoT LyFi compatible device')
    args = parser.parse_args()
    asyncio.get_event_loop().run_until_complete(main(args.address))