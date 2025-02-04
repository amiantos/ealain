//
//  ViewModel.swift
//  Ealain
//
//  Created by Brad Root on 2/2/25.
//

import Foundation

enum Orientation: String {
    case portrait = "portrait"
    case landscape = "landscape"
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

        let hordeApiKey: String = "0000000000"

        let framesPerSecond: Int = 30
        var orientation: Orientation = .landscape

        var frameCounter: Int = 0
        var urlRefreshCounter: Int = 0

        var urls: [String] = []
        var recentlyUsedUrls: [String] = []
        
        var currentlyGenerating: Bool = false

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
        
        func updateCurrentUrlStrings() {
            do {
                urls = try getCurrentImageUrlStrings()
            } catch {
                Log.error(error.localizedDescription)
            }
        }

        func start() {
            Log.debug("ViewModel start!")
            
            while true {
                updateCurrentUrlStrings()
                if urls.count < 2 {
                    Task {
                        await generateNewImages()
                    }
                } else {
                    delegate?.swapHiddenImage()
                    break
                }
            }
        }
        
        func animateOneFrame() {
            frameCounter += 1
            urlRefreshCounter += 1

            if frameCounter == 20 * framesPerSecond {
                Log.debug("20 seconds has passed")
                frameCounter = 0
            }

            if urlRefreshCounter == 3600 * framesPerSecond {
                Log.debug("One hour has passed.")
                urlRefreshCounter = 0
            }
        }


        func getImagesFolderURL() throws -> URL {
            let fileManager = FileManager.default

            guard
                let appSupportURL = fileManager.urls(
                    for: .applicationSupportDirectory, in: .userDomainMask
                ).first
            else {
                throw NSError(
                    domain: "FileManagerError", code: 1,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Failed to locate Application Support directory"
                    ])
            }

            let imagesFolderURL = appSupportURL.appendingPathComponent("Ealain").appendingPathComponent(self.orientation.rawValue)
            try fileManager.createDirectory(
                at: imagesFolderURL, withIntermediateDirectories: true,
                attributes: nil)

            return imagesFolderURL
        }

        func saveImageFromUrlString(_ urlString: String) async -> Bool {
            guard let url = URL(string: urlString) else {
                print("Invalid URL: \(urlString)")
                return false
            }

            do {
                // Fetch image data asynchronously
                let (data, _) = try await URLSession.shared.data(from: url)

                // Get the images folder path
                let imagesFolderURL = try getImagesFolderURL()

                // Determine file name and path
                let timestamp = Int(Date().timeIntervalSince1970)
                let originalFileName = url.deletingPathExtension().lastPathComponent // Remove extension from original name
                let fileExtension = url.pathExtension.isEmpty ? "webp" : url.pathExtension // Default to .webp if no extension
                let fileName = "\(timestamp)-\(originalFileName).\(fileExtension)"
                
                let fileURL = imagesFolderURL.appendingPathComponent(fileName)

                // Write data to file
                try data.write(to: fileURL)

                Log.debug("Image saved to: \(fileURL.path)")

                return true
            } catch {
                Log.error("Error saving image: \(error)")
            }
            
            return false
        }

        func getCurrentImageUrlStrings() throws -> [String] {
            let fileManager = FileManager.default
            let imagesFolderURL = try getImagesFolderURL()  // Reuse the function

            do {
                // Get contents of the directory
                let fileURLs = try fileManager.contentsOfDirectory(
                    at: imagesFolderURL, includingPropertiesForKeys: nil,
                    options: .skipsHiddenFiles)

                // Convert to an array of string paths
                return fileURLs.map { $0.absoluteString }.sorted()
            } catch {
                throw NSError(
                    domain: "FileManagerError", code: 2,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Failed to fetch image URLs: \(error)"
                    ])
            }
        }

        func generateNewImages() async{
            if currentlyGenerating {
                return
            }
            
            currentlyGenerating = true
            var currentRequestUUID: UUID?

            do {
                delegate?.updateStatusLabel(
                    "Submitting new image request to the AI Horde...")
                let requestResponse = try await hordeAPI.submitRequest(
                    apiKey: hordeApiKey,
                    request: HordeRequest(
                        prompt: " ",
                        style: "fb8abfab-e3cd-4790-8460-fe82cc7e44c0",
                        params: HordeParams(n: 2)))
                currentRequestUUID = requestResponse.id
                Log.debug(
                    "New generation request ID: \(String(describing: currentRequestUUID))"
                )
                delegate?.updateStatusLabel(
                    "Submitted new image request to the AI Horde")
            } catch APIError.requestFailed {
                delegate?.updateStatusLabel(
                    "Unable to communicate with the AI Horde")
            } catch APIError.requestTimedOut {
                delegate?.updateStatusLabel(
                    "Unable to communicate with the AI Horde")
            } catch let APIError.invalidResponse(statusCode, content) {
                Log.error(
                    "Received \(statusCode) from AI Horde API. \(content)")
                if statusCode == 429 {
                    delegate?.updateStatusLabel(
                        "The AI Horde is experiencing heavy loads, image generation will resume later."
                    )
                }
            } catch {
                Log.error("\(error)")
            }

            if let requestUUID = currentRequestUUID {
                var failures = 0
                while true {
                    do {
                        let requestResponse = try await hordeAPI.checkRequest(
                            apiKey: hordeApiKey, requestUUID: requestUUID)
                        Log.debug("\(requestResponse)")
                        if requestResponse.done {
                            delegate?.updateStatusLabel(
                                "Downloading new image...")
                            let finishedRequestResponse =
                                try await hordeAPI.fetchRequest(
                                    apiKey: hordeApiKey,
                                    requestUUID: requestUUID)
                            if let generations = finishedRequestResponse
                                .generations
                            {
                                delegate?.updateStatusLabel(
                                    "Storing new images...")
                                for generation in generations {
                                    _ = await saveImageFromUrlString(generation.img)
                                }
                            }
                            break
                        } else {
                            if !requestResponse.isPossible {
                                delegate?.updateStatusLabel(
                                    "Request can not be completed as sent.")
                            } else if requestResponse.processing == 0 {
                                if requestResponse.queuePosition > 0 {
                                    delegate?.updateStatusLabel(
                                        "Waiting... (#\(requestResponse.queuePosition) in queue)"
                                    )
                                } else {
                                    delegate?.updateStatusLabel("Waiting...")
                                }
                            } else {
                                delegate?.updateStatusLabel(
                                    "Image is generating...")
                            }
                            try await Task.sleep(nanoseconds: 3_000_000_000)
                        }
                    } catch APIError.requestTimedOut {
                        delegate?.updateStatusLabel(
                            "Unable to communicate with the AI Horde.")
                        break
                    } catch let APIError.invalidResponse(statusCode, content) {
                        Log.error(
                            "Received \(statusCode) from AI Horde API. \(content)"
                        )
                        failures += 1
                        if failures > 5 {
                            Log.error(
                                "Reached maximum failures, breaking polling loop."
                            )
                            break
                        }
                    } catch {
                        Log.error(
                            "Uknown error occurred when polling horde? \(error)"
                        )
                        break
                    }
                }
            }
            currentlyGenerating = false
        }

        //        private func fetchFreshImageUrls(firstLaunch: Bool = false) {
        //            Log.debug("Fetching fresh image URLs...")
        //            DispatchQueue.global(qos: .background).async {
        //                if let data = try? Data(
        //                    contentsOf: URL(
        //                        string: "https://ealain.s3.amazonaws.com/latest.json")!),
        //                    let urls = try? JSONDecoder().decode(
        //                        [String].self,
        //                        from: data
        //                    )
        //                {
        //                    self.urls = urls
        //                    if firstLaunch {
        //                        DispatchQueue.main.async {
        //                            self.delegate?.swapHiddenImage()
        //                        }
        //                    }
        //                }
        //            }
        //        }

        func getImageUrl() -> String {
            if urls.count == 1 {
                return urls[0]
            }

            if recentlyUsedUrls.count == urls.count {
                Log.debug(
                    "Image list exahusted, pruning recent urls by half...")
                recentlyUsedUrls.removeFirst(recentlyUsedUrls.count / 2)
            }

            guard var newUrl = urls.randomElement() else {
                fatalError("Failed to fetch a random image URL from the list!")
            }

            while recentlyUsedUrls.contains(newUrl) {
                guard let anotherUrl = urls.randomElement() else { break }
                newUrl = anotherUrl
            }

            recentlyUsedUrls.append(newUrl)
            return newUrl
        }

    }
}
