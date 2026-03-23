import AppKit
import Carbon
import Foundation

final class GlobalHotKeyManager {
    var onTrigger: ((TranslationAction) -> Void)?

    private var eventHandlerRef: EventHandlerRef?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var registrations: [TranslationAction: RegisteredHotKey] = [:]
    private var actionByHotKeyID: [UInt32: TranslationAction] = [:]
    private var lastTriggerTimes: [TranslationAction: TimeInterval] = [:]
    private static let signature: OSType = 0x49535452
    private static let triggerDebounceInterval: TimeInterval = 0.35

    init() {
        installHandler()
        installEventMonitors()
    }

    deinit {
        unregisterAll()
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
        removeEventMonitors()
    }

    @discardableResult
    func register(_ preset: HotKeyPreset, for action: TranslationAction) -> Result<Void, HotKeyRegistrationError> {
        unregister(action)

        let hotKeyID = EventHotKeyID(signature: Self.signature, id: action.hotKeyID)
        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            preset.keyCode,
            preset.carbonModifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr else {
            actionByHotKeyID[action.hotKeyID] = nil
            lastTriggerTimes[action] = 0
            if status == eventHotKeyExistsErr {
                return .failure(.alreadyInUse(preset))
            }
            return .failure(.systemError(status: status, preset: preset))
        }

        guard let hotKeyRef else {
            return .failure(.systemError(status: OSStatus(noTypeErr), preset: preset))
        }

        registrations[action] = RegisteredHotKey(preset: preset, hotKeyRef: hotKeyRef)
        actionByHotKeyID[action.hotKeyID] = action
        return .success(())
    }

    func unregister(_ action: TranslationAction) {
        if let registration = registrations.removeValue(forKey: action) {
            UnregisterEventHotKey(registration.hotKeyRef)
        }
        actionByHotKeyID[action.hotKeyID] = nil
        lastTriggerTimes[action] = 0
    }

    func unregisterAll() {
        for action in TranslationAction.allCases {
            unregister(action)
        }
    }

    private func installHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, event, userData in
                guard
                    let event,
                    let userData
                else {
                    return noErr
                }

                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                guard
                    status == noErr,
                    hotKeyID.signature == GlobalHotKeyManager.signature
                else {
                    return noErr
                }

                let manager = Unmanaged<GlobalHotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                guard let action = manager.actionByHotKeyID[hotKeyID.id] else {
                    return noErr
                }

                manager.trigger(action)
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )
    }

    private func installEventMonitors() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleMonitoredEvent(event)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleMonitoredEvent(event)
            return event
        }
    }

    private func removeEventMonitors() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }

        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }

    private func handleMonitoredEvent(_ event: NSEvent) {
        guard !event.isARepeat else {
            return
        }

        let modifierFlags = event.modifierFlags.intersection([.command, .option, .shift, .control])
        for (action, registration) in registrations {
            guard UInt32(event.keyCode) == registration.preset.keyCode else {
                continue
            }

            guard modifierFlags == registration.preset.eventModifiers else {
                continue
            }

            trigger(action)
            return
        }
    }

    private func trigger(_ action: TranslationAction) {
        let now = ProcessInfo.processInfo.systemUptime
        let lastTriggerTime = lastTriggerTimes[action] ?? 0
        guard now - lastTriggerTime > Self.triggerDebounceInterval else {
            return
        }

        lastTriggerTimes[action] = now
        onTrigger?(action)
    }
}

private struct RegisteredHotKey {
    let preset: HotKeyPreset
    let hotKeyRef: EventHotKeyRef
}
