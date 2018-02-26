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
    
    var previewLayer: AVCaptureVideoPreviewLayer!
    var dateTimeLayer: CATextLayer!
    
    //var testSpeed:Double = 0
    
    private func setupPreview() {
        previewLayer = AVCaptureVideoPreviewLayer(session:session)
        previewLayer.backgroundColor = UIColor.black.cgColor
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        
        previewLayer.frame = previewView.bounds
        previewView.layer.addSublayer(previewLayer)
                
        let previewLayerConnection: AVCaptureConnection  = previewLayer.connection!
        previewLayerConnection.videoOrientation = .landscapeRight
    }
    
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
            
        } catch let error {
            print("cannot use camera \(error)")
        }
    }
    
    private func setupLocationManager() {
        self.locationManager.delegate = self
        let status = CLLocationManager.authorizationStatus()
        if status == CLAuthorizationStatus.notDetermined {
            self.locationManager.requestAlwaysAuthorization()
        }
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        self.locationManager.startUpdatingLocation()
    }

    private func setupBluetooth() {
        self.centralManager = CBCentralManager(delegate:self, queue:nil, options:nil)
    }

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
    
    private func stopRecording() {
        fileOutput.stopRecording()
        session.stopRunning()
        recording = false
        UISaveVideoAtPathToSavedPhotosAlbum(filePath, self, #selector(ViewController.video(videoPath:didFinishSavingWithError:contextInfo:)), nil)
        updateButton()
    }
    
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
        session.startRunning()
        recording = true
        fileOutput.startRecording(to: fileURL, recordingDelegate: self)
        updateButton()
    }
    
    @IBAction func recordOrStop(sender: AnyObject) {
        if recording {
            self.stopRecording()
        } else {
            self.startRecording()
        }
    }
    
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
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.speedLabel.text = "0"
        self.statusLabel.text = ""
        self.gsensorSegmentedController.selectedSegmentIndex = 1
        self.gsensibility = 2.8

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
        sendSpeed(speed:speed)
        //sendSpeed(speed:self.testSpeed)
        //self.testSpeed += 1.0
        
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            self.statusLabel.text = "Scanning.."
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
            self.statusLabel.text = "Connecting..."
            central.connect(self.speedmeterPeripheral, options: nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        statusLabel.text = "Connected"
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

    func sendSpeed(speed:CLLocationSpeed) {
        let kmh = speed * 3.6
        self.speedLabel.text = "".appendingFormat("%.0f", kmh)
        if kmh < 50 {
            self.meterPanel.backgroundColor = UIColor.black
        } else if kmh < 70 {
            self.meterPanel.backgroundColor = UIColor.blue
        } else if kmh < 100 {
            self.meterPanel.backgroundColor = UIColor.magenta
        } else {
            self.meterPanel.backgroundColor = UIColor.red
        }
        if self.speedCharacteristic != nil {
            let str = "".appendingFormat("{speed:%.0f}", kmh)
            let data = str.data(using: String.Encoding.utf8)!
            self.speedmeterPeripheral.writeValue(data, for: self.speedCharacteristic, type: CBCharacteristicWriteType.withResponse)
        }
    }

}

