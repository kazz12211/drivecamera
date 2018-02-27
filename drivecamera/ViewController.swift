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

class ViewController: UIViewController, CLLocationManagerDelegate, CBCentralManagerDelegate, CBPeripheralDelegate, AVCaptureFileOutputRecordingDelegate {

    @IBOutlet weak var meterPanel: UIView!
    @IBOutlet weak var previewView: UIView!
    @IBOutlet weak var gsensorSegmentedController: UISegmentedControl!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var speedLabel: UILabel!
    @IBOutlet weak var autoStartSwitch: UISwitch!
    let locationManager = CLLocationManager()
    let motionManager = CMMotionManager()
    var centralManager: CBCentralManager!
    var speedmeterPeripheral: CBPeripheral!
    var speedService: CBService!
    var speedCharacteristic: CBCharacteristic!
    var session: AVCaptureSession!
    var videoDevice: AVCaptureDevice!
    var audioDevice: AVCaptureDevice!
    var videoInput: AVCaptureDeviceInput!
    var audioInput: AVCaptureDeviceInput!
    var fileOutput: AVCaptureMovieFileOutput!
    var filePath: String!
    var recording: Bool = false
    var gsensibility: Double = 2.8
    var autoStart: Bool = true;
    
    var previewLayer: AVCaptureVideoPreviewLayer!
    
    //var testSpeed:Double = 0
    
    // カメラプレビューの設定
    private func setupPreview() {
        previewLayer = AVCaptureVideoPreviewLayer(session:session)
        previewLayer.backgroundColor = UIColor.black.cgColor
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        
        previewLayer.frame = previewView.bounds
        previewView.layer.addSublayer(previewLayer)
                
        let previewLayerConnection: AVCaptureConnection  = previewLayer.connection!
        previewLayerConnection.videoOrientation = .landscapeRight
    }
    
    // ビデオキャプチャーの設定
    private func setupVideo() {
        session = AVCaptureSession()
        session.sessionPreset = AVCaptureSession.Preset.high
        let discoverySession = AVCaptureDevice.DiscoverySession.init(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera], mediaType: AVMediaType.video, position: AVCaptureDevice.Position.back)
        let devices = discoverySession.devices
        for device in devices {
            if device.position == AVCaptureDevice.Position.back {
                videoDevice = device
            }
        }
        audioDevice = AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInMicrophone, for: AVMediaType.audio, position: AVCaptureDevice.Position.unspecified)
        
        do {
            videoInput = try AVCaptureDeviceInput(device:videoDevice)
            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
            } else {
                
            }
            
            audioInput = try AVCaptureDeviceInput(device: audioDevice)
            if session.canAddInput(audioInput) {
                session.addInput(audioInput)
            } else {
                
            }
            fileOutput = AVCaptureMovieFileOutput()
            if session.canAddOutput(fileOutput) {
                session.addOutput(fileOutput)
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
            
            setupPreview()
            
            session.startRunning()
            
        } catch let error {
            print("cannot use camera \(error)")
        }
    }
    
    // 位置情報サービスを開始
    private func setupLocationManager() {
        self.locationManager.delegate = self
        let status = CLLocationManager.authorizationStatus()
        if status == CLAuthorizationStatus.notDetermined {
            self.locationManager.requestAlwaysAuthorization()
        }
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        self.locationManager.startUpdatingLocation()
    }

    // Bluetoothセントラルの開始
    private func setupBluetooth() {
        self.centralManager = CBCentralManager(delegate:self, queue:nil, options:nil)
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
                    if !self.recording {
                        self.startRecording()
                    }
                }
            });
        }
    }
    
    // 録画ボタンの状態変更
    private func updateButton() {
        if recording {
            recordButton.setTitle("停止", for: UIControlState.normal)
            recordButton.backgroundColor = UIColor.red
            recordButton.layer.masksToBounds = true
            recordButton.layer.cornerRadius = 8.0
        } else {
            recordButton.setTitle("録画", for: UIControlState.normal)
            recordButton.backgroundColor = UIColor.blue
            recordButton.layer.masksToBounds = true
            recordButton.layer.cornerRadius = 8.0
        }
    }
    
    // 録画停止
    private func stopRecording() {
        fileOutput.stopRecording()
        recording = false
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
        recording = true
        fileOutput.startRecording(to: fileURL, recordingDelegate: self)
        updateButton()
    }
    
    // 動画の録画・停止アクション
    @IBAction func recordOrStop(sender: AnyObject) {
        if recording {
            self.stopRecording()
        } else {
            self.startRecording()
        }
    }
    
    // Gセンサーの感度設定アクション
    @IBAction func gsensitibityChanged(sender: AnyObject) {
        switch gsensorSegmentedController.selectedSegmentIndex {
        case 0:
            gsensibility = 1.8
            break
        case 1:
            gsensibility = 2.8
            break
        case 2:
            gsensibility = 4.2
            break;
        default:
            gsensibility = 2.8
        }
    }
    
    // 自動録画設定アクション
    @IBAction func changeAutoStart(_ sender: Any) {
        self.autoStart = self.autoStartSwitch.isOn
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        print("capture finished")
    }
    
    @objc func video(videoPath: NSString, didFinishSavingWithError error: NSError?, contextInfo info: AnyObject) {
        if error != nil {
            print("video saving error")
        } else {
            print("video saving success")
        }
    }
    
    private func showBleStatus(str:String) {
        self.statusLabel.text = str
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.speedLabel.text = "0"
        self.gsensorSegmentedController.selectedSegmentIndex = 1
        self.gsensibility = 2.8
        self.autoStartSwitch.isOn = true

        self.showBleStatus(str: "")
        self.setupLocationManager()
        self.setupBluetooth()
        self.setupMotionManager()
        self.setupVideo()
        self.updateButton()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let myLocation = locations.last! as CLLocation
        var speed = myLocation.speed
        
        if speed < 0 {
            speed = 0
        }
        speed *= 3.6
        
        sendSpeed(speed:speed)
        //sendSpeed(speed:self.testSpeed)
        //self.testSpeed += 1.0
        
        // 時速５キロを超えたら録画を自動的に開始する
        if(speed > 5.0 && !self.recording && self.autoStart) {
            self.startRecording()
        }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            self.showBleStatus(str: "Scanning")
            self.centralManager.scanForPeripherals(withServices: nil, options: nil)
        default:
            print(central.state)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let localName = advertisementData["kCBAdvDataLocalName"] as? String
        if localName == "Speedmeter" {
            central.stopScan()
            self.speedmeterPeripheral = peripheral
            self.showBleStatus(str: "Connecting")
            central.connect(self.speedmeterPeripheral, options: nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        self.showBleStatus(str: "Connected")
        self.speedmeterPeripheral.delegate = self
        self.speedmeterPeripheral.discoverServices(nil)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        //print("DidDiscoverServices")
        for service in peripheral.services! {
            if service.uuid.uuidString == "6E400001-B5A3-F393-E0A9-E50E24DCCA9F" {
                self.speedService = service
                self.speedmeterPeripheral.discoverCharacteristics(nil, for: self.speedService)
                break
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for characteristic in service.characteristics! {
            self.speedCharacteristic = characteristic
            break
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        self.showBleStatus(str: "Scanning")
        self.speedmeterPeripheral = nil
        self.speedCharacteristic = nil
        self.centralManager.scanForPeripherals(withServices: nil, options: nil)
    }

    func sendSpeed(speed:CLLocationSpeed) {
        self.speedLabel.text = "".appendingFormat("%.0f", speed)
        if speed < 50 {
            self.meterPanel.backgroundColor = UIColor.black
        } else if speed < 70 {
            self.meterPanel.backgroundColor = UIColor.blue
        } else if speed < 100 {
            self.meterPanel.backgroundColor = UIColor.magenta
        } else {
            self.meterPanel.backgroundColor = UIColor.red
        }
        if self.speedCharacteristic != nil {
            let str = "".appendingFormat("{speed:%.0f}", speed)
            let data = str.data(using: String.Encoding.utf8)!
            self.speedmeterPeripheral.writeValue(data, for: self.speedCharacteristic, type: CBCharacteristicWriteType.withResponse)
        }
    }

}

