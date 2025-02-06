import Foundation
import ScreenSaver

enum Orientation: String {
    case portrait = "portrait"
    case landscape = "landscape"
}

class EalainView: ScreenSaverView {

    private let hordeAPI: HordeAPI = .init()
    private let hordeApiKey: String = "0000000000"

    private var urls: [String] = []
    private var recentlyUsedUrls: [String] = []

    private var orientation: Orientation = .landscape

    private let bottomImageView = EalainImageView()
    private let topImageView = EalainImageView()

    private let statusLabelView = NSView()
    private let statusLabel = NSTextField(
        labelWithString:
            "Ealain requires internet access to function. Please wait...")
    private let statusLabelShadow = NSShadow()

    private var fadeOutTimer: Timer?

    private var animationRunning: Bool = false

    private var currentlyGenerating: Bool = false

    private var swapTimer: Timer?

    override init?(frame: CGRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)

        Log.logLevel = .debug

        addSubview(bottomImageView)
        addSubview(topImageView)
        topImageView.layer?.opacity = 0
        bottomImageView.layer?.opacity = 0

        addSubview(statusLabelView)
        statusLabelView.wantsLayer = true
        statusLabelView.addSubview(statusLabel)
        statusLabel.textColor = .white
        let fontSize: CGFloat = isPreview ? 10 : 16
        statusLabel.font = .systemFont(ofSize: fontSize, weight: .medium)
        statusLabel.sizeToFit()
        statusLabel.maximumNumberOfLines = 2
        statusLabelView.layer?.opacity = 0

        statusLabelShadow.shadowColor = NSColor.black
        statusLabelShadow.shadowOffset = CGSize(width: 2, height: 2)
        statusLabelShadow.shadowBlurRadius = 3
        statusLabel.shadow = statusLabelShadow

        DistributedNotificationCenter.default.addObserver(
            self,
            selector: #selector(EalainView.willStop(_:)),
            name: Notification.Name("com.apple.screensaver.willstop"),
            object: nil)

        updateOrientation()

        updateCurrentUrlStrings(firstLaunch: true)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func startAnimation() {
        super.startAnimation()
    }

    override func stopAnimation() {
        super.stopAnimation()
    }

    override func draw(_ rect: NSRect) {
        super.draw(rect)

        var squareFrame = NSRect.zero
        squareFrame.size = NSSize(
            width: window?.frame.width ?? 200,
            height: window?.frame.height ?? 200)
        squareFrame.origin.x = 0
        squareFrame.origin.y = 0
        bottomImageView.frame = squareFrame
        topImageView.frame = squareFrame
        statusLabelView.frame = squareFrame

        statusLabel.frame.origin = CGPoint(x: 10, y: 10)
    }

    func animationStopped() {
        Log.debug("Fade animation complete")
        swapHiddenImage()

        swapTimer?.invalidate()
        swapTimer = Timer.scheduledTimer(
            timeInterval: 15.0, target: self,
            selector: #selector(triggerSwapImageViews), userInfo: nil,
            repeats: false)
    }

    @objc private func triggerSwapImageViews() {
        Log.debug("15 seconds have passed, swapping images")
        swapImageViews()
    }

    override func animateOneFrame() {
        updateCurrentUrlStrings(firstLaunch: false)

        if urls.count < 100 {
            Task {
                await generateNewImages()
            }
        }

    }

    @objc fileprivate func willStop(_ aNotification: Notification) {
        Log.debug("🖼️ 📢📢📢 willStop")
        if #available(macOS 14.0, *) {
            exit(0)
        }
        self.stopAnimation()
    }

    private func updateOrientation() {
        if window?.frame.width ?? 0 < window?.frame.height ?? 0 {
            orientation = .portrait
        } else {
            orientation = .landscape
        }
    }

    func updateCurrentUrlStrings(firstLaunch: Bool) {
        do {
            urls = try getCurrentImageUrlStrings()
            if firstLaunch {
                swapHiddenImage()
            }
        } catch {
            Log.error(error.localizedDescription)
        }
    }

    private func showBottomImage() {
        let animation = CABasicAnimation(
            keyPath: #keyPath(CALayer.opacity))
        animation.fromValue = 0.0
        animation.toValue = 1.0
        animation.duration = 5.0
        animation.timingFunction = CAMediaTimingFunction(
            name: .easeInEaseOut)
        animation.delegate = self
        self.bottomImageView.layer?.add(animation, forKey: "fade")
        self.bottomImageView.layer?.opacity = 1
        Log.debug("Displaying Bottom Image")
    }

    private func showTopImage() {
        let animation = CABasicAnimation(keyPath: #keyPath(CALayer.opacity))
        animation.fromValue = 0.0
        animation.toValue = 1.0
        animation.duration = 5.0
        animation.timingFunction = CAMediaTimingFunction(
            name: .easeInEaseOut)
        animation.delegate = self
        topImageView.layer?.add(animation, forKey: "fade")
        topImageView.layer?.opacity = 1
        Log.debug("Displaying Top Image")
    }

    private func hideTopImage() {
        let animation = CABasicAnimation(keyPath: #keyPath(CALayer.opacity))
        animation.fromValue = 1.0
        animation.toValue = 0.0
        animation.duration = 5.0
        animation.timingFunction = CAMediaTimingFunction(
            name: .easeInEaseOut)
        animation.delegate = self
        topImageView.layer?.add(animation, forKey: "fade")
        topImageView.layer?.opacity = 0
        Log.debug("Hiding Top Image")
    }

    internal func updateStatusLabel(_ text: String) {
        fadeOutTimer?.invalidate()
        fadeOutTimer = nil
        statusLabelView.layer?.removeAllAnimations()

        statusLabel.stringValue = text
        let animation = CABasicAnimation(keyPath: #keyPath(CALayer.opacity))
        animation.fromValue = statusLabelView.layer?.opacity ?? 0.0
        animation.toValue = 1.0
        animation.duration = 1
        animation.timingFunction = CAMediaTimingFunction(
            name: .easeInEaseOut)
        statusLabelView.layer?.add(animation, forKey: "fade")
        statusLabelView.layer?.opacity = 1

        fadeOutTimer = Timer.scheduledTimer(
            timeInterval: 5.0, target: self,
            selector: #selector(fadeOutStatusLabel), userInfo: nil,
            repeats: false)
    }

    @objc private func fadeOutStatusLabel() {
        let animation = CABasicAnimation(keyPath: #keyPath(CALayer.opacity))
        animation.fromValue = statusLabelView.layer?.opacity ?? 1.0
        animation.toValue = 0
        animation.duration = 1
        animation.timingFunction = CAMediaTimingFunction(
            name: .easeInEaseOut)
        statusLabelView.layer?.add(animation, forKey: "fade")
        statusLabelView.layer?.opacity = 0
    }

    internal func swapHiddenImage() {
        if bottomImageView.layer?.opacity == 0.0 {
            if let url = getImageUrl() {
                bottomImageView.loadImage(url: url)
                Log.debug("Swapped Bottom Image")
                self.showBottomImage()
            }
        } else if topImageView.layer?.opacity == 1.0 {
            if let url = getImageUrl() {
                bottomImageView.loadImage(url: url)
                Log.debug("Swapped Bottom Image")
            }
        } else if topImageView.layer?.opacity == 0.0 {
            if let url = getImageUrl() {
                topImageView.loadImage(url: url)
                Log.debug("Swapped Top Image")
            }
        }
    }

    internal func swapImageViews() {
        guard !animationRunning else { return }

        animationRunning = true

        if topImageView.layer?.opacity ?? 0.0 == 0.0 {
            showTopImage()
        } else if topImageView.layer?.opacity ?? 0.0 == 1.0 {
            hideTopImage()
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

        let imagesFolderURL = appSupportURL.appendingPathComponent("Ealain")
            .appendingPathComponent(self.orientation.rawValue)
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
            let originalFileName = url.deletingPathExtension()
                .lastPathComponent  // Remove extension from original name
            let fileExtension =
                url.pathExtension.isEmpty ? "webp" : url.pathExtension  // Default to .webp if no extension
            let fileName =
                "\(timestamp)-\(originalFileName).\(fileExtension)"

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

    func generateNewImages() async {
        if currentlyGenerating {
            return
        }
        
        if isPreview {
            updateStatusLabel("Preview Mode")
            return
        }

        currentlyGenerating = true
        var currentRequestUUID: UUID?

        do {
            updateStatusLabel(
                "Requesting new images from the AI Horde")
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
        } catch APIError.requestFailed {
            updateStatusLabel(
                "Unable to communicate with the AI Horde, retrying")
        } catch APIError.requestTimedOut {
            updateStatusLabel(
                "Unable to communicate with the AI Horde, retrying")
        } catch let APIError.invalidResponse(statusCode, content) {
            Log.error(
                "Received \(statusCode) from AI Horde API. \(content)")
            if statusCode == 429 {
                updateStatusLabel(
                    "The AI Horde is experiencing heavy loads, retrying"
                )
            } else {
                updateStatusLabel(
                    "Unable to communicate with the AI Horde, retrying")
            }
        } catch {
            Log.error("\(error)")
            updateStatusLabel(
                "Unable to communicate with the AI Horde, retrying")
        }

        if let requestUUID = currentRequestUUID {
            var failures = 0
            while true {
                do {
                    let requestResponse = try await hordeAPI.checkRequest(
                        apiKey: hordeApiKey, requestUUID: requestUUID)
                    Log.debug("\(requestResponse)")
                    if requestResponse.done {
                        updateStatusLabel(
                            "Downloading new images from the AI Horde")
                        let finishedRequestResponse =
                            try await hordeAPI.fetchRequest(
                                apiKey: hordeApiKey,
                                requestUUID: requestUUID)
                        if let generations = finishedRequestResponse
                            .generations
                        {
                            updateStatusLabel(
                                "Storing new images downloaded from the AI Horde"
                            )
                            for generation in generations {
                                if !generation.censored {
                                    _ = await saveImageFromUrlString(
                                        generation.img)
                                }
                            }
                        }
                        break
                    } else {
                        if !requestResponse.isPossible {
                            updateStatusLabel(
                                "There are insufficient AI Horde workers to generate new images, waiting"
                            )
                        } else if requestResponse.processing == 0 {
                            if requestResponse.queuePosition > 0 {
                                updateStatusLabel(
                                    "Waiting (Currently #\(requestResponse.queuePosition) in queue)"
                                )
                            } else {
                                updateStatusLabel(
                                    "Waiting for a worker to begin generating images"
                                )
                            }
                        } else {
                            updateStatusLabel(
                                "Images are being generated by the AI Horde"
                            )
                        }
                    }
                } catch APIError.requestTimedOut {
                    updateStatusLabel(
                        "Request to the AI Horde timed out, retrying")
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
                }

                do {
                    try await Task.sleep(nanoseconds: 5_000_000_000)
                } catch {
                    Log.error("Could not sleep for 5 seconds!")
                }
            }
        }

        do {
            try await Task.sleep(nanoseconds: 5_000_000_000)
        } catch {
            Log.error("Could not sleep for extra 5 seconds!")
        }

        currentlyGenerating = false

    }

    func getImageUrl() -> String? {
        if urls.count < 2 {
            return nil
        }
        if urls.count == 1 {
            return urls[0]
        }

        if recentlyUsedUrls.count == urls.count {
            Log.debug(
                "Image list exahusted, pruning recent urls by half")
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

extension EalainView: CAAnimationDelegate {
    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        if flag {
            animationStopped()
            animationRunning = false
        }
    }
}
