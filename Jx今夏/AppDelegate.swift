//
//  AppDelegate.swift
//  Jx今夏
//
//  Created by 嘉煦 on 2025/8/7.
//

import Foundation
import UIKit
import AVFoundation
import MediaPlayer

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // 后台播放 Session
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
        try? AVAudioSession.sharedInstance().setActive(true)
        
        // ✅ 关键：提前加载歌曲
//            PlayerViewController.shared.bootstrap()

        // 注册远程控制
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { _ in
            AudioPlayer.shared.resume()
            return .success
        }
        center.pauseCommand.addTarget { _ in
            AudioPlayer.shared.pause()
            return .success
        }

        center.nextTrackCommand.addTarget { _ in
            PlayerViewController.shared?.nextTrack()
            return .success
        }
        center.previousTrackCommand.addTarget { _ in
            PlayerViewController.shared?.prevTrack()
            return .success
        }

        return true
    }
}
