//
//  EalainImageView.swift
//  Ealain
//
//  Created by Brad Root on 6/14/23.
//

import Cocoa

class EalainImageView: NSView {

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func loadImage(url: URL) {
        DispatchQueue.global(qos: .background).async {
            if let data = try? Data(contentsOf: url),
                let image = NSImage(data: data)
            {
                DispatchQueue.main.async {
                    self.layer?.contents = image.layerContents(
                        forContentsScale: image.recommendedLayerContentsScale(
                            0.0))
                    self.layer?.contentsGravity = .resizeAspectFill
                }
            }
        }
    }
}
