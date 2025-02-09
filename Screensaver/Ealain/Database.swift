//
//  Database.swift
//  MultiClock
//
//  Created by Brad Root on 1/8/22.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.

import SpriteKit

struct Database {
    fileprivate enum Key {
        static let styleIdOverride = "ealainStyleIdOverride"
    }

    static var standard: UserDefaults {
        var database = UserDefaults.standard
        if let customDatabase = UserDefaults(
            suiteName: "net.amiantos.MultiClockScreensaverSettings")
        {
            database = customDatabase
        }

        database.register(defaults: [
            Key.styleIdOverride: ""
        ])

        return database
    }
}

extension UserDefaults {

    // Getters

    var styleIdOverride: String {
        return string(forKey: Database.Key.styleIdOverride) ?? ""
    }

    // Setters

    func set(styleIdOverride: String) {
        set(styleIdOverride, for: Database.Key.styleIdOverride)
    }

}

extension UserDefaults {
    fileprivate func set(_ object: Any?, for key: String) {
        set(object, forKey: key)
        synchronize()
    }
}
