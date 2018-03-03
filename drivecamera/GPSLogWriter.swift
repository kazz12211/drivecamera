//
//  KMLWrite.swift
//  drivecamera
//
//  Created by Kazuo Tsubaki on 2018/03/03.
//  Copyright © 2018年 Kazuo Tsubaki. All rights reserved.
//

import Foundation

class GPSLogWriter : NSObject {
    
    var logFilePath: String!
    var lastTime: Date!
    
    override init() {
        super.init()
    }
    
    init(path: String) {
        super.init()
        self.logFilePath = path
    }
    
    func start() {
        lastTime = Date()
    }
    
    func stop() {
    }
    
    private func log(timestamp: Date, latitude: Double, longitude: Double, altitude: Double) -> String {
        let dateStr = ISO8601DateFormatter.string(from: timestamp, timeZone: TimeZone.current, formatOptions:
            [
                ISO8601DateFormatter.Options.withFullDate,
                ISO8601DateFormatter.Options.withFullTime,
                ISO8601DateFormatter.Options.withTimeZone
            ])
        return "".appendingFormat("\(dateStr),%.8f,%.8f,%.0f\n", latitude, longitude, altitude)
    }
    
    func record(timestamp: Date, latitude: Double, longitude: Double, altitude: Double) {
        if timestamp.timeIntervalSince(lastTime) < 60 {
            return
        }
        
        lastTime = timestamp
        
        guard let outputStream = OutputStream(toFileAtPath: logFilePath, append: true) else {
            return
        }
        
        outputStream.open()
        
        defer {
            outputStream.close()
        }
        
        let str = log(timestamp: timestamp, latitude: latitude, longitude: longitude, altitude: altitude)
        guard let data = str.data(using: String.Encoding.utf8) else {
            return
        }
        
        let result = data.withUnsafeBytes({
            outputStream.write($0, maxLength: data.count)
        })
        
        if(result > 0) {
            print(result)
        }
        return
    }
}
