//
//  ViewController.swift
//  bt-test2
//
//  Created by Niklas Dusenlund on 2024-10-02.
//
import UIKit
import CoreBluetooth

class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate {

    var centralManager: CBCentralManager!
    var discoveredPeripheral: CBPeripheral?
    var pWriter: CBCharacteristic?
    var pReader: CBCharacteristic?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialize the CBCentralManager
        centralManager = CBCentralManager(delegate: self, queue: nil)
        print("initialized")
    }

    // MARK: - CBCentralManagerDelegate methods
    
    // This method gets called when the central manager’s state changes
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            // Bluetooth is powered on and ready, start scanning
            print("Bluetooth is powered on. Scanning for devices...")
            centralManager.scanForPeripherals(withServices: nil, options: nil)
        case .poweredOff:
            print("Bluetooth is powered off.")
        case .resetting:
            print("Bluetooth is resetting.")
        case .unauthorized:
            print("Bluetooth is not authorized.")
        case .unsupported:
            print("Bluetooth is not supported on this device.")
        case .unknown:
            print("Bluetooth state is unknown.")
        @unknown default:
            print("A new Bluetooth state is available.")
        }
    }

    // This method gets called when a peripheral is discovered
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        if peripheral.name != "bitbox" {
            print("Discovered peripheral: \(peripheral.name ?? "Unknown")")
            return
        }
        
        if discoveredPeripheral != nil {
            return;
        }
        
        print("Discovered a bitbox!")
        
        
        // Stop scanning once a device is found
        centralManager.stopScan()
        
        // Store a reference to the peripheral
        discoveredPeripheral = peripheral
        discoveredPeripheral?.delegate = self
        
        // Connect to the peripheral
        centralManager.connect(peripheral, options: nil)
    }

    // This method gets called when the central manager connects to the peripheral
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to peripheral: \(peripheral.name ?? "Unknown")")
        
        // Discover services once connected
        peripheral.discoverServices(nil)
    }

    // This method gets called when services are discovered on the peripheral
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("Error discovering services: \(error.localizedDescription)")
            return
        }
        
        if let services = peripheral.services {
            for service in services {
                print("Discovered service: \(service.uuid)")
                
                // Discover characteristics for each service
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }

    // This method gets called when characteristics are discovered
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("Error discovering characteristics: \(error.localizedDescription)")
            return
        }
        
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                print("Discovered characteristic: \(characteristic.uuid)")
                if let characteristics = service.characteristics {
                    for c in characteristics {
                        if c.uuid == CBUUID(string:"0001") {
                            pWriter = c
                        }
                        if c.uuid == CBUUID(string:"0002") {
                            pReader = c
                        }
                    }
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let _ = error {
            print("Failed to write")
            
        } else {
            print("Succeded to write")
        }
        let response = discoveredPeripheral?.readValue(for: pReader!)
        print("response \(pReader!.value)")
    }

    // This method gets called if the connection fails
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Failed to connect to peripheral: \(error?.localizedDescription ?? "Unknown error")")
    }

    // This method gets called if the peripheral disconnects
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected from peripheral: \(peripheral.name ?? "Unknown")")
        
        // Optionally, you can start scanning again after disconnection
        centralManager.scanForPeripherals(withServices: nil, options: nil)
    }
    @IBAction func doSomething(sender: UIButton, forEvent event: UIEvent){
        let max_len = discoveredPeripheral?.maximumWriteValueLength(for: CBCharacteristicWriteType.withoutResponse)
        print("Found writer service with max length \(max_len ?? 0)")
        let data = Data(repeating: 1, count: max_len!)
        discoveredPeripheral?.writeValue(data, for: pWriter!, type: .withResponse)
        
    }
}
