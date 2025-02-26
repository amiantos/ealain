//
//  URLType.swift
//  Life Saver Screensaver
//
//  Created by Brad Root on 5/22/19.
//  Copyright © 2019 Brad Root. All rights reserved.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Cocoa

enum URLType: String {
    case brad = "https://bradroot.me"
    case github = "https://github.com/amiantos/ealain"
    case horde = "https://aihorde.net"
    case styles = "https://github.com/amiantos/ealain/blob/main/STYLES.md"
}

extension URLType {
    func open() {
        guard let url = URL(string: rawValue) else { return }
        NSWorkspace.shared.open(url)
    }
}
