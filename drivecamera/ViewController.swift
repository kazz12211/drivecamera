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
    @IBOutlet weak var qualitySegmentedControl: UISegmentedControl!
    
    let locationManager = CLLocationManager()
    let motionManager = CMMotionManager()
    var centralManager: CBCentralManager!
    
    var speedmeterPeripheral: CBPeripheral!
    var speedService: CBService!
    var speedCharacteristic: CBCharacteristic!
    
    var captureSession: AVCaptureSession!
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
    
    var previewLayer: AVCaptureVideoPreviewLayer!
    var timestampLayer: CATextLayer!
    var timestampFormatter: DateFormatter!
    
    var testSpeed:Double = 0
    
    // カメラプレビューの設定
    private func setupPreview() {
        previewLayer = AVCaptureVideoPreviewLayer(session:captureSession)
        previewLayer.backgroundColor = UIColor.black.cgColor
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        
        previewLayer.frame = previewView.bounds
        previewView.layer.addSublayer(previewLayer)
        
        timestampLayer = CATextLayer()
        timestampLayer.frame = CGRect(x: 4, y: 4, width: 130, height: 20)
        timestampLayer.foregroundColor = UIColor.green.cgColor
        timestampLayer.fontSize = 14.0
        timestampLayer.allowsEdgeAntialiasing = true
        timestampLayer.string = timestampFormatter.string(from: Date())
        previewView.layer.addSublayer(timestampLayer)
                
        let previewLayerConnection: AVCaptureConnection  = previewLayer.connection!
        previewLayerConnection.videoOrientation = .landscapeRight
        
        let composition = AVMutableVideoComposition()
        composition.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: previewLayer, in: previewView.layer)
        
        let timer = Timer.scheduledTimer(timeInterval: 1/5, target: self, selector: #selector(updateClock), userInfo: nil, repeats: true)
        timer.fire()
    }
    
    @objc func updateClock() {
        timestampLayer.string = timestampFormatter.string(from: Date())
    }
    // ビデオキャプチャーの設定
    private func setupCaptureSession() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = AVCaptureSession.Preset.hd1280x720
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
        
        audioDevice = AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInMicrophone, for: AVMediaType.audio, position: AVCaptureDevice.Position.unspecified)
        
        do {
            videoInput = try AVCaptureDeviceInput(device:videoDevice)
            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
            }
            
            audioInput = try AVCaptureDeviceInput(device: audioDevice)
            if captureSession.canAddInput(audioInput) {
                captureSession.addInput(audioInput)
            }
        } catch {
            print("cannot setup capture device", error)
        }
    }
    
    // キャプチャーセッションの開始
    private func startCaptureSession() {
        captureSession.startRunning()
    }
    
    // キャプチャーセッションの終了
    private func stopCaptureSession() {
        captureSession.stopRunning()
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
    
    // 録画ボタンの状態変更
    private func updateButton() {
        if recordingInProgress {
            recordButton.setTitle("停止", for: UIControlState.normal)
            recordButton.backgroundColor = UIColor.red
            UIView.animateKeyframes(withDuration: 1.0, delay: 0.0, options: [.repeat ,.allowUserInteraction], animations: {
                self.recordButton.alpha = 0.5
            }, completion: nil)

        } else {
            recordButton.setTitle("録画", for: UIControlState.normal)
            recordButton.backgroundColor = UIColor.blue
            recordButton.layer.removeAllAnimations()
            recordButton.alpha = 1.0
        }
    }
    
    // 録画停止
    private func stopRecording() {
        fileOutput.stopRecording()
        recordingInProgress = false
        UISaveVideoAtPathToSavedPhotosAlbum(filePath, self, #selector(ViewController.video(videoPath:didFinishSavingWithError:contextInfo:)), nil)
        updateButton()
    }
    
    // 録画開始
    private func startRecording() {
        filePath = NSHomeDirectory() + "/Documents/drivecamera_tmp.mp4"
        if FileManager.default.fileExists(atPath: filePath) {
            do {
                try FileManager.default.removeItem(atPath: filePath)
            } catch let error {
                print(error)
            }
        }
        let fileURL: URL = URL(fileURLWithPath: filePath)
        recordingInProgress = true
        fileOutput.startRecording(to: fileURL, recordingDelegate: self)
        updateButton()
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
            gsensibility = 4.2
            break
        case 1:
            gsensibility = 2.8
            break
        case 2:
            gsensibility = 1.8
            break;
        default:
            gsensibility = 2.8
        }
    }
    
    // 動画品質の設定
    @IBAction func qualityChanged(_ sender: Any) {
        stopCaptureSession()

        if qualitySegmentedControl.selectedSegmentIndex == 0 {
            captureSession.sessionPreset = .hd1280x720
        } else {
            captureSession.sessionPreset = .hd1920x1080
        }

        startCaptureSession()
    }
    // 自動録画設定アクション
    @IBAction func changeAutoStart(_ sender: Any) {
        autoStartEnabled = autoStartSwitch.isOn
        autoStopEnabled = autoStartEnabled
    }
    
    @objc func video(videoPath: NSString, didFinishSavingWithError error: NSError?, contextInfo info: AnyObject) {
        if error != nil {
            print("video saving error")
        } else {
            print("video saving success")
        }
    }
    
    private func showBleStatus(str:String) {
        statusLabel.text = str
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        speedLabel.text = "0"
        gsensorSegmentedController.selectedSegmentIndex = 1
        gsensibility = 2.8
        autoStartSwitch.isOn = true
        recordButton.layer.masksToBounds = true
        recordButton.layer.cornerRadius = 8.0
        timestampFormatter = DateFormatter()
        timestampFormatter.dateFormat = "yyyy/MM/dd HH:mm:ss"

        showBleStatus(str: "")
        setupLocationManager()
        setupBluetooth()
        setupMotionManager()
        setupCaptureSession()
        setupCaptureDevice()
        setupVideoOutput()
        setupPreview()
        updateButton()
        startCaptureSession()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


    func sendSpeed(speed:CLLocationSpeed) {
        speedLabel.text = "".appendingFormat("%.0f", speed)
        
        if speed < 50 {
            meterPanel.backgroundColor = UIColor.black
        } else if speed < 70 {
            meterPanel.backgroundColor = UIColor.blue
        } else if speed < 100 {
            meterPanel.backgroundColor = UIColor.magenta
        } else {
            meterPanel.backgroundColor = UIColor.red
        }
        if speed >= 110 {
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
        print("capture finished")
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
        if(speed > 5.0 && !recordingInProgress && autoStartEnabled) {
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
