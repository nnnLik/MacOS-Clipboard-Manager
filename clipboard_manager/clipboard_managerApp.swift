import AppKit
import Carbon
import Combine
import ServiceManagement
import SwiftUI

@main
struct ClipboardManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate


    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var eventMonitor: Any?
    private var hotKeyRef: EventHotKeyRef?

    private let historyStore = ClipboardHistoryStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()
        setupPopover()
        setupEventMonitor()
        registerGlobalHotKey()
        registerLaunchAtLogin()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "doc.on.clipboard",
                accessibilityDescription: "Clipboard Manager")
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
    }

    private func setupPopover() {
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 300, height: 320)
        let rootView = ContentView()
            .environmentObject(historyStore)
        popover.contentViewController = NSHostingController(rootView: rootView)
    }

    private func setupEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [
            .leftMouseDown, .rightMouseDown,
        ]) { [weak self] event in
            guard let self, self.popover.isShown else { return }
            self.popover.performClose(event)
        }
    }

    @objc
    private func togglePopover(_ sender: Any?) {
        if popover.isShown {
            popover.performClose(sender)
        } else if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func registerGlobalHotKey() {
        let keyCode: UInt32 = 9  // V
        let modifiers: UInt32 = UInt32(cmdKey | shiftKey)

        var eventHotKeyRef: EventHotKeyRef?
        let eventHotKeyID = EventHotKeyID(
            signature: OSType(UInt32(truncatingIfNeeded: "CLPB".hashValue)),
            id: 1)

        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            eventHotKeyID,
            GetEventDispatcherTarget(),
            0,
            &eventHotKeyRef
        )

        guard status == noErr, let eventHotKeyRef else {
            return
        }

        hotKeyRef = eventHotKeyRef

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed))

        let selfPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        InstallEventHandler(
            GetEventDispatcherTarget(),
            { (_, _, userData) -> OSStatus in
                guard let userData else { return noErr }
                let delegate = Unmanaged<AppDelegate>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
                delegate.handleHotKey()
                return noErr
            },
            1,
            &eventType,
            selfPointer,
            nil
        )
    }

    private func handleHotKey() {
        DispatchQueue.main.async { [weak self] in
            self?.togglePopover(nil)
        }
    }

    private func registerLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            do {
                try SMAppService.mainApp.register()
            } catch {
            }
        }
    }
}
