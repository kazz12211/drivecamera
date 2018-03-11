//
//  ViewController.swift
//  drivecamera
//
//  Created by Kazuo Tsubaki on 2018/02/25.
//  Copyright © 2018年 Kazuo Tsubaki. All rights reserved.
//

import UIKit
import CoreLocation
import CoreMotion
import AVFoundation

class ViewController: UIViewController {

    @IBOutlet weak var meterPanel: UIView!
    @IBOutlet weak var previewView: UIView!
    @IBOutlet weak var gsensorSegmentedController: UISegmentedControl!
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var speedLabel: UILabel!
    @IBOutlet weak var autoStartSwitch: UISwitch!
    @IBOutlet weak var altitudeLabel: UILabel!
    @IBOutlet weak var latitudeLabel: UILabel!
    @IBOutlet weak var longitudeLabel: UILabel!
    @IBOutlet weak var batteryLevelLabel: UILabel!
    @IBOutlet weak var qualitySegmentedControl: UISegmentedControl!
    @IBOutlet weak var audioSwitch: UISwitch!
    @IBOutlet weak var videoListButton: UIButton!
    @IBOutlet weak var freeStorageLabel: UILabel!
    @IBOutlet weak var bleStatusView: UIView!
    @IBOutlet weak var gpsLogSwitch: UISwitch!
    
    let locationManager = CLLocationManager()
    let motionManager = CMMotionManager()
    
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
    var speeds: [Double]!
    var recordAudio: Bool = true
    var gpsLogging: Bool = false
    var logFilePath: String!
    var logWriter: GPSLogWriter!
    var filename: FilenameUtil = FilenameUtil()
    var logTimer: Timer!
    var speedIndicator: SpeedIndicator!
    
    var testSpeed:Double = 10
    

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
        timestampLayer.string = filename.timestamp(from: Date())
        previewView.layer.addSublayer(timestampLayer)
        let timer = Timer.scheduledTimer(timeInterval: 1/5, target: self, selector: #selector(ViewController.updateClock), userInfo: nil, repeats: true)
        timer.fire()
   }
    
    @objc func restartRecording() {
        stopRecording()
        startRecording()
    }
    
    @objc func updateClock() {
        timestampLayer.string = filename.timestamp(from: Date())
        showFreeStorageSize()
    }
    // ビデオキャプチャーの設定
    private func setupCaptureSession() {
        captureSession.sessionPreset = videoQualities[videoQuality]
    }
    
    // 入力デバイスの設定
    private func setupCaptureDevice() {
        let discoverySession = AVCaptureDevice.DiscoverySession.init(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera], mediaType: AVMediaType.video, position: AVCaptureDevice.Position.back)
        let devices = discoverySession.devices
        
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
    
    private func setupVideoFileOutputLayout() {
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
    
    // 動画録画先の設定
    private func setupVideoOutput() {
        fileOutput = AVCaptureMovieFileOutput()
        if captureSession.canAddOutput(fileOutput) {
            captureSession.addOutput(fileOutput)
        }
        setupVideoFileOutputLayout()
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
        // バッテリーの充電状態の変化を検知する
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.batteryLevelChanged(notification:)), name: NSNotification.Name.UIDeviceBatteryLevelDidChange, object: nil)
        // バッテリーが充電中かどうかを判定する
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.batteryStateChanged(notification:)), name: NSNotification.Name.UIDeviceBatteryStateDidChange, object: nil)
    }
    // ボタンの状態変更
    private func updateButtons() {
        gsensorSegmentedController.isEnabled = !recordingInProgress
        qualitySegmentedControl.isEnabled = !recordingInProgress
        autoStartSwitch.isEnabled = !recordingInProgress
        qualitySegmentedControl.isEnabled = !recordingInProgress
        audioSwitch.isEnabled = !recordingInProgress
        videoListButton.isEnabled = !recordingInProgress
        gpsLogSwitch.isEnabled = !recordingInProgress
        
        if recordingInProgress {
            UIView.animateKeyframes(withDuration: 1.5, delay: 0.0, options: [.repeat ,.allowUserInteraction], animations: {
                self.recordButton.alpha = 0.1
            }, completion: nil)
        } else {
            recordButton.layer.removeAllAnimations()
            recordButton.alpha = 1.0
        }
    }
    
    private func setupSpeedIndicator() {
        speedIndicator = SpeedIndicator(deviceName: "konashi2-f02226")
        NotificationCenter.default.addObserver(self, selector: #selector(speedIndicationIsReadyToConnect(notif:)), name: SpeedIndicator.SpeedIndicatorReadyToConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(speedIndicatorReady(notif:)), name: SpeedIndicator.SpeedIndicatorReady, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(speedIndicatorNotReady(notif:)), name: SpeedIndicator.SpeedIndicatorNotReady, object: nil)
        showBleStatus(status: 1)
    }
    // 録画停止
    private func stopRecording() {
        if recordingInProgress {
            fileOutput.stopRecording()
            recordingInProgress = false

            if gpsLogging {
                logWriter.stop()
                logTimer.invalidate()
                logTimer = nil
            }
            updateButtons()
        }
    }
    
    // 録画開始
    private func startRecording() {
        if !recordingInProgress {
            let documentPath = NSHomeDirectory() + "/Documents/"
            let date = Date()
            filePath = documentPath + filename.filename(from: date) + ".mp4"
            let fileURL: URL = URL(fileURLWithPath: filePath)
            recordingInProgress = true
            fileOutput.startRecording(to: fileURL, recordingDelegate: self)

            if gpsLogging {
                logFilePath = documentPath + filename.filename(from: date) + ".csv"
                logWriter = GPSLogWriter(path:logFilePath)
                logWriter.start()
                logTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(Constants.LoggingInterval), repeats: true, block: { (timer) in
                    let location = self.locationManager.location
                    let altitude = location?.altitude
                    let latitude = location?.coordinate.latitude
                    let longitude = location?.coordinate.longitude
                    self.logGPS(timestamp: Date(), altitude: altitude!, latitude: latitude!, longitude: longitude!)
                })
                logTimer.fire()
            } else {
                logFilePath = nil
            }

            updateButtons()
        }
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
        captureSession.beginConfiguration()
        
        videoQuality = qualitySegmentedControl.selectedSegmentIndex
        captureSession.sessionPreset = videoQualities[videoQuality]
 
        captureSession.commitConfiguration()
        
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
        
        captureSession.beginConfiguration()
        
        if !recordAudio {
            removeAudioInput()
        } else {
            addAudioInput()
        }
        
        captureSession.commitConfiguration()

        saveUserDefaults()
    }
    
    @IBAction func gpsLogChanged(_ sender: Any) {
        gpsLogging = gpsLogSwitch.isOn
        saveUserDefaults()
    }
    
    @objc func batteryLevelChanged(notification: NSNotification)  {
        showBatteryLevel(batteryLevel: UIDevice.current.batteryLevel)
    }
    
    @objc func batteryStateChanged(notification: NSNotification)  {
        if recordingInProgress && UIDevice.current.batteryState == .unplugged {
            stopRecording()
        }
    }

    private func showBatteryLevel(batteryLevel: Float) {
        batteryLevelLabel.text = "".appendingFormat("%.0f%%", batteryLevel * 100)
    }
    
    private func showBleStatus(status:Int) {
        bleStatusView.layer.removeAllAnimations()
        bleStatusView.alpha = 1.0
        
        switch status {
        case 0:
            bleStatusView.backgroundColor = UIColor.black
            break
        case 1: // scanning
            bleStatusView.backgroundColor = UIColor.green
            UIView.animateKeyframes(withDuration: 0.6, delay: 0.0, options: UIViewKeyframeAnimationOptions.repeat, animations: {
                self.bleStatusView.alpha = 0
            }, completion: nil)
            break
        case 2: // connecting
            bleStatusView.backgroundColor = UIColor.blue
            UIView.animateKeyframes(withDuration: 0.6, delay: 0.0, options: UIViewKeyframeAnimationOptions.repeat, animations: {
                self.bleStatusView.alpha = 0
            }, completion: nil)
            break
        case 3: // connected
            bleStatusView.backgroundColor = UIColor.yellow
            break
        case 4: // engaged
            bleStatusView.backgroundColor = UIColor.orange
            break
        default:
            break
        }
    }
    
    private func calculateFreeStorageSize() -> NSNumber {
        let documentDirPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        if let sysAttributes = try? FileManager.default.attributesOfFileSystem(forPath: documentDirPath.last!) {
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
    
    
    private func setupBleStatusView() {
        bleStatusView.layer.masksToBounds = true
        bleStatusView.layer.cornerRadius = 5
        bleStatusView.layer.opacity = 1
        bleStatusView.backgroundColor = UIColor.white
    }
  
    @objc func speedIndicationIsReadyToConnect(notif: Notification) -> Void {
        speedIndicator.connect()
    }
    
    @objc func speedIndicatorReady(notif: Notification) -> Void {
        showBleStatus(status: 4)
    }
    
    @objc func speedIndicatorNotReady(notif: Notification)  -> Void {
        showBleStatus(status: 1)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        speedLabel.text = "0"
        gsensorSegmentedController.selectedSegmentIndex = 1
        gsensibility = Constants.GSensorMedium
        autoStartSwitch.isOn = true
        recordButton.layer.masksToBounds = true
        recordButton.layer.cornerRadius = 24.0
        recordButton.backgroundColor = UIColor.red
        
        
        reflectUserDefaults()

        showFreeStorageSize()
        setupBleStatusView()
        setupLocationManager()
        setupSpeedIndicator()
        setupMotionManager()
        setupCaptureSession()
        setupCaptureDevice()
        setupVideoOutput()
        setupPreviewLayer()
        setupTimestampLayer()
        setupBatteryLevelMonitoring()
        updateButtons()
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startCaptureSession()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopCaptureSession()
    }

    func sendSpeed(speed:CLLocationSpeed) {
        speedLabel.text = "".appendingFormat("%.0f", speed)
        
        if speed < speeds[1] {
            meterPanel.backgroundColor = UIColor.black
        } else if speed >= speeds[1] && speed < speeds[2] {
            meterPanel.backgroundColor = UIColor.blue
        } else if speed >= speeds[2] && speed < speeds[3] {
            meterPanel.backgroundColor = UIColor.magenta
        } else {
            meterPanel.backgroundColor = UIColor.red
        }
        if speed >= speeds[4] {
            startBlinking()
        } else {
            stopBlinking()
        }
        // SpeedIndicatorにスピードを送信
        if speedIndicator.isReady() {
            speedIndicator.showSpeed(speed)
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
    
    private func logGPS(timestamp: Date, altitude: Double, latitude: Double, longitude: Double) {
        logWriter.record(timestamp: timestamp, latitude: latitude, longitude: longitude, altitude: altitude)
    }
}

extension ViewController: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
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
        /*
        speed *= 3.6
        
        sendSpeed(speed:speed)
        */
        sendSpeed(speed:testSpeed)
         if testSpeed > 120 {
            testSpeed = 40
         } else {
            testSpeed += 10.0
         }
         
        // 時速10キロを超えたら録画を自動的に開始する
        if speed > speeds[0] && !recordingInProgress && autoStartEnabled {
            startRecording()
        }
        
    }

}


extension ViewController {
    
    private func loadUserDefaults() {
        let defaults = UserDefaults.standard
        gsensibility = defaults.double(forKey: Constants.GSensorSensibilityKey)
        autoStartEnabled = defaults.bool(forKey: Constants.AutoStartEnabledKey)
        autoStopEnabled = defaults.bool(forKey: Constants.AutoStopEnabledKey)
        videoQuality = defaults.integer(forKey: Constants.VideoQualityKey)
        speeds = [Constants.SpeedVerySlow, Constants.SpeedSlow, Constants.SpeedNormal, Constants.SpeedHigh, Constants.SpeedVeryHigh]
        /*
        if defaults.double(forKey: Constants.SpeedVerySlowKey) != 0 {
            speeds[0] = defaults.double(forKey: Constants.SpeedVerySlowKey)
            if speeds[0] < Constants.SpeedVerySlow {
                speeds[0] = Constants.SpeedVerySlow
            }
        }
        if defaults.double(forKey: Constants.SpeedSlowKey) != 0 {
            speeds[1] = defaults.double(forKey: Constants.SpeedSlowKey)
            if speeds[1] < Constants.SpeedSlow {
                speeds[1] = Constants.SpeedSlow
            }
        }
        if defaults.double(forKey: Constants.SpeedNormalKey) != 0 {
            speeds[2] = defaults.double(forKey: Constants.SpeedNormalKey)
            if speeds[2] < Constants.SpeedNormal {
                speeds[2] = Constants.SpeedNormal
            }
        }
        if defaults.double(forKey: Constants.SpeedHighKey) != 0 {
            speeds[3] = defaults.double(forKey: Constants.SpeedHighKey)
            if speeds[3] < Constants.SpeedHigh {
                speeds[3] = Constants.SpeedHigh
            }
        }
        if defaults.double(forKey: Constants.SpeedVeryHighKey) != 0 {
            speeds[4] = defaults.double(forKey: Constants.SpeedVeryHighKey)
            if speeds[4] < Constants.SpeedVeryHigh {
                speeds[4] = Constants.SpeedVeryHigh
            }
        }
         */
        recordAudio = defaults.bool(forKey: Constants.RecordAudioKey)
        gpsLogging = defaults.bool(forKey: Constants.GPSLogEnabledKey)
    }
    
    private func reflectUserDefaults() {
        loadUserDefaults()

        if(gsensibility == Constants.GSensorWeak) {
            gsensorSegmentedController.selectedSegmentIndex = 2
        } else if(gsensibility == Constants.GSensorMedium) {
            gsensorSegmentedController.selectedSegmentIndex = 1
        } else if(gsensibility == Constants.GSensorStrong) {
            gsensorSegmentedController.selectedSegmentIndex = 0
        }
        
        autoStartSwitch.isOn = autoStartEnabled
        
        qualitySegmentedControl.selectedSegmentIndex = videoQuality
        
        audioSwitch.isOn = recordAudio
        
        gpsLogSwitch.isOn = gpsLogging
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
        defaults.set(gpsLogging, forKey: Constants.GPSLogEnabledKey)
    }

}


