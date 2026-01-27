import Flutter
import UIKit
import ESPProvision

public class SwiftFlutterEspBleProvPlugin: NSObject, FlutterPlugin {
    private let SCAN_BLE_DEVICES = "scanBleDevices"
    private let SCAN_WIFI_NETWORKS = "scanWifiNetworks"
    private let SCAN_WIFI_NETWORKS_WITH_DETAILS = "scanWifiNetworksWithDetails"
    private let PROVISION_WIFI = "provisionWifi"
    private let SEND_DATA_TO_CUSTOM_END_POINT = "sendDataToCustomEndPoint"
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_esp_ble_prov", binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterEspBleProvPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let provisionService = BLEProvisionService(result: result);
        let arguments = call.arguments as! [String: Any]
        let security = arguments["security"] as? String
        
        if(call.method == SCAN_BLE_DEVICES) {
            let prefix = arguments["prefix"] as! String
            provisionService.searchDevices(prefix: prefix, security: security)
        } else if(call.method == SCAN_WIFI_NETWORKS) {
            let deviceName = arguments["deviceName"] as! String
            let proofOfPossession = arguments["proofOfPossession"] as! String
            provisionService.scanWifiNetworks(deviceName: deviceName, proofOfPossession: proofOfPossession, security: security)
        } else if(call.method == SCAN_WIFI_NETWORKS_WITH_DETAILS) {
            let deviceName = arguments["deviceName"] as! String
            let proofOfPossession = arguments["proofOfPossession"] as! String
            provisionService.scanWifiNetworksWithDetails(deviceName: deviceName, proofOfPossession: proofOfPossession, security: security)
        } else if(call.method == SEND_DATA_TO_CUSTOM_END_POINT) {
            let deviceName = arguments["deviceName"] as! String
            let proofOfPossession = arguments["proofOfPossession"] as! String
            let path = arguments["path"] as! String
            let data = (arguments["data"] as! FlutterStandardTypedData).data
            provisionService.sendData(
                deviceName: deviceName,
                proofOfPossession: proofOfPossession,
                path: path,
                data: data,
                security: security
            )
        } else if (call.method == PROVISION_WIFI) {
            let deviceName = arguments["deviceName"] as! String
            let proofOfPossession = arguments["proofOfPossession"] as! String
            let ssid = arguments["ssid"] as! String
            let passphrase = arguments["passphrase"] as! String
            provisionService.provision(
                deviceName: deviceName,
                proofOfPossession: proofOfPossession,
                ssid: ssid,
                passphrase: passphrase,
                security: security
            )
        } else {
            result("iOS " + UIDevice.current.systemVersion)
        }
    }
    
}

protocol ProvisionService {
    var result: FlutterResult { get }
    func searchDevices(prefix: String, security: String?) -> Void
    func scanWifiNetworks(deviceName: String, proofOfPossession: String, security: String?) -> Void
    func scanWifiNetworksWithDetails(deviceName: String, proofOfPossession: String, security: String?) -> Void
    func provision(deviceName: String, proofOfPossession: String, ssid: String, passphrase: String, security: String?) -> Void
    func sendData(deviceName: String, proofOfPossession: String, path: String, data: Data, security: String?) -> Void
}

private class BLEProvisionService: ProvisionService {
    fileprivate var result: FlutterResult
    
    init(result: @escaping FlutterResult) {
        self.result = result
    }
    
    func searchDevices(prefix: String, security: String?) {
        ESPProvisionManager.shared.searchESPDevices(devicePrefix: prefix, transport:.ble, security: security.toESPSecurity()) { deviceList, error in
            if(error != nil) {
                // Error code 27 = "No bluetooth device found" - return empty list instead of error
                if error!.code == 27 {
                    self.result([String]())
                    return
                }
                ESPErrorHandler.handle(error: error!, result: self.result)
                return
            }
            self.result(deviceList?.map({ (device: ESPDevice) -> String in
                return device.name
            }) ?? [])
        }
    }
    
    func scanWifiNetworks(deviceName: String, proofOfPossession: String, security: String?) {
        self.connect(deviceName: deviceName, proofOfPossession: proofOfPossession, security: security) {
            device in
            device?.scanWifiList { wifiList, error in
                if(error != nil) {
                    NSLog("Error scanning wifi networks, deviceName: \(deviceName) ")
                    ESPErrorHandler.handle(error: error!, result: self.result)
                }
                self.result(wifiList?.map({(networks: ESPWifiNetwork) -> String in return networks.ssid}))
                device?.disconnect()
            }
        }
    }
    
    func scanWifiNetworksWithDetails(deviceName: String, proofOfPossession: String, security: String?) {
        self.connect(deviceName: deviceName, proofOfPossession: proofOfPossession, security: security) {
            device in
            device?.scanWifiList { wifiList, error in
                if(error != nil) {
                    NSLog("Error scanning wifi networks with details, deviceName: \(deviceName) ")
                    ESPErrorHandler.handle(error: error!, result: self.result)
                }
                self.result(wifiList?.map({(networks: ESPWifiNetwork) -> [String: Any] in 
                    return [
                        "ssid": networks.ssid,
                        "rssi": networks.rssi,
                        "security": networks.auth.rawValue
                    ]
                }))
                device?.disconnect()
            }
        }
    }
    
    func provision(deviceName: String, proofOfPossession: String, ssid: String, passphrase: String, security: String?) {
        self.connect(deviceName: deviceName, proofOfPossession: proofOfPossession, security: security){
            device in
            device?.provision(ssid: ssid, passPhrase: passphrase) { status in
                switch status {
                case .success:
                    NSLog("Success provisioning device. ssid: \(ssid), deviceName: \(deviceName) ")
                    self.result(true)
                    device?.disconnect()
                case .configApplied:
                    NSLog("Wifi config applied device. ssid: \(ssid), deviceName: \(deviceName) ")
                case .failure:
                    NSLog("Failed to provision device. ssid: \(ssid), deviceName: \(deviceName) ")
                    self.result(false)
                    device?.disconnect()
                }
            }
        }
    }

    func sendData(deviceName: String, proofOfPossession: String, path: String, data: Data, security: String?) {
        self.connect(deviceName: deviceName, proofOfPossession: proofOfPossession, security: security) { device in
            device?.sendData(path: path, data: data) { returnData, error in
                if let error = error {
                    NSLog("Error sending data to custom endpoint, deviceName: \(deviceName) ")
                    self.result(FlutterError(code: "E_SEND_DATA_FAILED", message: error.localizedDescription, details: nil))
                    device?.disconnect()
                    return
                }
                self.result(returnData)
                device?.disconnect()
            }
        }
    }
    
    private func connect(deviceName: String, proofOfPossession: String, security: String?, completionHandler: @escaping (ESPDevice?) -> Void) {
        ESPProvisionManager.shared.createESPDevice(deviceName: deviceName, transport: .ble, security: security.toESPSecurity(), proofOfPossession: proofOfPossession) { espDevice, error in
            
            if(error != nil) {
                ESPErrorHandler.handle(error: error!, result: self.result)
                return
            }
            espDevice?.connect { status in
                switch status {
                case .connected:
                    completionHandler(espDevice!)
                case let .failedToConnect(error):
                    ESPErrorHandler.handle(error: error, result: self.result)
                default:
                    self.result(FlutterError(code: "DEVICE_DISCONNECTED", message: nil, details: nil))
                }
            }
        }
    }
    
}

private class ESPErrorHandler {
    static func handle(error: ESPError, result: FlutterResult) {
        result(FlutterError(code: String(error.code), message: error.description, details: nil))
    }
}

private extension Optional where Wrapped == String {
    func toESPSecurity() -> ESPSecurity {
        switch self?.lowercased() {
        case "secure1":
            return .secure
        case "secure2":
            if let sec2 = ESPSecurity(rawValue: 2) { // defensive in case SDK exposes security 2
                return sec2
            }
            return .secure
        default:
            return .unsecure
        }
    }
}
