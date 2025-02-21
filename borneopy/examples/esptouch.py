import argparse
import asyncio

from borneo import *

parser = argparse.ArgumentParser(description="ESPTouch WiFi Provisioning Utility")
parser.add_argument('ssid', help='SSID of the WiFi')
parser.add_argument('password', help='WiFi password')
parser.add_argument('broadcast', help='Broadcast (T/F)', default='T')
parser.add_argument('ip', help='Local machine IP address')
parser.add_argument('bssid', help="BSSID (optional)", nargs='?')

args = parser.parse_args()

smart_config = EspTouch(args.ssid, args.password, args.broadcast, args.ip, args.bssid)
asyncio.run(smart_config.send_data())