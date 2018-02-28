//
//  ViewController.swift
//  drivecamera
//
//  Created by Kazuo Tsubaki on 2018/02/25.
//  Copyright © 2018年 Kazuo Tsubaki. All rights reserved.
//

import UIKit
import CoreLocation
import CoreBluetooth
import CoreMotion
import AVFoundation

class ViewController: UIViewController {

    @IBOutlet weak var meterPanel: UIView!
    @IBOutlet weak var previewView: UIView!
    @IBOutlet weak var gsensorSegmentedController: UISegmentedControl!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var speedLabel: UILabel!
    @IBOutlet weak var autoStartSwitch: UISwitch!
    @IBOutlet weak var altitudeLabel: UILabel!
    @IBOutlet weak var latitudeLabel: UILabel!
    @IBOutlet weak var longitudeLabel: UILabel!
    @IBOutlet weak var batteryLevelLabel: UILabel!
    @IBOutlet weak var qualitySegmentedControl: UISegmentedControl!
    @IBOutlet weak var audioSwitch: UISwitch!
    @IBOutlet weak var freeStorageLabel: UILabel!
    
    let locationManager = CLLocationManager()
    let motionManager = CMMotionManager()
    var centralManager: CBCentralManager!
    
    var speedmeterPeripheral: CBPeripheral!
    var speedService: CBService!
    var speedCharacteristic: CBCharacteristic!
    
    var captureSession: AVCaptureSession = AVCaptureSession()
    var videoDevice: AVCaptureDevice!
    var audioDevice: AVCaptureDevice!
    var videoInput: AVCaptureDeviceInput!
    var audioInput: AVCaptureDeviceInput!
    var fileOutput: AVCaptureMovieFileOutput!
    var filePath: String!
    var recordingInProgress: Bool = false
    var gsensibility: Double = 2.8
    var autoStartEnabled: Bool = true;
    var autoStopEnabled: Bool = true;
    var videoQualities: [AVCaptureSession.Preset] = [.hd1280x720, .hd1920x1080]
    var videoQuality: Int = 0
    var previewLayer: AVCaptureVideoPreviewLayer!
    var timestampLayer: CATextLayer!
    var timestampFormatter: DateFormatter!
    var filenameFormatter: DateFormatter!
    var speeds: [Double]!
    var recordAudio: Bool = true
    
    var testSpeed:Double = 0
    
    struct Constants {
        static let GSensorSensibilityKey = "GSensor-Sensibility"
        static let AutoStartEnabledKey = "AutoStartEnabled"
        static let AutoStopEnabledKey = "AutoStopEnabled"
        static let VideoQualityKey = "VideoQuality"
        static let GSensorStrong = 4.0
        static let GSensorMedium = 2.8
        static let GSensorWeak = 1.8
        static let SpeedVerySlow = 5.0
        static let SpeedSlow = 50.0
        static let SpeedNormal = 70.0
        static let SpeedHigh = 100.0
        static let SpeedVeryHigh = 110.0
        static let SpeedVerySlowKey = "SpeedVerySlow"
        static let SpeedSlowKey = "SpeedSlow"
        static let SpeedNormalKey = "SpeedNormal"
        static let SpeedHighKey = "SpeedHigh"
        static let SpeedVeryHighKey = "SpeedVeryHigh"
        static let RecordAudioKey = "RecordAudio"
    }
    

    // カメラプレビューの設定
    private func setupPreviewLayer() {
        previewLayer = AVCaptureVideoPreviewLayer(session:captureSession)
        previewLayer.backgroundColor = UIColor.black.cgColor
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        
        previewLayer.frame = previewView.bounds
        previewView.layer.addSublayer(previewLayer)
        
        
        let previewLayerConnection: AVCaptureConnection  = previewLayer.connection!
        previewLayerConnection.videoOrientation = .landscapeRight
        
        let composition = AVMutableVideoComposition()
        composition.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: previewLayer, in: previewView.layer)
        
    }
    
    private func setupTimestampLayer() {
        timestampLayer = CATextLayer()
        timestampLayer.frame = CGRect(x: 4, y: 4, width: 130, height: 20)
        timestampLayer.foregroundColor = UIColor.green.cgColor
        timestampLayer.fontSize = 14.0
        timestampLayer.allowsEdgeAntialiasing = true
        timestampLayer.string = timestampFormatter.string(from: Date())
        previewView.layer.addSublayer(timestampLayer)
        let timer = Timer.scheduledTimer(timeInterval: 1/5, target: self, selector: #selector(ViewController.updateClock), userInfo: nil, repeats: true)
        timer.fire()
   }
    
    @objc func updateClock() {
        timestampLayer.string = timestampFormatter.string(from: Date())
    }
    // ビデオキャプチャーの設定
    private func setupCaptureSession() {
        captureSession.sessionPreset = videoQualities[videoQuality]
    }
    
    // 入力デバイスの設定
    private func setupCaptureDevice() {
        let discoverySession = AVCaptureDevice.DiscoverySession.init(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera], mediaType: AVMediaType.video, position: AVCaptureDevice.Position.back)
        let devices = discoverySession.devices
        /*
        for device in devices {
            if device.position == AVCaptureDevice.Position.back {
                videoDevice = device
            }
        }
         */
        
        videoDevice = devices.first
        videoDevice.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
        
        do {
            videoInput = try AVCaptureDeviceInput(device:videoDevice)
            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
            }
            
        } catch {
            print("cannot setup capture device", error)
        }
        
        if recordAudio {
            addAudioInput()
        }
    }
    
    private func removeAudioInput() {
        captureSession.removeInput(audioInput)
        audioDevice = nil
    }
    
    private func addAudioInput() {
        audioDevice = AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInMicrophone, for: AVMediaType.audio, position: AVCaptureDevice.Position.unspecified)
        
        do {
            audioInput = try AVCaptureDeviceInput(device: audioDevice)
            if captureSession.canAddInput(audioInput) {
                captureSession.addInput(audioInput)
            }

        } catch {
            print("cannot add audio input device")
        }
    }
    // 動画録画先の設定
    private func setupVideoOutput() {
        fileOutput = AVCaptureMovieFileOutput()
        if captureSession.canAddOutput(fileOutput) {
            captureSession.addOutput(fileOutput)
        }
        // 保存される動画の向きを設定
        var videoConnection: AVCaptureConnection!
            
        for connection:AVCaptureConnection in fileOutput.connections {
            for port:AVCaptureInput.Port in connection.inputPorts {
                if port.mediaType == AVMediaType.video {
                    videoConnection = connection;
                }
            }
        }
            
        if videoConnection.isVideoOrientationSupported {
            videoConnection.videoOrientation = AVCaptureVideoOrientation.landscapeRight
        }
        
        /*
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        let queue = DispatchQueue(label: "drivecamera")
        videoOutput.setSampleBufferDelegate(self, queue: queue)
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
         */
    }
    
    // キャプチャーセッションの開始
    private func startCaptureSession() {
        captureSession.startRunning()
    }
    
    // キャプチャーセッションの終了
    private func stopCaptureSession() {
        captureSession.stopRunning()
    }
    // 位置情報サービスを開始
    private func setupLocationManager() {
        locationManager.delegate = self
        let status = CLLocationManager.authorizationStatus()
        if status == CLAuthorizationStatus.notDetermined {
            locationManager.requestAlwaysAuthorization()
        }
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.startUpdatingLocation()
    }

    // Bluetoothセントラルの開始
    private func setupBluetooth() {
        centralManager = CBCentralManager(delegate:self, queue:nil, options:nil)
    }

    // 加速度センサーの利用開始
    private func setupMotionManager() {
        if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = 1 / 60
            motionManager.showsDeviceMovementDisplay = true
            motionManager.startAccelerometerUpdates(to: OperationQueue.current!, withHandler: {(accelerationData, error) in
                if let e = error {
                    print(e.localizedDescription)
                }
                guard let data = accelerationData else {
                    return
                }
                if fabs(data.acceleration.y) > self.gsensibility || fabs(data.acceleration.z) > self.gsensibility {
                    print("".appendingFormat("x = %.4f, y = %.4f, z = %.4f", data.acceleration.x, data.acceleration.y, data.acceleration.z))
                    if !self.recordingInProgress {
                        self.startRecording()
                    }
                }
            });
        }
    }
    
    private func setupBatteryLevelMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        showBatteryLevel(batteryLevel: UIDevice.current.batteryLevel)
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.batteryLevelChanged(notification:)), name: NSNotification.Name.UIDeviceBatteryLevelDidChange, object: nil)
    }
    // ボタンの状態変更
    private func updateButtons() {
        qualitySegmentedControl.isEnabled = !recordingInProgress
        autoStartSwitch.isEnabled = !recordingInProgress
        qualitySegmentedControl.isEnabled = !recordingInProgress
        audioSwitch.isEnabled = !recordingInProgress
        
        if recordingInProgress {
            UIView.animateKeyframes(withDuration: 1.5, delay: 0.0, options: [.repeat ,.allowUserInteraction], animations: {
                self.recordButton.alpha = 0.1
            }, completion: nil)
        } else {
            recordButton.layer.removeAllAnimations()
            recordButton.alpha = 1.0
        }
    }
    
    // 録画停止
    private func stopRecording() {
        fileOutput.stopRecording()
        recordingInProgress = false
        updateButtons()
    }
    
    // 録画開始
    private func startRecording() {
        let documentPath = NSHomeDirectory() + "/Documents/"
        filePath = documentPath + filenameFormatter.string(from: Date()) + ".mp4"
        let fileURL: URL = URL(fileURLWithPath: filePath)
        recordingInProgress = true
        fileOutput.startRecording(to: fileURL, recordingDelegate: self)
        updateButtons()
    }
    
    // 動画の録画・停止アクション
    @IBAction func recordOrStop(sender: AnyObject) {
        if recordingInProgress {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    // Gセンサーの感度設定アクション
    @IBAction func gsensitibityChanged(sender: AnyObject) {
        switch gsensorSegmentedController.selectedSegmentIndex {
        case 0:
            gsensibility = Constants.GSensorStrong
            break
        case 1:
            gsensibility = Constants.GSensorMedium
            break
        case 2:
            gsensibility = Constants.GSensorWeak
            break;
        default:
            gsensibility = Constants.GSensorMedium
        }
        
        saveUserDefaults()
    }
    
    // 動画品質の設定
    @IBAction func qualityChanged(_ sender: Any) {
        stopCaptureSession()

        videoQuality = 0
        if qualitySegmentedControl.selectedSegmentIndex == 0 {
            captureSession.sessionPreset = videoQualities[qualitySegmentedControl.selectedSegmentIndex]
            videoQuality = qualitySegmentedControl.selectedSegmentIndex
        } else {
            captureSession.sessionPreset = videoQualities[qualitySegmentedControl.selectedSegmentIndex]
            videoQuality = qualitySegmentedControl.selectedSegmentIndex
        }

        startCaptureSession()
        
        saveUserDefaults()
    }
    // 自動録画設定アクション
    @IBAction func changeAutoStart(_ sender: Any) {
        autoStartEnabled = autoStartSwitch.isOn
        autoStopEnabled = autoStartEnabled
        
        saveUserDefaults()
    }
    
    // 音声の取り込みのオンオフ
    @IBAction func audioSwitchChanged(_ sender: Any) {
        recordAudio = audioSwitch.isOn
        
        stopCaptureSession()
        
        if !recordAudio {
            removeAudioInput()
        } else {
            addAudioInput()
        }
        
        startCaptureSession()

        saveUserDefaults()
    }
    
    @objc func video(videoPath: NSString, didFinishSavingWithError error: NSError?, contextInfo info: AnyObject) {
        if error != nil {
            print("video saving error")
        } else {
            print("video saving success", videoPath)
            do {
                try FileManager.default.removeItem(atPath: videoPath as String)
                print("video file removed", videoPath)
            } catch {
             
            }
        }
    }
    
    @objc func batteryLevelChanged(notification: NSNotification)  {
        showBatteryLevel(batteryLevel: UIDevice.current.batteryLevel)
    }
    
    private func showBatteryLevel(batteryLevel: Float) {
        batteryLevelLabel.text = "".appendingFormat("%.0f%%", batteryLevel * 100)
    }
    
    private func showBleStatus(str:String) {
        statusLabel.text = str
    }
    
    private func calculateFreeStorageSize() -> NSNumber {
        let documentDirPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        if let sysAttributes = try? FileManager.default.attributesOfFileSystem(forPath: documentDirPath.last!) {
            for val in sysAttributes {
                print(val)
            }
            if let freeStorageSize = sysAttributes[FileAttributeKey.systemFreeSize] as? NSNumber {
                let freeStorageGigaBytes = freeStorageSize.doubleValue / Double(1024 * 1024 * 1024)
                return NSNumber(value: round(freeStorageGigaBytes))
            }
        }
        return NSNumber(value:0.0)
    }
    
    private func showFreeStorageSize() {
        let freeSize = calculateFreeStorageSize()
        freeStorageLabel.text = "".appendingFormat("%.0fGB", freeSize.doubleValue)
    }
    
    private func reflectUserDefaults() {
        let defaults = UserDefaults.standard
        gsensibility = defaults.double(forKey: Constants.GSensorSensibilityKey)
        if(gsensibility == Constants.GSensorWeak) {
            gsensorSegmentedController.selectedSegmentIndex = 2
        } else if(gsensibility == Constants.GSensorMedium) {
            gsensorSegmentedController.selectedSegmentIndex = 1
        } else if(gsensibility == Constants.GSensorStrong) {
            gsensorSegmentedController.selectedSegmentIndex = 0
        }
        
        autoStartEnabled = defaults.bool(forKey: Constants.AutoStartEnabledKey)
        autoStartSwitch.isOn = autoStartEnabled

        autoStopEnabled = defaults.bool(forKey: Constants.AutoStopEnabledKey)
        
        qualitySegmentedControl.selectedSegmentIndex = defaults.integer(forKey: Constants.VideoQualityKey)
        videoQuality = defaults.integer(forKey: Constants.VideoQualityKey)
        captureSession.sessionPreset = videoQualities[videoQuality]
        
        speeds = [Constants.SpeedVerySlow, Constants.SpeedSlow, Constants.SpeedNormal, Constants.SpeedHigh, Constants.SpeedVeryHigh]
        if defaults.double(forKey: Constants.SpeedVerySlowKey) != 0 {
            speeds[0] = defaults.double(forKey: Constants.SpeedVerySlowKey)
        }
        if defaults.double(forKey: Constants.SpeedSlowKey) != 0 {
            speeds[1] = defaults.double(forKey: Constants.SpeedSlowKey)
        }
        if defaults.double(forKey: Constants.SpeedNormalKey) != 0 {
            speeds[1] = defaults.double(forKey: Constants.SpeedNormalKey)
        }
        if defaults.double(forKey: Constants.SpeedHighKey) != 0 {
            speeds[1] = defaults.double(forKey: Constants.SpeedHighKey)
        }
        if defaults.double(forKey: Constants.SpeedVeryHighKey) != 0 {
            speeds[1] = defaults.double(forKey: Constants.SpeedVeryHighKey)
        }
        
        recordAudio = defaults.bool(forKey: Constants.RecordAudioKey)
        audioSwitch.isOn = recordAudio
    }
    
    private func saveUserDefaults() {
        let defaults = UserDefaults.standard
        defaults.set(gsensibility, forKey: Constants.GSensorSensibilityKey)
        defaults.set(autoStartEnabled, forKey: Constants.AutoStartEnabledKey)
        defaults.set(autoStopEnabled, forKey: Constants.AutoStopEnabledKey)
        defaults.set(videoQuality, forKey: Constants.VideoQualityKey)
        defaults.set(speeds[0], forKey: Constants.SpeedVerySlowKey)
        defaults.set(speeds[1], forKey: Constants.SpeedSlowKey)
        defaults.set(speeds[2], forKey: Constants.SpeedNormalKey)
        defaults.set(speeds[3], forKey: Constants.SpeedHighKey)
        defaults.set(speeds[4], forKey: Constants.SpeedVeryHighKey)
        defaults.set(recordAudio, forKey: Constants.RecordAudioKey)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        speedLabel.text = "0"
        gsensorSegmentedController.selectedSegmentIndex = 1
        gsensibility = Constants.GSensorMedium
        autoStartSwitch.isOn = true
        recordButton.layer.masksToBounds = true
        recordButton.layer.cornerRadius = 24.0
        timestampFormatter = DateFormatter()
        timestampFormatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        filenameFormatter = DateFormatter()
        filenameFormatter.dateFormat = "yyyy-mm-dd_HH:mm:ss"
        recordButton.backgroundColor = UIColor.red
        
        
        reflectUserDefaults()

        showBleStatus(str: "")
        showFreeStorageSize()
        setupLocationManager()
        setupBluetooth()
        setupMotionManager()
        setupCaptureSession()
        setupCaptureDevice()
        setupVideoOutput()
        setupPreviewLayer()
        setupTimestampLayer()
        setupBatteryLevelMonitoring()
        updateButtons()
        startCaptureSession()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


    func sendSpeed(speed:CLLocationSpeed) {
        speedLabel.text = "".appendingFormat("%.0f", speed)
        
        if speed < speeds[1] {
            meterPanel.backgroundColor = UIColor.black
        } else if speed < speeds[2] {
            meterPanel.backgroundColor = UIColor.blue
        } else if speed < speeds[3] {
            meterPanel.backgroundColor = UIColor.magenta
        } else {
            meterPanel.backgroundColor = UIColor.red
        }
        if speed >= speeds[4] {
            startBlinking()
        } else {
            stopBlinking()
        }
        // BLEペリフェラルデバイスにスピードを送信
        if speedCharacteristic != nil {
            let str = "".appendingFormat("{speed:%.0f}", speed)
            let data = str.data(using: String.Encoding.utf8)!
            speedmeterPeripheral.writeValue(data, for: speedCharacteristic, type: CBCharacteristicWriteType.withResponse)
        }
    }

    private func startBlinking() {
        UIView.animateKeyframes(withDuration: 0.6, delay: 0.0, options: UIViewKeyframeAnimationOptions.repeat, animations: {
            self.meterPanel.alpha = 0.2
        }, completion: nil)
    }
    
    private func stopBlinking() {
        meterPanel.layer.removeAllAnimations()
        meterPanel.alpha = 1.0
    }
}

extension ViewController: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        print("capture finished", outputFileURL)
        UISaveVideoAtPathToSavedPhotosAlbum(outputFileURL.path, self, #selector(ViewController.video(videoPath:didFinishSavingWithError:contextInfo:)), nil)
    }
    
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        print("delegate called")
    }
    
}

extension ViewController: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let myLocation = locations.last! as CLLocation
        var speed = myLocation.speed
        let altitude = myLocation.altitude
        let latitude = myLocation.coordinate.latitude
        let longitude = myLocation.coordinate.longitude
        
        altitudeLabel.text = "".appendingFormat("%.0f m", altitude)
        latitudeLabel.text = "".appendingFormat("%.5f", latitude)
        longitudeLabel.text = "".appendingFormat("%.5f", longitude)
        
        if speed < 0 {
            speed = 0
        }
        speed *= 3.6
        
        sendSpeed(speed:speed)
        /*
         sendSpeed(speed:testSpeed)
         if testSpeed > 130 {
            testSpeed = 60
         } else {
            testSpeed += 10.0
         }
         */
        // 時速５キロを超えたら録画を自動的に開始する
        if(speed > speeds[0] && !recordingInProgress && autoStartEnabled) {
            startRecording()
        }
    }

}

extension ViewController: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            showBleStatus(str: "Scanning")
            centralManager.scanForPeripherals(withServices: nil, options: nil)
        default:
            print(central.state)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let localName = advertisementData["kCBAdvDataLocalName"] as? String
        if localName == "Speedmeter" {
            central.stopScan()
            speedmeterPeripheral = peripheral
            showBleStatus(str: "Connecting")
            central.connect(speedmeterPeripheral, options: nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        showBleStatus(str: "Connected")
        speedmeterPeripheral.delegate = self
        speedmeterPeripheral.discoverServices(nil)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        showBleStatus(str: "Scanning")
        speedmeterPeripheral = nil
        speedCharacteristic = nil
        centralManager.scanForPeripherals(withServices: nil, options: nil)
    }
    

}

extension ViewController: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for service in peripheral.services! {
            if service.uuid.uuidString == "6E400001-B5A3-F393-E0A9-E50E24DCCA9F" {
                speedService = service
                speedmeterPeripheral.discoverCharacteristics(nil, for: speedService)
                break
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for characteristic in service.characteristics! {
            speedCharacteristic = characteristic
            break
        }
    }
    
}
