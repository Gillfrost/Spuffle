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
        let debugController = LogViewController()
        let navController = UINavigationController(rootViewController: debugController)

        debugController.title = "Logs"

        self.present(navController, animated: true)
    }
}

private final class LogViewController: UITableViewController {

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium

        return formatter
    }()

    var reuseIdentifier: String { #function }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: reuseIdentifier)

        NotificationCenter.default
            .addObserver(tableView!,
                         selector: #selector(UITableView.reloadData),
                         name: UIApplication.didBecomeActiveNotification,
                         object: nil)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Log.logs.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath)

        let log = Log.logs[indexPath.row]

        let date = dateFormatter.string(from: log.date)
        cell.textLabel?.text = "\(date) \(log.message)"
        cell.contentView.backgroundColor = backgroundColor(for: log.level)

        return cell
    }

    private func backgroundColor(for level: Log.Level) -> UIColor {
        switch level {
        case .error:
            return UIColor.red.withAlphaComponent(0.25)
        case .info:
            return UIColor.green.withAlphaComponent(0.15)
        }
    }
}

#endif
