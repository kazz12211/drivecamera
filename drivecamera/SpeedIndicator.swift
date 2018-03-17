//
//  SpeedIndicator.swift
//  drivecamera
//
//  Created by Kazuo Tsubaki on 2018/03/11.
//  Copyright © 2018年 Kazuo Tsubaki. All rights reserved.
//

import Foundation

class SpeedIndicator : NSObject {
    
    var koshian: Koshian!
    private static var GreenLED = KoshianConstants.DigitalIO5
    private static var YellowLED = KoshianConstants.DigitalIO3
    private static var RedLED = KoshianConstants.DigitalIO1
    var yellowValue: Bool = true
    var redValue: Bool = true
    static let SpeedIndicatorReady = Notification.Name("SpeedIndicatorReady")
    static let SpeedIndicatorNotReady = Notification.Name("SpeedIndicatorNotReady")
    static let SpeedIndicatorReadyToConnect = Notification.Name("SpeedIndicatorReadyToConnect")
    static let SpeedRangeSlow = UInt(0)
    static let SpeedRangeNormal = UInt(1)
    static let SpeedRangeHigh = UInt(2)
    static let SpeedRangeVeryHigh = UInt(3)
    
    var connected: Bool = false
    var speedRange: UInt = SpeedRangeSlow
    var blinkTimer: Timer! = nil

    init(deviceName: String) {
        super.init()
        koshian = Koshian(localName: deviceName)
        NotificationCenter.default.addObserver(self, selector: #selector(koshianPoweredOn(notif:)), name: KoshianConstants.KoshianPoweredOn, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(koshianConnected(notif:)), name: KoshianConstants.KoshianConnected, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(koshianDisconnected(notif:)), name: KoshianConstants.KoshianDisconnected, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(koshianTimeout(notif:)), name: KoshianConstants.KoshianConnectionTimeout, object: nil)
    }
    
    func connect() {
        if !koshian.connected {
            koshian.connect()
        }
    }
    
    func disconnect() {
        if koshian.connected {
            digitalWrite(pin: SpeedIndicator.GreenLED, value: KoshianConstants.LOW)
            koshian.disconnect()
        }
    }
    
    func isReady() -> Bool {
        return koshian.connected
    }
    
    func isConnected() -> Bool {
        return connected;
    }
    
    private func setupPinMode() {
        var result:Int
        result = koshian.pinMode(pin: SpeedIndicator.GreenLED, mode: KoshianConstants.PinModeOutput)
        if result == KoshianResult.Failure {}
        result = koshian.pinMode(pin: SpeedIndicator.YellowLED, mode: KoshianConstants.PinModeOutput)
        if result == KoshianResult.Failure {}
        result = koshian.pinMode(pin: SpeedIndicator.RedLED, mode: KoshianConstants.PinModeOutput)
        if result == KoshianResult.Failure {}
    }
    
    @objc func koshianPoweredOn(notif: Notification) {
        NotificationCenter.default.post(name: SpeedIndicator.SpeedIndicatorReadyToConnect, object:self)
    }
    
    @objc func koshianConnected(notif: Notification) {
        connected = true
        
        setupPinMode()
        
        digitalWrite(pin: SpeedIndicator.GreenLED, value: KoshianConstants.HIGH)
        
        NotificationCenter.default.post(name: SpeedIndicator.SpeedIndicatorReady, object: self)
        
    }
    
    private func startTimer() {
        if blinkTimer == nil {
            blinkTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true, block: { (timer) in
                if self.speedRange == SpeedIndicator.SpeedRangeNormal {
                    self.digitalWrite(pin: SpeedIndicator.YellowLED, value: self.yellowValue ? KoshianConstants.HIGH : KoshianConstants.LOW)
                    self.yellowValue = !self.yellowValue
                } else if self.speedRange == SpeedIndicator.SpeedRangeHigh {
                    self.digitalWrite(pin: SpeedIndicator.RedLED, value: self.redValue ? KoshianConstants.HIGH : KoshianConstants.LOW)
                    self.redValue = !self.redValue
                } else if self.speedRange == SpeedIndicator.SpeedRangeVeryHigh {
                    self.digitalWrite(pin: SpeedIndicator.YellowLED, value: self.redValue ? KoshianConstants.LOW : KoshianConstants.HIGH)
                    self.digitalWrite(pin: SpeedIndicator.RedLED, value: self.redValue ? KoshianConstants.HIGH : KoshianConstants.LOW)
                    self.redValue = !self.redValue
                }
            })
        }
        blinkTimer.fire()
    }
    
    private func stopTimer() {
        if blinkTimer != nil {
            if blinkTimer.isValid {
                blinkTimer.invalidate()
            }
            blinkTimer = nil
        }
    }
    
    @objc func koshianDisconnected(notif: Notification) {
        connected = false
        NotificationCenter.default.post(name: SpeedIndicator.SpeedIndicatorNotReady, object: self)
    }
    
    private func digitalWrite(pin: UInt8, value: UInt8) {
        let result = koshian.digitalWrite(pin: pin, value: value)
        if result == KoshianResult.Failure {
            // no error reporting
        }
    }
    
    @objc func koshianTimeout(notif: Notification) {
        connected = false
        NotificationCenter.default.post(name: SpeedIndicator.SpeedIndicatorNotReady, object: self)
    }
    
    private func speedToRange(_ speed: Double) -> UInt {
        if speed >= Constants.SpeedNormal && speed < Constants.SpeedHigh {
            return SpeedIndicator.SpeedRangeNormal
        } else if speed >= Constants.SpeedHigh && speed < Constants.SpeedVeryHigh {
            return SpeedIndicator.SpeedRangeHigh
        } else if speed >= Constants.SpeedVeryHigh {
            return SpeedIndicator.SpeedRangeVeryHigh
        } else {
            return SpeedIndicator.SpeedRangeSlow
        }
    }
    
    func showSpeed(_ speed: Double) -> Void {
        if koshian.connected {
            let range = speedToRange(speed)
            if speedRange != range {
                showSpeedRange(range)
            }
        }
    }
    
    private func showSpeedRange(_ range: UInt) {
        speedRange = range
        
        digitalWrite(pin: SpeedIndicator.YellowLED, value: KoshianConstants.LOW)
        digitalWrite(pin: SpeedIndicator.RedLED, value: KoshianConstants.LOW)
        yellowValue = true
        redValue = true

         if speedRange == SpeedIndicator.SpeedRangeSlow {
            stopTimer()
         } else {
            startTimer()
        }
    }
}
