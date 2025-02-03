//
//  ViewModel.swift
//  Ealain
//
//  Created by Brad Root on 2/2/25.
//

import Foundation

enum Orientation {
    case portrait
    case landscape
}

enum ImageType {
    case top
    case bottom
}

extension EalainView {
    protocol ViewModelDelegate {
        func updateStatusLabel(_ text: String)
        func swapHiddenImage()
        func swapImageViews()
    }

    class ViewModel {
        let hordeAPI: HordeAPI = .init()
        var delegate: ViewModelDelegate?

        let framesPerSecond: Int = 30
        var orientation: Orientation = .landscape

        var frameCounter: Int = 0
        var urlRefreshCounter: Int = 0

        var currentUrlTop: String = ""
        var currentUrlBottom: String = ""
        var urls: [String] = []
        var recentUrls: [String] = []

        init(delegate: ViewModelDelegate? = nil) {
            self.delegate = delegate
        }

        func setOrientation(_ orientation: Orientation) {
            if self.orientation == orientation {
                return
            }

            self.orientation = orientation
            Log.debug("Orientation changed to \(orientation)!")
        }

        func animateOneFrame() {
            frameCounter += 1
            urlRefreshCounter += 1

            if frameCounter == 20 * framesPerSecond {
                Log.debug("20 seconds has passed")
                self.delegate?.swapImageViews()
                frameCounter = 0
            }

            if urlRefreshCounter == 3600 * framesPerSecond {
                Log.debug("One hour has passed.")
                urlRefreshCounter = 0
            }
        }

        func start() {
            Log.debug("ViewModel start!")
            fetchFreshImageUrls(firstLaunch: true)
        }

        private func fetchFreshImageUrls(firstLaunch: Bool = false) {
            Log.debug("Fetching fresh image URLs...")
            DispatchQueue.global(qos: .background).async {
                if let data = try? Data(
                    contentsOf: URL(
                        string: "https://ealain.s3.amazonaws.com/latest.json")!),
                    let urls = try? JSONDecoder().decode(
                        [String].self,
                        from: data
                    )
                {
                    self.urls = urls
                    if firstLaunch {
                        DispatchQueue.main.async {
                            self.delegate?.swapHiddenImage()
                        }
                    }
                }
            }
        }

        func getImageUrl(for imageType: ImageType) -> String {
            if recentUrls.count == urls.count {
                Log.debug(
                    "Image list exahusted, pruning recent urls by half...")
                recentUrls.removeFirst(recentUrls.count / 2)
            }

            if imageType == .bottom {
                while true {
                    guard let newUrl = urls.randomElement() else { break }
                    if recentUrls.firstIndex(of: newUrl) == nil {
                        currentUrlTop = newUrl
                        break
                    }
                }
                recentUrls.append(currentUrlTop)
                return currentUrlTop
            } else {
                while true {
                    guard let newUrl = urls.randomElement() else { break }
                    if recentUrls.firstIndex(of: newUrl) == nil {
                        currentUrlBottom = newUrl
                        break
                    }
                }
                recentUrls.append(currentUrlBottom)
                return currentUrlBottom
            }
        }

    }
}
