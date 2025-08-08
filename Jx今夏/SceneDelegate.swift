//
//  SceneDelegate.swift
//  Jx今夏
//
//  Created by 嘉煦 on 2025/8/7.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let winScene = scene as? UIWindowScene else { return }
        window = UIWindow(windowScene: winScene)
        window?.rootViewController = UINavigationController(rootViewController: PlayerViewController())
        window?.makeKeyAndVisible()
    }
}
