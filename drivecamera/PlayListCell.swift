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
        let size = fileSizeFromURL(url: url)
        nameLabel.text = dateTimeStringFromURL(url: url)
        timeLabel.text = "".appendingFormat("%.0f 秒", asset.duration.seconds)
        sizeLabel.text = "\(size) MB"
        videoImageView.image = thumbnailFromVideo(asset: asset)
    }
    
    // ファイル名からタイムスタンプ形式の文字列を作る
    private func dateTimeStringFromURL(url: URL) -> String {
        let name = url.lastPathComponent
        let fn = String(name[name.index(name.startIndex, offsetBy: 0)...name.index(name.endIndex, offsetBy: -5)])
        let dateTime = filename.date(fromFilename: fn)
        return filename.timestamp(from: dateTime)
    }
    
    // ファイルのサイズをメガバイトで返す
    private func fileSizeFromURL(url: URL) -> NSNumber {
        let filePath = NSHomeDirectory() + "/Documents/" + url.lastPathComponent
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: filePath)
            let bytes: NSNumber = attributes[FileAttributeKey.size] as! NSNumber
            return NSNumber(value:bytes.int64Value / (1024 * 1024))
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
