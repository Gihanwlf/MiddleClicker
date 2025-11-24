import Cocoa
import CoreGraphics

// Global drag state tracker
var isMiddleClicking = false

// The event tap callback function
func callback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    
    // 1. Handle Dragging and Mouse Up if we are currently in a "Middle Click" state
    if isMiddleClicking {
        if type == .leftMouseDragged {
            // Create a new Middle Mouse Dragged event
            if let newEvent = CGEvent(mouseEventSource: nil, mouseType: .otherMouseDragged, mouseCursorPosition: event.location, mouseButton: .center) {
                newEvent.timestamp = event.timestamp
                return Unmanaged.passRetained(newEvent)
            }
        } else if type == .leftMouseUp {
            // End the middle click
            isMiddleClicking = false
            if let newEvent = CGEvent(mouseEventSource: nil, mouseType: .otherMouseUp, mouseCursorPosition: event.location, mouseButton: .center) {
                newEvent.timestamp = event.timestamp
                return Unmanaged.passRetained(newEvent)
            }
        }
        // If we are middle clicking, swallow strictly related left-mouse events
        return nil
    }

    // 2. Detect the Start of a Click (Fn + Left Mouse Down)
    if type == .leftMouseDown {
        let flags = event.flags
        // Check if Fn key is pressed (SecondaryFn)
        if flags.contains(.maskSecondaryFn) {
            isMiddleClicking = true
            
            // Create a new Middle Mouse Down event
            if let newEvent = CGEvent(mouseEventSource: nil, mouseType: .otherMouseDown, mouseCursorPosition: event.location, mouseButton: .center) {
                newEvent.timestamp = event.timestamp
                return Unmanaged.passRetained(newEvent)
            }
            // Swallow the original left click
            return nil
        }
    }

    // Pass all other events through unchanged
    return Unmanaged.passUnretained(event)
}

// Application Delegate to handle Menu Bar
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create Menu Bar Item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "M" // Icon for Middle Clicker
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit MiddleClicker", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem.menu = menu

        // Request Accessibility Permissions
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String : true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)

        if !accessEnabled {
            print("Access not enabled. Please grant permissions in System Settings > Privacy & Security > Accessibility")
        }

        // Create the Event Tap
        let eventMask = (1 << CGEventType.leftMouseDown.rawValue) | (1 << CGEventType.leftMouseUp.rawValue) | (1 << CGEventType.leftMouseDragged.rawValue)
        
        guard let eventTap = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                               place: .headInsertEventTap,
                                               options: .defaultTap,
                                               eventsOfInterest: CGEventMask(eventMask),
                                               callback: callback,
                                               userInfo: nil) else {
            print("Failed to create event tap")
            exit(1)
        }

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(self)
    }
}

// Main Entry Point
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // Hides from Dock
app.run()
