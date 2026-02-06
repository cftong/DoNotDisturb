//
//  file: AboutWindowController.swift
//  project: DND (main app)
//  description: 'about' window controller
//
//  created by Dharmesh Tarapore
//  copyright (c) 2026 Objective-See. All rights reserved.
//

import Cocoa

// Button tag constants (from Consts.h)
private let kButtonSupportUs = 100
private let kButtonMoreInfo = 101

// URL constants (from Consts.h)
private let kPatreonURL = "https://www.patreon.com/bePatron?c=701171"
private let kProductURL = "https://objective-see.com/products/dnd.html"

@objc class AboutWindowController: NSWindowController, NSWindowDelegate {

    // version label/string
    @IBOutlet weak var versionLabel: NSTextField!

    // patrons
    @IBOutlet var patrons: NSTextView!

    // automatically called when nib is loaded
    // center window
    override func awakeFromNib() {
        super.awakeFromNib()
        window?.center()
    }

    // automatically invoked when window is loaded
    // set to white
    override func windowDidLoad() {
        super.windowDidLoad()

        // not in mojave dark mode?
        // make window color white
        if !isDarkMode() {
            window?.backgroundColor = .white
        }

        // grab app version
        let version = getAppVersion() ?? "unknown"

        // set version string
        versionLabel.stringValue = version

        // load patrons
        // <3 you guys & girls
        if let path = Bundle.main.path(forResource: "patrons", ofType: "txt"),
           let content = try? String(contentsOfFile: path, encoding: .utf8) {
            patrons.string = content
        } else {
            patrons.string = "error: failed to load patrons :/"
        }
    }

    // automatically invoked when window is closing
    // make window unmodal
    func windowWillClose(_ notification: Notification) {
        NSApplication.shared.stopModal()
    }

    // automatically invoked when user clicks any of the buttons
    // perform actions, such as loading patreon or products URL
    @IBAction func buttonHandler(_ sender: Any) {
        guard let button = sender as? NSButton else { return }

        // support us button
        if button.tag == kButtonSupportUs {
            // open URL
            // invokes user's default browser
            if let url = URL(string: kPatreonURL) {
                NSWorkspace.shared.open(url)
            }
        }
        // more info button
        else if button.tag == kButtonMoreInfo {
            // open URL
            // invokes user's default browser
            if let url = URL(string: kProductURL) {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
