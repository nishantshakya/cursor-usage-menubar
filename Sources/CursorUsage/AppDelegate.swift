import AppKit
import Combine
import SwiftUI

final class AppState: ObservableObject {
    @Published var usageData: UsageData?
    @Published var error: String?
    @Published var isLoading = false

    private let service = UsageService()
    private var refreshTimer: Timer?
    private var refreshInterval: TimeInterval = 900

    func start(config: AppConfig) {
        refreshInterval = config.refreshInterval
        refresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func refresh() {
        Task { @MainActor in
            isLoading = true
            do {
                usageData = try await service.fetchUsage()
                error = nil
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private let appState = AppState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let config = AppConfig.load()
        appState.start(config: config)

        setupStatusItem()
        setupPopover()
        observeSummary()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }
        button.image = StatusBarChart.makeImage(percent: nil, isError: false)
        button.imagePosition = .imageOnly
        button.title = ""
        button.action = #selector(togglePopover)
        button.target = self
    }

    private func setupPopover() {
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 340)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: UsageView().environmentObject(appState)
        )
        self.popover = popover
    }

    private func observeSummary() {
        appState.$usageData
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateStatusDisplay() }
            .store(in: &cancellables)
        appState.$error
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateStatusDisplay() }
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()

    private func updateStatusDisplay() {
        guard let button = statusItem?.button else { return }
        button.title = ""
        button.imagePosition = .imageOnly
        if appState.error != nil {
            button.image = StatusBarChart.makeImage(percent: nil, isError: true)
        } else if let data = appState.usageData {
            button.image = StatusBarChart.makeImage(percent: data.dailyUsagePercent, isError: false)
        } else {
            button.image = StatusBarChart.makeImage(percent: nil, isError: false)
        }
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button, let popover else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
