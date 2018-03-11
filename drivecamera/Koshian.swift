//
//  Koshian.swift
//
//  Created by Kazuo Tsubaki on 2018/03/09.
//  Copyright © 2018年 Kazuo Tsubaki. All rights reserved.
//

import Foundation
import CoreBluetooth

struct KoshianConstants {
    // Digital I/0
    static let HIGH = UInt8(1)
    static let LOW = UInt8(0)
    
    // Pin Mode
    static let PinModeInput = UInt8(0)
    static let PinModeOutput = UInt8(1)
    static let PinModeNoPulls = UInt8(0)
    static let PinModePullup = UInt8(1)
    
    // Digital IO Pin
    static let DigitalIO0 = UInt8(0)
    static let DigitalIO1 = UInt8(1)
    static let DigitalIO2 = UInt8(2)
    static let DigitalIO3 = UInt8(3)
    static let DigitalIO4 = UInt8(4)
    static let DigitalIO5 = UInt8(5)
    static let DigitalIO6 = UInt8(6)
    static let DigitalIO7 = UInt8(7)
    static let S1 = DigitalIO0
    static let PIO1 = DigitalIO1
    static let PIO2 = DigitalIO2
    static let PIO3 = DigitalIO3
    static let PIO4 = DigitalIO4
    
    static let KoshianConnected = Notification.Name("KoshianConnected")
    static let KoshianDisconnected = Notification.Name("KoshianDisconnected")
    static let KoshianConnectionTimeout = Notification.Name("KoshianConnectionTimeout")
}

struct KoshianResult {
    static let Success = 1
    static let Failure = 0
}

class Koshian: NSObject {
    
    private static var _batteryServiceUUID: CBUUID!
    private static var _levelServiceUUID: CBUUID!
    private static var _powerStateUUID: CBUUID!
    private static var _serviceUUID: CBUUID!
    private static var _pioSettingUUID: CBUUID!
    private static var _pioPullupUUID: CBUUID!
    private static var _pioOutputUUID: CBUUID!
    
    var pioSetting: UInt8 = 0
    var pioOutput: UInt8 = 0
    var pioPullup: UInt8 = 0
    
    var peripheral: CBPeripheral!
    var services: [CBService] = []
    var characteristics = [String: [CBCharacteristic]]()
    
    var centralManager: CBCentralManager!
    var localName: String!
    var connected: Bool = false
    
    var connectionTimer: Timer!
    
    init(localName: String) {
        super.init()
        pioSetting = 0
        pioOutput = 0
        pioPullup = 0
        centralManager = CBCentralManager(delegate: self, queue: nil, options:nil)
        self.localName = localName
    }
    
    func disconnect() {
        if connected {
            print("Disconnecting Koshian")
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }
    
    func connect() {
        if !connected {
            print("Scanning Koshian")
            connectionTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false, block: { (timer) in
                if self.connected == false {
                    print("Connection Timeout")
                    NotificationCenter.default.post(name: KoshianConstants.KoshianConnectionTimeout, object: self)
                    self.centralManager.stopScan()
                }
            })
            centralManager.scanForPeripherals(withServices: nil, options: nil)
        }
    }
    
    func createUUIDFromString(_ string: String!) -> CBUUID! {
        if string != nil {
            let uuid = CBUUID(string: string)
            return uuid
        }
        return nil
    }
    
    // from KNSKoshianPeripheralImpl.m
    
    func batteryServiceUUID() -> CBUUID {
        if Koshian._batteryServiceUUID == nil {
            Koshian._batteryServiceUUID = createUUIDFromString("180F")
        }
        return Koshian._batteryServiceUUID
    }
    
    func levelServiceUUID() -> CBUUID {
        if Koshian._levelServiceUUID == nil {
            Koshian._levelServiceUUID = createUUIDFromString("2A19")
        }
        return Koshian._levelServiceUUID
    }
    
    func powerStateUUID() -> CBUUID {
        if Koshian._powerStateUUID == nil {
            Koshian._powerStateUUID = createUUIDFromString("2A1B")
        }
        return Koshian._powerStateUUID
    }
    
    func serviceUUID() -> CBUUID {
        if Koshian._serviceUUID == nil {
            Koshian._serviceUUID = createUUIDFromString("229BFF00-03FB-40DA-98A7-B0DEF65C2D4B")
        }
        return Koshian._serviceUUID
    }
    
    func pioSettingUUID() -> CBUUID {
        if Koshian._pioSettingUUID == nil {
            Koshian._pioSettingUUID = createUUIDFromString("229B3000-03FB-40DA-98A7-B0DEF65C2D4B")
        }
        return Koshian._pioSettingUUID
    }
    
    func pioPullupUUID() -> CBUUID {
        if Koshian._pioPullupUUID == nil {
            Koshian._pioPullupUUID = createUUIDFromString("229B3001-03FB-40DA-98A7-B0DEF65C2D4B")
        }
        return Koshian._pioPullupUUID
    }
    
    func pioOutputUUID() -> CBUUID {
        if Koshian._pioOutputUUID == nil {
            Koshian._pioOutputUUID = createUUIDFromString("229B3002-03FB-40DA-98A7-B0DEF65C2D4B")
        }
        return Koshian._pioOutputUUID
    }
    
    // from KNSPeripheralBaseImpl.m
    
    func writeUInt8(_ value: UInt8, toCharacteristic: CBCharacteristic) -> Void {
        var i = value
        let data = Data(buffer: UnsafeBufferPointer(start: &i, count: MemoryLayout<UInt8>.size))
        peripheral.writeValue(data, for:toCharacteristic, type: CBCharacteristicWriteType.withoutResponse)
    }
    
    func lookupCharacteristic(serviceUUID: CBUUID, characteristicUUID: CBUUID) -> CBCharacteristic! {
        guard let chars = characteristics[serviceUUID.uuidString] else {
            return nil
        }
        for char in chars {
            let c = char as CBCharacteristic
            if c.uuid.isEqual(characteristicUUID) {
                return c
            }
        }
        return nil
    }
    
    func pinMode(pin: UInt8, mode: UInt8) -> Int {
        if pin >= KoshianConstants.DigitalIO0 && pin <= KoshianConstants.DigitalIO7 && (mode == KoshianConstants.PinModeInput || mode == KoshianConstants.PinModeOutput) {
            if mode == KoshianConstants.PinModeOutput {
                pioSetting |= 0x01 << pin
            } else {
                pioSetting &= ~(0x01 << pin) & 0xFF
            }
            let c = lookupCharacteristic(serviceUUID: serviceUUID(), characteristicUUID: pioSettingUUID())
            if c != nil {
                writeUInt8(pioSetting, toCharacteristic: c!)
                return KoshianResult.Success
            } else {
                return KoshianResult.Failure
            }
        }
        return KoshianResult.Failure
    }
    
    func pinModeAll(mode: UInt8) -> Int {
        if mode >= 0x00 && mode <= 0xFF {
            pioSetting = mode
            let c = lookupCharacteristic(serviceUUID: serviceUUID(), characteristicUUID: pioSettingUUID())
            if c != nil {
                writeUInt8(pioSetting, toCharacteristic: c!)
                return KoshianResult.Success
            } else {
                return KoshianResult.Failure
            }
        }
        return KoshianResult.Failure
    }
    
    func pinPullup(pin: UInt8, mode: UInt8) -> Int {
        if pin >= KoshianConstants.DigitalIO0 && pin <= KoshianConstants.DigitalIO7 && (mode == KoshianConstants.PinModeNoPulls || mode == KoshianConstants.PinModePullup) {
            if mode == KoshianConstants.PinModePullup {
                pioPullup |= 0x01 << pin
            } else {
                pioPullup &= ~(0x01 << pin) & 0xFF
            }
            let c = lookupCharacteristic(serviceUUID: serviceUUID(), characteristicUUID: pioPullupUUID())
            if c != nil {
                writeUInt8(pioPullup, toCharacteristic: c!)
                return KoshianResult.Success
            } else {
                return KoshianResult.Failure
            }
        }
        return KoshianResult.Failure
    }
    
    func pinPullupAll(mode: UInt8) -> Int {
        if mode >= 0x00 && mode <= 0xFF {
            pioPullup = mode
            let c = lookupCharacteristic(serviceUUID: serviceUUID(), characteristicUUID: pioPullupUUID())
            if c != nil {
                writeUInt8(pioPullup, toCharacteristic: c!)
                return KoshianResult.Success
            } else {
                return KoshianResult.Failure
            }
        }
        return KoshianResult.Failure
    }
    
    func digitalWrite(pin: UInt8, value:UInt8) -> Int {
        if pin >= KoshianConstants.DigitalIO0 && pin <= KoshianConstants.DigitalIO7 && (value == KoshianConstants.HIGH || value == KoshianConstants.LOW) {
            if value == KoshianConstants.HIGH {
                pioOutput |= 0x01 << pin
            } else {
                pioOutput &= ~(0x01 << pin) & 0xFF
            }
            let c = lookupCharacteristic(serviceUUID: serviceUUID(), characteristicUUID: pioOutputUUID())
            if c != nil {
                writeUInt8(pioOutput, toCharacteristic: c!)
                return KoshianResult.Success
            } else {
                return KoshianResult.Failure
            }
        }
        return KoshianResult.Failure
    }
    
    func digitalWriteAll(value: UInt8) -> Int {
        if value >= 0x00 && value <= 0xFF {
            pioOutput = value
            let c = lookupCharacteristic(serviceUUID: serviceUUID(), characteristicUUID: pioOutputUUID())
            if c != nil {
                writeUInt8(pioOutput, toCharacteristic: c!)
                return KoshianResult.Success
            } else {
                return KoshianResult.Failure
            }
        }
        return KoshianResult.Failure
    }
}

extension Koshian: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("powerOn")
        default:
            print("central.state = \(central.state)")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Koshian disconnected")
        self.peripheral = nil
        self.services.removeAll()
        self.characteristics.removeAll()
        self.pioOutput = 0
        self.pioSetting = 0
        self.pioPullup = 0
        self.connected = false
        NotificationCenter.default.post(name: KoshianConstants.KoshianDisconnected, object: self)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Koshian connected")
        self.peripheral = peripheral
        self.peripheral.delegate = self
        self.services.removeAll()
        self.peripheral.discoverServices(nil)
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let name = advertisementData["kCBAdvDataLocalName"] as? String
        if name == localName {
            central.stopScan()
            print("\(localName) found")
            self.peripheral = peripheral
            print("Connecting \(localName)")
            self.centralManager.connect(self.peripheral, options: nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Failed to connect to Koshian")
    }
    
}

extension Koshian: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for service in peripheral.services! {
            print("Found service \(service.uuid)")
            services.append(service)
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    private func notifyWhenReady() {
        for s in services {
            let chars = characteristics[s.uuid.uuidString]
            if chars?.count == 0 {
                return
            }
        }
        connected = true
        if connectionTimer != nil {
            connectionTimer.invalidate()
            connectionTimer = nil
        }
        NotificationCenter.default.post(name: KoshianConstants.KoshianConnected, object: self)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        print("Found characteristic \(String(describing: service.characteristics)) for service \(String(describing: service))")
        characteristics[service.uuid.uuidString] = service.characteristics
        print("Saved characteristics \(String(describing: self.characteristics))")
        notifyWhenReady()
    }
    
}

