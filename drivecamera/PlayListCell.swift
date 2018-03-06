//
//  PlayListCell.swift
//  drivecamera
//
//  Created by Kazuo Tsubaki on 2018/03/02.
//  Copyright © 2018年 Kazuo Tsubaki. All rights reserved.
//

import UIKit
import AVFoundation

class PlayListCell: UITableViewCell {
    
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var sizeLabel: UILabel!
    @IBOutlet weak var videoImageView: UIImageView!
    
    var filename: FilenameUtil = FilenameUtil()
        
    func setURL(url: URL) {
        let asset = AVAsset(url: url)
        nameLabel.text = dateTimeStringFromURL(url: url)
        timeLabel.text = timeStringFromAsset(asset: asset)
        sizeLabel.text = fileSizeStringFromURL(url: url)
        videoImageView.image = thumbnailFromVideo(asset: asset)
    }
    
    // ファイル名からタイムスタンプ形式の文字列を作る
    private func dateTimeStringFromURL(url: URL) -> String {
        let name = url.lastPathComponent
        let fn = String(name[name.index(name.startIndex, offsetBy: 0)...name.index(name.endIndex, offsetBy: -5)])
        let dateTime = filename.date(fromFilename: fn)
        return filename.timestamp(from: dateTime)
    }
    
    private func timeStringFromAsset(asset: AVAsset) -> String {
        var seconds = UInt64(asset.duration.seconds)
        var minutes = UInt64(0)
        var hours = UInt64(0)
        if(seconds >= 60) {
            minutes = seconds / 60
            seconds = seconds % 60
        }
        if(minutes >= 60) {
            hours = minutes / 60
            minutes = minutes % 60
        }
        if hours > 0 {
            return "\(hours)時間\(minutes)分\(seconds)秒"
        }
        if minutes > 0 {
            return "\(minutes)分\(seconds)秒"
        } else {
            return "\(seconds)秒"
        }
    }
    
    private func fileSizeStringFromURL(url: URL) -> String {
        let kb = fileSizeFromURL(url: url).int64Value;
        if kb < 1024 {
            return "".appendingFormat("\(kb) KB")
        }
        if kb < (1024 * 1024) {
            let mb = kb / 1024
            return "".appendingFormat("\(mb) MB")
        }
        let mb = (kb / 1024) % 1024
        let gb = kb / (1024 * 1024)
        return "".appendingFormat("\(gb).\(mb) GB")
    }
    
    // ファイルのサイズをメガバイトで返す
    private func fileSizeFromURL(url: URL) -> NSNumber {
        let filePath = NSHomeDirectory() + "/Documents/" + url.lastPathComponent
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: filePath)
            let bytes: NSNumber = attributes[FileAttributeKey.size] as! NSNumber
            return NSNumber(value:bytes.int64Value / 1024)
        } catch {
        }
        return NSNumber(value: 0)
    }
    
    // ビデオのサムネイルを取得する
    private func thumbnailFromVideo(asset: AVAsset) -> UIImage? {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.maximumSize = videoImageView.frame.size
        do {
            let thumbnail = try generator.copyCGImage(at: asset.duration, actualTime: nil)
            return UIImage(cgImage: thumbnail)
        } catch {
            return UIImage(named: "video-camera")
        }
    }
}
