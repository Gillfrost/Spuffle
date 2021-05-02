//  Copyright (c) 2021 André Gillfrost
//  Licensed under the MIT license

import UIKit
import SwiftUI
import Combine

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
        let logView = LogView(viewModel: .init(logs: Log.logs))
        let logViewController = UIHostingController(rootView: logView)
        let navController = UINavigationController(rootViewController: logViewController)

        logViewController.title = "Logs"

        self.present(navController, animated: true)
    }
}

extension Log: Identifiable {

    var id: Int {
        hashValue
    }
}

final class LogViewModel: ObservableObject {

    @Published private (set) var logs: [Log] = []

    private var cancellable: AnyCancellable?

    init(logs: AnyPublisher<[Log], Never>) {
        cancellable = logs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] logs in
                self?.logs = logs.reversed()
            }
    }
}

private struct LogView: View {

    @ObservedObject var viewModel: LogViewModel

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium

        return formatter
    }()

    var body: some View {
        List(viewModel.logs, rowContent: logRow)
    }

    private func logRow(log: Log) -> some View {
        let date = LogView.dateFormatter.string(from: log.date)
        let text = "\(date) \(log.message)"

        return ZStack(alignment: .leading) {
            Color(backgroundColor(for: log.level))
            Text(text)
        }
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

struct Extensions_Previews: PreviewProvider {
    static var previews: some View {
        LogView(
            viewModel: LogViewModel(
                logs: Just([
                    .init(date: .init(),
                          level: .info,
                          message: "info",
                          location: nil),
                    .init(date: .init(),
                          level: .error,
                          message: "error",
                          location: nil)
                ])
                .eraseToAnyPublisher()
            )
        )
    }
}

#endif
