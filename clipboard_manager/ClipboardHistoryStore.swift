import Foundation
import Combine
import AppKit

struct ClipboardItem: Identifiable {
    let id: UUID
    let content: String
    let date: Date

    init(content: String, date: Date, id: UUID = UUID()) {
        self.id = id
        self.content = content
        self.date = date
    }
}

final class ClipboardHistoryStore: ObservableObject {
    @Published private(set) var items: [ClipboardItem] = []

    private let pasteboard = NSPasteboard.general
    private var changeCount: Int
    private var timer: Timer?
    private let maxItems = 50
    private let workQueue = DispatchQueue(label: "clipboard.check", qos: .utility)

    init() {
        changeCount = pasteboard.changeCount
        startMonitoring()
    }

    deinit {
        timer?.invalidate()
    }

    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.scheduleCheck()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    /// Только диспатч в фоновую очередь — главный поток не блокируется чтением pasteboard.
    private func scheduleCheck() {
        workQueue.async { [weak self] in
            self?.checkPasteboard()
        }
    }

    private func checkPasteboard() {
        let currentChangeCount = pasteboard.changeCount
        guard currentChangeCount != changeCount else { return }

        guard let string = pasteboard.string(forType: .string),
              !string.isEmpty else {
            changeCount = currentChangeCount
            return
        }

        changeCount = currentChangeCount
        let newItem = ClipboardItem(content: string, date: Date())

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.items.first?.content == string { return }
            self.items.insert(newItem, at: 0)
            if self.items.count > self.maxItems {
                self.items.removeLast(self.items.count - self.maxItems)
            }
        }
    }

    func recopy(_ item: ClipboardItem) {
        pasteboard.clearContents()
        pasteboard.setString(item.content, forType: .string)
    }

    func moveToTop(_ item: ClipboardItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.items.remove(at: index)
            self.items.insert(item, at: 0)
            self.changeCount = self.pasteboard.changeCount
        }
    }

    func clearHistory() {
        DispatchQueue.main.async { [weak self] in
            self?.items.removeAll()
            self?.pasteboard.clearContents()
        }
    }
}

