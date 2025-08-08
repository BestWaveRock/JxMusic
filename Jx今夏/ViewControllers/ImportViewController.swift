//
//  ImportViewController.swift
//  Jx今夏
//
//  Created by 嘉煦 on 2025/8/7.
//

//import SwiftUI
//
//struct ImportViewController: View {
//    var body: some View {
//        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
//    }
//}
//
//struct ImportViewController_Previews: PreviewProvider {
//    static var previews: some View {
//        ImportViewController()
//    }
//}

import UIKit
import UniformTypeIdentifiers

protocol ImportDelegate: AnyObject {
    func didImport(tracks: [Track])
}

class ImportViewController: UIViewController {
    weak var delegate: ImportDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "导入音乐"
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(importTapped))
        
        // ✅ 进入页面即自动弹出目录选择器
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.importTapped()
        }
    }

    @objc private func importTapped() {
        let supportedTypes: [UTType] = [
            UTType.mp3,
            UTType.types(tag: "m4a", tagClass: .filenameExtension, conformingTo: .audio).first,
            UTType.types(tag: "flac", tagClass: .filenameExtension, conformingTo: .audio).first
        ].compactMap { $0 }
//        let supportedTypes: [UTType] = [UTType.mp3, UTType(filenameExtension: "m4a"), UTType(filenameExtension: "flac")!]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])   // 选目录
        picker.delegate = self
        picker.allowsMultipleSelection = false   // 只需要一次选一个目录
        present(picker, animated: true)    }
}

extension ImportViewController: UIDocumentPickerDelegate {
//    func documentPicker(_ controller: UIDocumentPickerViewController,
//                        didPickDocumentsAt urls: [URL]) {
//
//        let docs = FileManager.default
//            .urls(for: .documentDirectory, in: .userDomainMask)[0]
//
//        var newTracks: [Track] = []
//
//        for srcURL in urls {
//            guard srcURL.startAccessingSecurityScopedResource() else { continue }
//            defer { srcURL.stopAccessingSecurityScopedResource() }
//
//            let dstURL = docs.appendingPathComponent(srcURL.lastPathComponent)
//            _ = try? FileManager.default.removeItem(at: dstURL)
//
//            do {
//                try FileManager.default.copyItem(at: srcURL, to: dstURL)
//                newTracks.append(Track(url: dstURL))
//            } catch {
//                print("拷贝失败：\(error)")
//            }
//        }
//
//        // 一次性把新曲目追加给播放器
//        if !newTracks.isEmpty {
//            delegate?.didImport(tracks: newTracks)
//
//            // 完成后直接关闭
//            self.dismiss(animated: true, completion: nil)
//        }
//    }
    func documentPicker(_ controller: UIDocumentPickerViewController,
                            didPickDocumentsAt urls: [URL]) {
        guard let folder = urls.first else { return }

        // 安全域
        guard folder.startAccessingSecurityScopedResource() else { return }
        defer { folder.stopAccessingSecurityScopedResource() }

        let docs = FileManager.default.urls(for: .documentDirectory,
                                            in: .userDomainMask)[0]
        var newTracks: [Track] = []

        let keys: [URLResourceKey] = [.isRegularFileKey]
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
                at: folder,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles]) else { return }

        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: Set(keys)),
                  resourceValues.isRegularFile == true else { continue }

            let ext = fileURL.pathExtension.lowercased()
            if ["mp3", "m4a", "flac"].contains(ext) {
                let dst = docs.appendingPathComponent(fileURL.lastPathComponent)
                do {
                    if fm.fileExists(atPath: dst.path) { try fm.removeItem(at: dst) }
                    try fm.copyItem(at: fileURL, to: dst)
                    newTracks.append(Track(url: dst))
                } catch {
                    print("❌ 拷贝失败: \(error.localizedDescription)")
                }
            }
        }

        delegate?.didImport(tracks: newTracks)
        self.dismiss(animated: true)
    }
    
    /// 递归收集目录下所有 mp3 / flac
    private func scanDirectory(_ url: URL) -> [Track] {
        let fm = FileManager.default
        let resourceKeys: [URLResourceKey] = [.isRegularFileKey]
        var result: [Track] = []

        guard let enumerator = fm.enumerator(
                at: url,
                includingPropertiesForKeys: resourceKeys,
                options: [.skipsHiddenFiles]) else { return [] }

        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: Set(resourceKeys)),
                  resourceValues.isRegularFile == true else { continue }

            let ext = fileURL.pathExtension.lowercased()
            
            if ["mp3", "m4a", "flac"].contains(ext) {
                // 拷贝到沙盒再生成 Track
                let docs = FileManager.default.urls(for: .documentDirectory,
                                                    in: .userDomainMask)[0]
                let dst = docs.appendingPathComponent(fileURL.lastPathComponent)
                _ = try? FileManager.default.removeItem(at: dst)
                try? FileManager.default.copyItem(at: fileURL, to: dst)
                result.append(Track(url: dst))
            }
        }
        return result
    }
}
