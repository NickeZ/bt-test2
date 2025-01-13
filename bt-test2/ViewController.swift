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
    var clock: ContinuousClock?;
    var startInstant: ContinuousClock.Instant?;
    var sends: Int = 0;
    var acks: Int = 0;
    var waitingForInfo: Bool = false;
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var consoleInApp: UILabel!
    @IBOutlet weak var messageBox: UITextField!
    @IBOutlet weak var connectionStatus: UILabel!
    @IBOutlet weak var ConnectButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        clock = ContinuousClock()
        
        // Initialize the CBCentralManager
        centralManager = CBCentralManager(delegate: self, queue: nil)
        
        //Looks for single or multiple taps.
         let tap = UITapGestureRecognizer(target: self, action: #selector(UIInputViewController.dismissKeyboard))

        view.addGestureRecognizer(tap)
    }

    // MARK: - CBCentralManagerDelegate methods
    
    // This method gets called when the central manager’s state changes
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            // Bluetooth is powered on and ready, start scanning
            print("Bluetooth is powered on.")
            //centralManager.scanForPeripherals(withServices: [CBUUID(string: "e1511a45-f3db-44c0-82b8-6c880790d1f1")], options: nil)
            //centralManager.scanForPeripherals(withServices: nil, options: nil)
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
    
    func peripheralDidUpdateName(_ peripheral: CBPeripheral) {
        connectionStatus!.text = "\(peripheral.name ?? "unknown")"
        print("New name: \(peripheral.name ?? "Unknown")")
    }

    // This method gets called when a peripheral is discovered
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        if discoveredPeripheral != nil {
            return;
        }
        
        print("Discovered a bitbox! \(peripheral.name ?? "unknown")")
        
        
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
        
        connectionStatus!.text = "\(peripheral.name ?? "unknown")"
        ConnectButton.isEnabled = true;
        
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
                //print("Discovered service: \(service.uuid)")
                
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
                //print("Discovered characteristic: \(characteristic.uuid)")
                if let characteristics = service.characteristics {
                    for c in characteristics {
                        if c.uuid == CBUUID(string:"0001") {
                            pWriter = c
                            let max_len = peripheral.maximumWriteValueLength(for: CBCharacteristicWriteType.withoutResponse)
                                print("Found writer service with max length \(max_len)")
                            
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
        if waitingForInfo {
            // Issue read
            peripheral.readValue(for: pReader!)
            waitingForInfo = false
        }
        if let _ = error {
            print("Failed to write")
            return
        }
        acks += 1;
        if acks == sends {
            if let startInstant {
                let duration = startInstant.duration(to: clock!.now);
                let millis = duration.components.seconds*1000 + duration.components.attoseconds/1000_000_000_000_000;
                let bandwidth = 4.0/Double(millis);
                consoleInApp.text?.append("SENT 4096 bytes payload in \(duration). \(String( format: "%.2f", bandwidth*1000)) kBps\n")
                print("SENT 4096 bytes payload in \(duration). \(bandwidth*1000) kBps");
            } else {
                consoleInApp.text?.append("SENT bytes\n")
                print("SENT bytes")
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: (any Error)?) {
        if pReader!.value == nil || pReader!.value!.isEmpty {
            label.text = "<NO MESSAGE>"
            return
        }
        label.text = ""
        for byte in pReader!.value! {
            label.text! += String(format: "%02X", byte);
        }
        
        consoleInApp.text?.append("RECV len: \(pReader!.value!)\n")
        dump(pReader!.value![..<10])
        print("read \(pReader!.value)")
    }

    // This method gets called if the connection fails
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Failed to connect to peripheral: \(error?.localizedDescription ?? "Unknown error")")
    }

    // This method gets called if the peripheral disconnects
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected from peripheral: \(peripheral.name ?? "Unknown")")
        discoveredPeripheral = nil;
        connectionStatus!.text = "Device Name"
        
        ConnectButton.isEnabled = false;
        
        // Optionally, you can start scanning again after disconnection
        //centralManager.scanForPeripherals(withServices: [CBUUID(string: "e1511a45-f3db-44c0-82b8-6c880790d1f1")], options: nil)
        //centralManager.scanForPeripherals(withServices: nil, options: nil)
    }
    
    @IBAction func sendButton(_ sender: Any) {
        startInstant = nil;
        if let p = discoveredPeripheral {
            let hello = Array(_: messageBox!.text!.utf8)
            let mtu = p.maximumWriteValueLength(for: CBCharacteristicWriteType.withoutResponse)
            if (hello.count > mtu - 7) {
                print("Cannot send message larger than \(mtu-7)")
                return
            }
            let cid = [UInt8](_:[0xEE, 0xEE, 0xEE, 0xEE]);
            let cmd = [UInt8](_:[UInt8(0x80)]);
            let sz = [UInt8](_:[UInt8(hello.count >> 8), UInt8(hello.count & 0xff)]);
            let header = cid + cmd + sz;
            let data = Data(_:header + hello);
            sends += 1;
            p.writeValue(data, for: pWriter!, type: .withResponse)
        }
    }
    @IBAction func receiveButton(_ sender: Any) {
        if let p = discoveredPeripheral {
            p.readValue(for: pReader!)
        }
    
    }
    @IBAction func ConnectPress(_ sender: Any) {
        if let p = discoveredPeripheral {
            centralManager.cancelPeripheralConnection(p)
        }
    }
    @IBAction func ScanPressed(_ sender: Any) {
        if centralManager.state == .poweredOn {
            centralManager.scanForPeripherals(withServices: [CBUUID(string: "e1511a45-f3db-44c0-82b8-6c880790d1f1")], options: nil)
            print(" Scanning for devices...");
        }
    }
    @IBAction func speedTestPush(_ sender: Any) {
        if let peripheral = discoveredPeripheral {
            let hello = Array(String(repeating:"abcdefghij", count:410).prefix(4*1024).utf8);
            
            startInstant = clock?.now
            let mtu = peripheral.maximumWriteValueLength(for: CBCharacteristicWriteType.withoutResponse)
            let cid = [UInt8](_:[0xEE, 0xEE, 0xEE, 0xEE]);
            let cmd = [UInt8](_:[UInt8(0x80)]);
            let sz = [UInt8](_:[UInt8(hello.count >> 8), UInt8(hello.count & 0xff)]);
            let header = cid + cmd + sz;
            
            let data = Data(_:header + hello[0..<mtu-7]);
            peripheral.writeValue(data, for: pWriter!, type: .withResponse)
            sends += 1;
            var ptr = mtu-7;
            var seq = UInt8(0);
            while (ptr < hello.count) {
                let header = cid + [UInt8](_:[seq]);
                let len = min(mtu-5, hello[ptr..<hello.count].count);
                let data = Data(_:header + hello[ptr..<ptr+len]);
                print("ptr \(ptr), len \(len)");
                peripheral.writeValue(data, for: pWriter!, type: .withResponse)
                sends += 1;
                ptr += len;
                seq += 1;
                if seq > 127 {
                    print("oh no \(ptr)")
                    break;
                }
            }
        }
    }
    
    //Calls this function when the tap is recognized.
    @objc func dismissKeyboard() {
        //Causes the view (or one of its embedded text fields) to resign the first responder status.
        view.endEditing(true)
    }

    @IBAction func infoPush(_ sender: Any) {
        if let peripheral = discoveredPeripheral{
            let cid = [UInt8](_:[0xEE, 0xEE, 0xEE, 0xEE]);
            let cmd = [UInt8](_:[UInt8(0x80)]);
            let sz = [UInt8](_:[0, 1]);
            let header = cid + cmd + sz;
            let packet = header + [Character("i").asciiValue!];
            var report = Data(count: 64);
            for (i, c) in packet.enumerated() {
                report[i] = c;
            }
            print("trying to send \(report)");
            dump(report[..<8])
            peripheral.writeValue(report, for: pWriter!, type: .withResponse)
            waitingForInfo = true
        }
    }
}
