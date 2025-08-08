//
//  Track.swift
//  Jx今夏
//
//  Created by 嘉煦 on 2025/8/7.
//

import Foundation

struct Track: Identifiable {
    let id = UUID()
    let url: URL
    var name: String { url.deletingPathExtension().lastPathComponent }
}
