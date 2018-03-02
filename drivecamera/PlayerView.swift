//
//  PlayerView.swift
//  drivecamera
//
//  Created by Kazuo Tsubaki on 2018/03/02.
//  Copyright © 2018年 Kazuo Tsubaki. All rights reserved.
//

import UIKit
import AVFoundation

class PlayerView: UIView {

    override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
}
