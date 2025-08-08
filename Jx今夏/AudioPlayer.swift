//
//  AudioPlayer.swift
//  Jx今夏
//
//  Created by 嘉煦 on 2025/8/7.
//

import Foundation
import AVFoundation
import Combine
final class AudioPlayer: NSObject {
    static let shared = AudioPlayer()
    
    private override init() {
        super.init()
    }

    private var player: AVAudioPlayer?
    @Published var isPlaying = false
    
    // 供外部只读判断
    var isLoaded: Bool { player != nil }
    
    var currentTime: TimeInterval { player?.currentTime ?? 0 }
    var duration: TimeInterval   { player?.duration   ?? 0 }

    func play(url: URL) {
        stop()

        // 1. 先验证文件是否存在
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("❌ 文件不存在：\(url.path)")
            return
        }

        // 2. 尝试创建 AVAudioPlayer
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.prepareToPlay()
            player?.play()
            isPlaying = true
            onStateChange?()          // ✅ 通知外部
            print("✅ 开始播放：\(url.lastPathComponent)")
        } catch {
            print("❌ 播放失败：\(error.localizedDescription)  url:\(url)")
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
        print("✅ 暂停播放")
        onStateChange?()          // ✅ 通知外部
    }

    func stop() {
        player?.stop()
        print("✅ 停止播放")
        isPlaying = false
        onStateChange?()          // ✅ 通知外部
    }
    
    // 对外状态回调
    var onStateChange: (() -> Void)?
    
    
    /// 供外部直接设置播放进度
    func seek(to time: TimeInterval) {
        guard let p = player, p.duration > 0 else { return }
        p.currentTime = time
    }
    
    /// 暴露一个“继续播放”方法
    func resume() {
        player?.play()
        isPlaying = true
        print("✅ 继续播放")
        onStateChange?()          // ✅ 通知外部
    }
    
    // AudioPlayer.swift
    func clear() {
        player?.stop()
        player = nil
    }
}

extension AudioPlayer: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        NotificationCenter.default.post(name: .TrackDidFinish, object: nil)
    }
}

extension Notification.Name {
    static let TrackDidFinish = Notification.Name("TrackDidFinish")
}
