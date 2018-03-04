//
//  FilenameUtil.swift
//  drivecamera
//
//  Created by Kazuo Tsubaki on 2018/03/04.
//  Copyright © 2018年 Kazuo Tsubaki. All rights reserved.
//

import Foundation

class FilenameUtil {
    
    var timestampFormatter: DateFormatter = DateFormatter()
    var filenameFormatter: DateFormatter = DateFormatter()
    
    init() {
        filenameFormatter.dateFormat = "yyyyMMdd_HHmmss"
        timestampFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    }
    
    func filename(from: Date) -> String {
        return filenameFormatter.string(from: from)
    }
    
    func date(fromFilename: String) -> Date {
        return filenameFormatter.date(from: fromFilename)!
    }
    
    func timestamp(from: Date) -> String {
        return timestampFormatter.string(from: from)
    }
    
    func date(fromTimestamp: String) -> Date {
        return timestampFormatter.date(from: fromTimestamp)!
    }
}
