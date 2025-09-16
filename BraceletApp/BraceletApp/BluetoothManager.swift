import Foundation
import CoreBluetooth

// --- You MUST replace these UUIDs with the ones from your device's documentation ---
let yourDeviceServiceUUID = CBUUID(string: "0000180D-0000-1000-8000-00805F9B34FB") // Example: Heart Rate Service
let yourDataCharacteristicUUID = CBUUID(string: "00002A37-0000-1000-8000-00805F9B34FB") // For reading data (NOTIFY)
let yourWritableCharacteristicUUID = CBUUID(string: "00002A50-0000-1000-8000-00805F9B34FB") // For writing data (WRITE)


class BluetoothManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    var tcpManager: TCPManager?
    var lastKnownHost: String?
    var lastKnownPort: Int?

    @Published var bluetoothState: String = "Unknown"
    @Published var peripheralStatus: String = "Disconnected"
    
    private var centralManager: CBCentralManager!
    private var discoveredPeripheral: CBPeripheral?
    private let restoreIdentifier = "com.yourapp.bluetooth.restorekey"
    private var writableCharacteristic: CBCharacteristic?

    override init() {
        super.init()
        let options = [CBCentralManagerOptionRestoreIdentifierKey: restoreIdentifier]
        centralManager = CBCentralManager(delegate: self, queue: nil, options: options)
    }

    func startScanning() {
        guard centralManager.state == .poweredOn else { return }
        self.bluetoothState = "Scanning..."
        centralManager.scanForPeripherals(withServices: [yourDeviceServiceUUID], options: nil)
    }
    
    func writeString(_ string: String) {
        guard let peripheral = discoveredPeripheral, let characteristic = writableCharacteristic else {
            print("Not ready to write. Missing peripheral or writable characteristic.")
            return
        }
        let data = Data(string.utf8)
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
    }
    
    // MARK: - Central Manager Delegate
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        DispatchQueue.main.async { self.bluetoothState = central.state == .poweredOn ? "Bluetooth is On" : "Bluetooth is Off" }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi: NSNumber) {
        self.discoveredPeripheral = peripheral
        self.discoveredPeripheral?.delegate = self
        central.stopScan()
        central.connect(discoveredPeripheral!)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        DispatchQueue.main.async { self.peripheralStatus = "Connected! Discovering services..." }
        peripheral.discoverServices([yourDeviceServiceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            if let peripheral = peripherals.first {
                self.discoveredPeripheral = peripheral
                self.discoveredPeripheral?.delegate = self
            }
        }
    }

    // MARK: - Peripheral Delegate
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service) // Discover all characteristics for the service
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            if characteristic.uuid == yourDataCharacteristicUUID {
                peripheral.setNotifyValue(true, for: characteristic)
            }
            if characteristic.uuid == yourWritableCharacteristicUUID {
                print("Writable characteristic found.")
                self.writableCharacteristic = characteristic
            }
        }
        if writableCharacteristic != nil {
            DispatchQueue.main.async { self.peripheralStatus = "Device Ready & Listening!" }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }
        let hexString = data.map { String(format: "%02hhx", $0) }.joined()
        let tcpMessage = "data=\(hexString)"
        guard let host = lastKnownHost, let port = lastKnownPort else { return }
        tcpManager?.sendBackgroundTask(host: host, port: port, message: tcpMessage)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error writing to characteristic: \(error.localizedDescription)")
            return
        }
        print("Successfully wrote value to characteristic \(characteristic.uuid)")
    }
}
