import paho.mqtt.client as mqtt
import uuid
import time
import queue
import threading
import struct
import cbor2  # pip install cbor2
import asyncio

class MQTTRPCBase:
    HEADER_SIZE = 8  # 版本(1) + 类型(1) + ID(4) + 长度(2)
    VERSION = 1
    
    def _pack_message(self, msg_type, req_id, data):
        payload = cbor2.dumps(data)
        header = struct.pack('<BBIH', self.VERSION, msg_type, req_id, len(payload))  # 小端序
        return header + payload
    
    def _unpack_message(self, msg_payload):
        if len(msg_payload) < self.HEADER_SIZE:
            return None
        header = msg_payload[:self.HEADER_SIZE]
        version, msg_type, req_id, payload_len = struct.unpack('<BBIH', header)  # 小端序
        if version != self.VERSION or len(msg_payload) < self.HEADER_SIZE + payload_len:
            return None
        payload = msg_payload[self.HEADER_SIZE:self.HEADER_SIZE + payload_len]
        data = cbor2.loads(payload)
        return msg_type, req_id, data

class MQTTRPCClient(MQTTRPCBase):
    def __init__(self, broker="test.mosquitto.org", port=1883):  # 改为可靠 broker
        self.broker = broker
        self.port = port
        self.request_topic = "rpc/request"
        self.response_topic = "rpc/response"
        self.client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
        self.client.on_connect = self.on_connect
        self.client.on_message = self.on_message
        self.responses = {}  # {id: asyncio.Future}
        self.loop = None  # asyncio loop
    
    def on_connect(self, client, userdata, flags, reason_code, properties):
        print("Client connected to MQTT")
        client.subscribe(self.response_topic)
    
    def on_message(self, client, userdata, msg, properties=None):
        unpacked = self._unpack_message(msg.payload)
        if unpacked and unpacked[0] == 1:  # 响应类型
            msg_type, req_id, data = unpacked
            print(f"Client received response: {req_id}")
            if req_id in self.responses:
                future = self.responses.pop(req_id)
                if not future.done():
                    future.set_result(data)
    
    def connect(self):
        try:
            self.client.connect(self.broker, self.port, 60)
            self.client.loop_start()  # 启动后台循环
            print(f"Connected to {self.broker}:{self.port}")
        except Exception as e:
            print(f"Connection failed: {e}. Check network or use local broker.")
            raise
    
    async def call(self, method, params, timeout=10, retries=3):
        """异步发送请求，等待响应"""
        req_id = uuid.uuid4().int & 0xFFFFFFFF  # 32-bit ID
        data = {"method": method, "params": params}
        message = self._pack_message(0, req_id, data)  # 类型 0=请求
        
        for attempt in range(retries):
            future = asyncio.Future()
            self.responses[req_id] = future
            print(f"Sending request (attempt {attempt+1}/{retries})...")
            self.client.publish(self.request_topic, message, qos=1)
            
            try:
                response = await asyncio.wait_for(future, timeout=timeout)
                if "error" in response:
                    raise Exception(response["error"])
                return response["result"]
            except asyncio.TimeoutError:
                print(f"No response after {timeout}s, retrying...")
                self.responses.pop(req_id, None)
                await asyncio.sleep(1)
        raise TimeoutError("RPC call failed")

class MQTTRPCServer(MQTTRPCBase):
    def __init__(self, broker="test.mosquitto.org", port=1883):  # 改为可靠 broker
        self.broker = broker
        self.port = port
        self.request_topic = "rpc/request"
        self.response_topic = "rpc/response"
        self.client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
        self.client.on_connect = self.on_connect
        self.client.on_message = self.on_message
        self.request_queue = asyncio.Queue()  # 异步队列
    
    def on_connect(self, client, userdata, flags, reason_code, properties):
        print("Server connected to MQTT")
        client.subscribe(self.request_topic)
    
    def on_message(self, client, userdata, msg, properties=None):
        unpacked = self._unpack_message(msg.payload)
        if unpacked and unpacked[0] == 0:  # 请求类型
            msg_type, req_id, data = unpacked
            print(f"Server received request: {req_id}")
            self.request_queue.put_nowait((req_id, data))  # 同步放入队列
    
    def connect(self):
        try:
            self.client.connect(self.broker, self.port, 60)
            self.client.loop_start()  # 启动后台循环
            print(f"Connected to {self.broker}:{self.port}")
        except Exception as e:
            print(f"Connection failed: {e}. Check network or use local broker.")
            raise
    
    async def serve(self, handler_func):
        """异步启动服务器，处理请求"""
        while True:
            req_id, data = await self.request_queue.get()
            print(f"Server processing: {req_id}")
            try:
                result = handler_func(data["method"], data["params"])
                response_data = {"result": result, "error": None}
            except Exception as e:
                response_data = {"result": None, "error": str(e)}
            message = self._pack_message(1, req_id, response_data)  # 类型 1=响应
            print(f"Server sending response: {req_id}")
            self.client.publish(self.response_topic, message, qos=1)
            self.request_queue.task_done()

# 测试示例
async def main():
    def handler(method, params):
        if method == "add":
            return sum(params)
        raise ValueError("Unknown method")
    
    # 启动服务器
    server = MQTTRPCServer()
    server.connect()
    server_task = asyncio.create_task(server.serve(handler))
    
    # 等待服务器连接
    await asyncio.sleep(1)
    
    # 客户端测试
    client = MQTTRPCClient()
    client.connect()
    try:
        result = await client.call("add", [5, 3])
        print(f"Client result: {result}")
    except Exception as e:
        print(f"Client error: {e}")
    finally:
        client.client.loop_stop()
        server.client.loop_stop()
        server_task.cancel()

if __name__ == "__main__":
    asyncio.run(main())