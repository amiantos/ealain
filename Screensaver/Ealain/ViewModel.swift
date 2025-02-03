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
        
        let hordeApiKey: String = "0000000000"

        let framesPerSecond: Int = 30
        var orientation: Orientation = .landscape

        var frameCounter: Int = 0
        var urlRefreshCounter: Int = 0

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
            
            do {
                let imageUrls = try getAllImageUrls()
                print("Image URLs: \(imageUrls)")
                urls = imageUrls
                if urls.isEmpty {
                    Task {
                        await getRandomImage()
                    }
                } else {
                    delegate?.swapHiddenImage()
                    delegate?.updateStatusLabel("")
                }
            } catch {
                print("Error retrieving image URLs: \(error)")
            }
        }
        
        func getImagesFolderURL() throws -> URL {
            let fileManager = FileManager.default
            
            guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
                throw NSError(domain: "FileManagerError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to locate Application Support directory"])
            }
            
            let imagesFolderURL = appSupportURL.appendingPathComponent("Ealain")
            try fileManager.createDirectory(at: imagesFolderURL, withIntermediateDirectories: true, attributes: nil)

            return imagesFolderURL
        }
        
        func saveImageFromUrlString(_ urlString: String) async {
            guard let url = URL(string: urlString) else {
                print("Invalid URL: \(urlString)")
                return
            }

            do {
                // Fetch image data asynchronously
                let (data, _) = try await URLSession.shared.data(from: url)

                // Get the images folder path
                let imagesFolderURL = try getImagesFolderURL()

                // Determine file name and path
                let fileName = url.lastPathComponent.isEmpty ? UUID().uuidString + ".webp" : url.lastPathComponent
                let fileURL = imagesFolderURL.appendingPathComponent(fileName)

                // Write data to file
                try data.write(to: fileURL)

                Log.debug("Image saved to: \(fileURL.path)")
                
                // Update URLs (assuming `urls` is globally accessible)
                urls.append(fileURL.absoluteString)

//                // Dispatch UI update on the main thread
//                await MainActor.run {
//                    self.delegate?.swapHiddenImage()
//                }
            } catch {
                print("Error saving image: \(error)")
            }
        }
        
        func getAllImageUrls() throws -> [String] {
            let fileManager = FileManager.default
            let imagesFolderURL = try getImagesFolderURL() // Reuse the function

            do {
                // Get contents of the directory
                let fileURLs = try fileManager.contentsOfDirectory(at: imagesFolderURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)

                // Convert to an array of string paths
                return fileURLs.map { $0.absoluteString }
            } catch {
                throw NSError(domain: "FileManagerError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch image URLs: \(error)"])
            }
        }
        
        func getRandomImage() async {
            var currentRequestUUID: UUID?
            
            do {
                let requestResponse = try await hordeAPI.submitRequest(apiKey: hordeApiKey, request: HordeRequest(prompt: " ", style: "fb8abfab-e3cd-4790-8460-fe82cc7e44c0"))
                currentRequestUUID = requestResponse.id
                Log.debug("New generation request ID: \(String(describing: currentRequestUUID))")
                delegate?.updateStatusLabel("Submitted new image request to the AI Horde")
            } catch APIError.requestFailed {
                delegate?.updateStatusLabel("Unable to communicate with the AI Horde")
            } catch APIError.requestTimedOut {
                delegate?.updateStatusLabel("Unable to communicate with the AI Horde")
            } catch let APIError.invalidResponse(statusCode, content) {
                Log.error("Received \(statusCode) from AI Horde API. \(content)")
                if statusCode == 429 {
                    delegate?.updateStatusLabel("The AI Horde is experiencing heavy loads, image generation will resume later.")
                }
            } catch {
                Log.error("\(error)")
            }
            
            if let requestUUID = currentRequestUUID {
                var failures = 0
                while true {
                    do {
                        let requestResponse = try await hordeAPI.checkRequest(apiKey: hordeApiKey, requestUUID: requestUUID)
                        Log.debug("\(requestResponse)")
                        if requestResponse.done {
                            delegate?.updateStatusLabel("Downloading new image...")
                            let finishedRequestResponse = try await hordeAPI.fetchRequest(apiKey: hordeApiKey, requestUUID: requestUUID)
                            if let generation = finishedRequestResponse.generations?.first {
                                Log.debug(generation.img)
                                await saveImageFromUrlString(generation.img)
                                delegate?.updateStatusLabel("Storing new image...")
                                break
                            }
                            break
                        } else {
                            if !requestResponse.isPossible {
                                delegate?.updateStatusLabel("Request can not be completed as sent.")
                            } else if requestResponse.processing == 0 {
                                if requestResponse.queuePosition > 0 {
                                    delegate?.updateStatusLabel("Waiting... (#\(requestResponse.queuePosition) in queue)")
                                } else {
                                    delegate?.updateStatusLabel("Waiting...")
                                }
                            } else {
                                delegate?.updateStatusLabel("Image is generating...")
                            }
                            try await Task.sleep(nanoseconds: 3_000_000_000)
                        }
                    } catch APIError.requestTimedOut {
                        delegate?.updateStatusLabel("Unable to communicate with the AI Horde.")
                        break
                    } catch let APIError.invalidResponse(statusCode, content) {
                        Log.error("Received \(statusCode) from AI Horde API. \(content)")
                        failures += 1
                        if failures > 5 {
                            Log.error("Reached maximum failures, breaking polling loop.")
                            break
                        }
                    } catch {
                        Log.error("Uknown error occurred when polling horde? \(error)")
                        break
                    }
                }
            }
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
            
            if recentUrls.count == urls.count {
                Log.debug(
                    "Image list exahusted, pruning recent urls by half...")
                recentUrls.removeFirst(recentUrls.count / 2)
            }

            guard var newUrl = urls.randomElement() else {
                fatalError("Failed to fetch a random image URL from the list!")
            }

            while recentUrls.contains(newUrl) {
                guard let anotherUrl = urls.randomElement() else { break }
                newUrl = anotherUrl
            }

            recentUrls.append(newUrl)
            return newUrl
        }

    }
}
