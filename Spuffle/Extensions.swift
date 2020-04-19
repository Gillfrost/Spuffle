//
//  Extensions.swift
//  Spuffle
//
//  Created by André on 2020-04-16.
//

import UIKit

#if DEBUG

extension UIViewController {

    func addDebugButton() {
        let button = UIButton(type: .system)

        button.addTarget(self,
                         action: #selector(showDebugController),
                         for: .touchUpInside)

        button.setTitle("Debug", for: .normal)
        button.setTitleColor(.white, for: .normal)

        button.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(button)
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            button.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
        ])
    }

    @objc private func showDebugController() {
        let debugController = UIViewController()
        debugController.view.backgroundColor = .white

        self.present(debugController, animated: true)
    }
}

#endif
