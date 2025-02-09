//
//  ConfigureSheetController.swift
//  Life Saver Screensaver
//
//  Created by Brad Root on 5/21/19.
//  Copyright © 2019 Brad Root. All rights reserved.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Cocoa
import SpriteKit

final class ConfigureSheetController: NSObject {
//    private let manager = Manager()

    // MARK: - Config Actions and Outlets

    @IBOutlet var window: NSWindow?


    @IBAction func closeButtonAction(_ sender: NSButton) {
        guard let window = window else { return }
        window.sheetParent?.endSheet(window)
    }
    
    @IBAction func gitHubLinkAction(_ sender: NSButton) {
        URLType.github.open()
    }
    
    @IBAction func bradLinkAction(_ sender: NSButton) {
        URLType.brad.open()
    }
    
    @IBAction func aiHordeLinkAction(_ sender: NSButton) {
        URLType.horde.open()
    }
    
    @IBAction func styleLinkAction(_sender: NSButton) {
        URLType.styles.open()
    }
    
    @IBOutlet weak var styleOverrideTextField: NSTextField!
    @IBAction func saveButtonClicked(_ sender: NSButton) {
        Database.standard.set(styleIdOverride: styleOverrideTextField.stringValue)
        
        let alert = NSAlert()
        alert.messageText = "Save Successful"
        alert.informativeText = "Your style override has been saved."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    // MARK: - View Setup

    override init() {
        super.init()
        let myBundle = Bundle(for: ConfigureSheetController.self)
        myBundle.loadNibNamed("ConfigureSheet", owner: self, topLevelObjects: nil)
        
        loadSettings()
    }
    
    fileprivate func loadSettings() {
        styleOverrideTextField.stringValue = Database.standard.styleIdOverride
    }
}
