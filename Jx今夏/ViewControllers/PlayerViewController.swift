//
//  PlayerViewController.swift
//  Jx今夏
//
//  Created by 嘉煦 on 2025/8/7.
//

import UIKit
import Combine
import MediaPlayer

final class PlayerViewController: UIViewController {
    static var shared: PlayerViewController! // 供 AppDelegate 使用

    private var tracks: [Track] = []
    private var index = 0
    private var bag = Set<AnyCancellable>()
    private let buttonStack = UIStackView()
    
    // MARK: - 播放列表
    private let tableView = UITableView()

    private let prevButton = UIButton(type: .system)
    private let playButton = UIButton(type: .system)
    private let nextButton = UIButton(type: .system)

    private let nameLabel   = UILabel()
    private let slider      = UISlider()
    private let timeLabel   = UILabel()
    private var timer: Timer?

    // ENTRY
    override func viewDidLoad() {
        super.viewDidLoad()
        PlayerViewController.shared = self   // ✅ 绑定
        title = "今夏播放器"
        view.backgroundColor = .systemBackground
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "清空",
            style: .plain,
            target: self,
            action: #selector(clearAllTracks)
        )
        
        setupUI()
        bindEvents()
        loadLocalTracks()
        bindProgress()
        bindPlayState()
    }
    
    func bootstrap() {
        loadLocalTracks()  // 包含本地扫描 + 持久化恢复
    }

    private func bindProgress() {
        // 0.1 秒刷新一次
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            self.updateProgress()
        }
    }

    private func updateProgress() {
        let player = AudioPlayer.shared
        let current = player.currentTime
        let total   = player.duration
        guard total > 0 else { return }

        slider.value = Float(current / total)
        timeLabel.text = String(format: "%02d:%02d / %02d:%02d",
                                Int(current / 60), Int(current) % 60,
                                Int(total   / 60), Int(total)   % 60)

        // 本地封面
        let coverURL = tracks[index].url.deletingPathExtension().appendingPathExtension("jpg")
        if let image = UIImage(contentsOfFile: coverURL.path) {
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            let mpic = MPNowPlayingInfoCenter.default()
            mpic.nowPlayingInfo = [
                MPMediaItemPropertyTitle: tracks[index].name,
                MPMediaItemPropertyArtist: "Jx今夏",
                MPMediaItemPropertyArtwork: artwork,
                MPMediaItemPropertyPlaybackDuration: AudioPlayer.shared.duration,
                MPNowPlayingInfoPropertyElapsedPlaybackTime: AudioPlayer.shared.currentTime,
                MPNowPlayingInfoPropertyPlaybackRate: 1.0
            ]
        } else {
            // 如果没有找到封面，使用默认图标
            let defaultImage = UIImage(named: "HJCP") ?? UIImage(systemName: "music.note")! // UIImage(systemName: "music.note")!
            
            let artwork = MPMediaItemArtwork(boundsSize: defaultImage.size) { _ in defaultImage }
            let mpic = MPNowPlayingInfoCenter.default()
            mpic.nowPlayingInfo = [
                MPMediaItemPropertyTitle: tracks[index].name,
                MPMediaItemPropertyArtist: "Jx今夏",
                MPMediaItemPropertyArtwork: artwork,
                MPMediaItemPropertyPlaybackDuration: AudioPlayer.shared.duration,
                MPNowPlayingInfoPropertyElapsedPlaybackTime: AudioPlayer.shared.currentTime,
                MPNowPlayingInfoPropertyPlaybackRate: 1.0
            ]
        }
    }
    
    @objc private func sliderChanged(_ sender: UISlider) {
        let newTime = TimeInterval(sender.value) * AudioPlayer.shared.duration
        AudioPlayer.shared.seek(to: newTime)
    }

    private func playCurrent() {
        guard !tracks.isEmpty else { return }
        AudioPlayer.shared.play(url: tracks[index].url)
        nameLabel.text = tracks[index].name
        tableView.reloadData()
        
        let targetRow = max(0, min(index, tracks.count - 1))   // 保护越界
        tableView.scrollToRow(at: IndexPath(row: targetRow, section: 0),
                              at: .top, animated: true)

        self.playButton.setTitle(AudioPlayer.shared.isPlaying ? "⏸️" : "⏯️", for: .normal)
        
        updateLockScreen()
    }

    private func setupUI() {
        // 1️⃣ 子视图
        nameLabel.textAlignment = .center
        nameLabel.font = .boldSystemFont(ofSize: 18)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        tableView.delegate   = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.rowHeight = 45
        tableView.translatesAutoresizingMaskIntoConstraints = false
        // ✅ 让列表自己决定高度，最大不超过父视图剩余空间
        tableView.setContentHuggingPriority(.defaultLow, for: .vertical)
        tableView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        slider.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.translatesAutoresizingMaskIntoConstraints = false

        [prevButton, playButton, nextButton].forEach {
            $0.titleLabel?.font = .systemFont(ofSize: 50)
        }
        prevButton.setTitle("⏮️", for: .normal)
        playButton.setTitle("⏯️", for: .normal)
        nextButton.setTitle("⏭️", for: .normal)
        prevButton.addTarget(self, action: #selector(prevTrack), for: .touchUpInside)
        playButton.addTarget(self, action: #selector(playPause), for: .touchUpInside)
        nextButton.addTarget(self, action: #selector(nextTrack), for: .touchUpInside)

        let buttonStack = UIStackView(arrangedSubviews: [prevButton, playButton, nextButton])
        buttonStack.axis = .horizontal
        buttonStack.spacing = 40
        buttonStack.distribution = .fillEqually
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        // 2️⃣ 垂直主 StackView（列表 + 进度 + 按钮）
        let mainStack = UIStackView(arrangedSubviews: [
            nameLabel, tableView, slider, timeLabel, buttonStack
        ])
        mainStack.axis = .vertical
        mainStack.spacing = 12
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mainStack)

        // 3️⃣ 约束
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            mainStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            mainStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            mainStack.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            
            // 列表高度
            tableView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.55)
        ])
    }
    
    /// 始终 10 首：当前歌尽量放在中间，边界时整体平移
    private var visibleTracks: [Track] { tracks }

    private func bindEvents() {
        NotificationCenter.default
            .publisher(for: .TrackDidFinish)
            .sink { [weak self] _ in
                self?.nextTrack()
            }
            .store(in: &bag)
    }

    private func loadLocalTracks() {
        print("加载歌曲")
        let docs = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
        guard
            let files = try? FileManager.default.contentsOfDirectory(
                at: docs,
                includingPropertiesForKeys: nil
            )
        else { return }
        tracks = files.filter { url in
            ["mp3", "m4a", "flac"].contains(url.pathExtension.lowercased())
        }.map { Track(url: $0) }
        
        print("找到\(tracks.count)首歌曲")
        
        if !tracks.isEmpty {
            playCurrent()
        } else {
            tableView.reloadData()
            nameLabel.text = "暂无歌曲"
            slider.value = 0
            timeLabel.text = "--:-- / --:--"
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let importVC = ImportViewController()
        importVC.delegate = self
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "导入",
            style: .plain,
            target: self,
            action: #selector(openImport))
    }

    @objc private func openImport() {
        let importVC = ImportViewController()
        importVC.delegate = self
        let nav = UINavigationController(rootViewController: importVC)
        present(nav, animated: true)
    }
    
    @objc func prevTrack() {
        guard !tracks.isEmpty else { return }
        index = (index - 1 + tracks.count) % tracks.count
        playCurrent()
    }

    @objc func nextTrack() {
        print("next2 \(tracks) \(index)")
        guard !tracks.isEmpty else { return }
        index = (index + 1) % tracks.count
        playCurrent()
    }

    @objc private func playPause() {
        let player = AudioPlayer.shared
        if player.isPlaying {
            player.pause()
        } else {
            // 如果 player 已经存在，直接继续；不存在才重新加载
            if player.isLoaded != nil {
                player.resume()
            } else if !tracks.isEmpty {
                playCurrent()   // 第一次加载
            }
        }
    }
    
    @objc private func clearAllTracks() {
        let alert = UIAlertController(title: "确认清空",
                                      message: "将删除所有本地歌曲且不可恢复",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "确定", style: .destructive, handler: { _ in
            self.performClear()
        }))
        present(alert, animated: true)
    }

    private func performClear() {
        // 1️⃣ 强制停止 & 置空
        AudioPlayer.shared.stop()
        
        AudioPlayer.shared.clear() // 让 AVAudioPlayer 释放文件句柄

        // 2️⃣ 删除所有本地文件
        let docs = FileManager.default.urls(for: .documentDirectory,
                                            in: .userDomainMask)[0]
        (try? FileManager.default.contentsOfDirectory(at: docs,
                                                      includingPropertiesForKeys: nil))?
            .forEach { try? FileManager.default.removeItem(at: $0) }

        // 3️⃣ 清空数据 & UI
        tracks.removeAll()
        index = 0
        tableView.reloadData()
        nameLabel.text = "暂无歌曲"
        slider.value = 0
        timeLabel.text = "--:-- / --:--"
    }

    private func bindPlayState() {
        AudioPlayer.shared.onStateChange = { [weak self] in
            print("播放状态变更 \(AudioPlayer.shared.isPlaying)")
            guard let self = self else { return }
            self.playButton.setTitle(AudioPlayer.shared.isPlaying ? "⏸️" : "⏯️", for: .normal)
        }
    }

    private func updateLockScreen() {
        let image = UIImage(named: "HJCP") ?? UIImage(systemName: "music.note")!
        let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }

        let mpic = MPNowPlayingInfoCenter.default()
        mpic.nowPlayingInfo = [
            MPMediaItemPropertyTitle: tracks[index].name,
            MPMediaItemPropertyArtist: "Jx今夏",
            MPMediaItemPropertyArtwork: artwork,
            MPMediaItemPropertyPlaybackDuration: AudioPlayer.shared.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: AudioPlayer.shared.currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: 1.0
        ]
    }
}

extension PlayerViewController: ImportDelegate {
    func didImport(tracks: [Track]) {
        let wasEmpty = self.tracks.isEmpty
        
        // 已存在的歌名集合
        let existingNames = Set(self.tracks.map { $0.name })

        // 过滤新导入的重复歌名
        let uniqueTracks = tracks.filter { !existingNames.contains($0.name) }
        self.tracks.append(contentsOf: uniqueTracks)
        tableView.reloadData()

        if wasEmpty && !tracks.isEmpty {
            index = 0
            playCurrent()
        }

        
        // ✅ 目录导入后弹窗
        // 弹窗
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            let count = uniqueTracks.count
            if count == 0 {
                let alert = UIAlertController(title: "提示",
                                              message: "歌曲已存在，未重复导入",
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "好的", style: .default))
                self.present(alert, animated: true)
            } else {
                let alert = UIAlertController(title: "导入成功",
                                              message: "共导入 \(count) 首新歌",
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "好的", style: .default))
                self.present(alert, animated: true)
            }
        }
    }
}

// MARK: - UITableViewDataSource & Delegate
extension PlayerViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        tracks.count
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = tracks[indexPath.row].name
        cell.backgroundColor = (indexPath.row == index)
            ? UIColor.systemBlue.withAlphaComponent(0.2)
            : UIColor.clear
        return cell
    }

    func tableView(_ tableView: UITableView,
                   didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        index = indexPath.row
        playCurrent()
    }
}
