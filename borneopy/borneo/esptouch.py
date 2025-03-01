# Rewritten from https://github.com/KurdyMalloy/EsptouchPython 
# Original author: Jean-Michel Julien 


import socket
import time
import asyncio


class EspTouch:
    def __init__(self, ssid, password, broadcast, ip, bssid=None):
        self.ssid_bytes = bytes(ssid.encode())
        self.password_bytes = bytes(password.encode())
        self.ip_bytes = bytes(map(int, ip.split('.')))
        self.bssid_bytes = bytes.fromhex(bssid) if bssid else bytes()
        self.use_broadcast = broadcast.lower() == 't'
        self.data = self.ip_bytes + self.password_bytes + self.ssid_bytes
        self.data_to_send = []
        self.address_count = 0
        self.send_buffer = bytearray(600)

    def _add_to_crc(self, b, crc):
        if b < 0:
            b += 256
        for i in range(8):
            odd = ((b ^ crc) & 1) == 1
            crc >>= 1
            b >>= 1
            if odd:
                crc ^= 0x8C  # this means crc ^= 140
        return crc

    def encode_data_byte(self, data_byte, sequence_header):
        if sequence_header > 127:
            raise ValueError('sequenceHeader must be between 0 and 127')

        crc = 0
        crc = self._add_to_crc(data_byte, crc)
        crc = self._add_to_crc(sequence_header, crc)

        crc_high, crc_low = crc >> 4, crc & 0x0F
        data_high, data_low = bytes([data_byte])[0] >> 4, bytes([data_byte])[0] & 0x0F

        first = ((crc_high << 4) | data_high) + 40
        second = 296 + sequence_header
        third = ((crc_low << 4) | data_low) + 40

        return first, second, third

    def get_guide_code(self):
        return 515, 514, 513, 512

    def get_datum_code(self):
        total_data_length = 5 + len(self.data)
        password_length = len(self.password_bytes)
        ssid_crc = 0
        for b in self.ssid_bytes:
            ssid_crc = self._add_to_crc(b, ssid_crc)
        bssid_crc = 0
        for b in self.bssid_bytes:
            bssid_crc = self._add_to_crc(b, bssid_crc)

        total_xor = 0
        total_xor ^= total_data_length
        total_xor ^= password_length
        total_xor ^= ssid_crc
        total_xor ^= bssid_crc

        for b in self.data:
            total_xor ^= b

        return total_data_length, password_length, ssid_crc, bssid_crc, total_xor

    def get_data_code(self):
        return self.data

    def prepare_data_to_send(self):
        self.data_to_send.clear()
        i = 0
        for d in self.get_datum_code():
            for b in self.encode_data_byte(d, i):
                self.data_to_send.append(b)
            i += 1

        i_bssid = len(self.get_datum_code()) + len(self.get_data_code())
        bssid_length = len(self.bssid_bytes)
        index_bssid = 0
        index_data = 0

        for d in self.get_data_code():
            if (index_data % 4) == 0 and index_bssid < bssid_length:
                for b in self.encode_data_byte(self.bssid_bytes[index_bssid], i_bssid):
                    self.data_to_send.append(b)
                i_bssid += 1
                index_bssid += 1
            for b in self.encode_data_byte(d, i):
                self.data_to_send.append(b)
            i += 1
            index_data += 1

        while index_bssid < bssid_length:
            for b in self.encode_data_byte(self.bssid_bytes[index_bssid], i_bssid):
                self.data_to_send.append(b)
            i_bssid += 1
            index_bssid += 1

    async def send_packet(self, _socket, _destination, _size):
        if not isinstance(_socket, socket.socket):
            raise ValueError("sendPacket error invalid socket object")

        await asyncio.to_thread(_socket.sendto, self.send_buffer[0:_size], _destination)

    def get_next_target_address(self):
        if self.use_broadcast:
            return "255.255.255.255", 7001
        else:
            self.address_count += 1
            multicast_address = "234.{}.{}.{}".format(self.address_count, self.address_count, self.address_count)
            self.address_count %= 100
            return multicast_address, 7001

    async def send_guide_code(self):
        index = 0
        destination = self.get_next_target_address()
        next_time = now = time.monotonic()
        end_time = now + 2
        while now < end_time or index != 0:
            now = time.monotonic()
            if now > next_time:
                await self.send_packet(self.get_client_socket(), destination, self.get_guide_code()[index])
                next_time = now + 0.008
                index += 1
                if index > 3:
                    destination = self.get_next_target_address()
                index %= 4

    async def send_data_code(self):
        index = 0
        destination = self.get_next_target_address()
        next_time = now = time.monotonic()
        end_time = now + 4
        while now < end_time or index != 0:
            now = time.monotonic()
            if now > next_time:
                await self.send_packet(self.get_client_socket(), destination, self.data_to_send[index])
                next_time = now + 0.008
                index += 1
                if (index % 3) == 0:
                    destination = self.get_next_target_address()
                index %= len(self.data_to_send)

    async def send_data(self, timeout=10, interval=0.2):
        self.prepare_data_to_send()
        start_time = asyncio.get_running_loop().time()
        while asyncio.get_running_loop().time() - start_time <= timeout:
            await self.send_guide_code()
            await self.send_data_code()
            await asyncio.sleep(interval)


    def get_client_socket(self):
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        if self.use_broadcast:
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        return sock




if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="ESPTouch WiFi Provisioning Utility")
    parser.add_argument('ssid', help='SSID of the WiFi')
    parser.add_argument('password', help='WiFi password')
    parser.add_argument('broadcast', help='Broadcast (T/F)', default='T')
    parser.add_argument('ip', help='Local machine IP address')
    parser.add_argument('bssid', help="BSSID (optional)", nargs='?')

    args = parser.parse_args()

    smart_config = EspTouch(args.ssid, args.password, args.broadcast, args.ip, args.bssid)
    asyncio.run(smart_config.send_data())