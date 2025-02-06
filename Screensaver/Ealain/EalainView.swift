import Foundation
import ScreenSaver

class EalainView: ScreenSaverView, ViewModelDelegate {

    private let bottomImageView = EalainImageView()
    private let topImageView = EalainImageView()

    private let statusLabelView = NSView()
    private let statusLabel = NSTextField(
        labelWithString:
            "Ealain requires internet access to function. Please wait...")
    private let statusLabelShadow = NSShadow()

    private var viewModel: ViewModel?

    private var fadeOutTimer: Timer?
    
    private var animationRunning: Bool = false
    
    private var frameCounter: Int = 0
    private let framesPerSecond: Int = 30

    override init?(frame: CGRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        
        viewModel = ViewModel(delegate: self)

        Log.logLevel = .debug

        self.animationTimeInterval = TimeInterval(1 / framesPerSecond)

        addSubview(bottomImageView)
        addSubview(topImageView)
        topImageView.layer?.opacity = 0
        bottomImageView.layer?.opacity = 0

        addSubview(statusLabelView)
        statusLabelView.wantsLayer = true
        statusLabelView.addSubview(statusLabel)
        statusLabel.textColor = .white
        statusLabel.font = .systemFont(ofSize: 16, weight: .medium)
        statusLabel.sizeToFit()
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
        
        viewModel?.start()
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
        frameCounter = 0
    }

    override func animateOneFrame() {
        frameCounter += 1

        if frameCounter == 15 * framesPerSecond {
            Log.debug("15 seconds has passed since animation ended")
            swapImageViews()
            frameCounter = 0
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
            viewModel?.setOrientation(.portrait)
        } else {
            viewModel?.setOrientation(.landscape)
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
            if let url = viewModel?.getImageUrl() {
                bottomImageView.loadImage(url: url)
                Log.debug("Swapped Bottom Image")
                self.showBottomImage()
            }
        } else if topImageView.layer?.opacity == 1.0 {
            if let url = viewModel?.getImageUrl() {
                bottomImageView.loadImage(url: url)
                Log.debug("Swapped Bottom Image")
            }
        } else if topImageView.layer?.opacity == 0.0 {
            if let url = viewModel?.getImageUrl() {
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
}

extension EalainView: CAAnimationDelegate {
    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        if flag {
            animationStopped()
            animationRunning = false
        }
    }
}
