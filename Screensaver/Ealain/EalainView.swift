import Foundation
import ScreenSaver

class EalainView: ScreenSaverView {

    let bottomImageView = EalainImageView()
    let topImageView = EalainImageView()

    let statusLabelView = NSView()
    let statusLabel = NSTextField(
        labelWithString:
            "Ealain requires internet access to function. Please wait...")
    let statusLabelShadow = NSShadow()

    let viewModel: EalainView.ViewModel?

    private var fadeOutTimer: Timer?

    override init?(frame: CGRect, isPreview: Bool) {
        viewModel = EalainView.ViewModel()
        super.init(frame: frame, isPreview: isPreview)

        Log.logLevel = .debug

        self.animationTimeInterval = TimeInterval(1 / (viewModel?.framesPerSecond ?? 30))

        viewModel?.delegate = self

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

        updateOrientation()
    }

    override func animateOneFrame() {
        viewModel?.animateOneFrame()
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
        self.bottomImageView.layer?.opacity = 1
        self.bottomImageView.layer?.add(animation, forKey: "fade")
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
        topImageView.layer?.opacity = 1
        topImageView.layer?.add(animation, forKey: "fade")
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
        topImageView.layer?.opacity = 0
        topImageView.layer?.add(animation, forKey: "fade")
        Log.debug("Hiding Top Image")
    }

}

extension EalainView: EalainView.ViewModelDelegate {

    func updateStatusLabel(_ text: String) {
//        fadeOutTimer?.invalidate()
//        fadeOutTimer = nil
//        statusLabelView.layer?.removeAllAnimations()
//
//        statusLabel.stringValue = text
//        let animation = CABasicAnimation(keyPath: #keyPath(CALayer.opacity))
//        animation.fromValue = statusLabelView.layer?.opacity ?? 0.0
//        animation.toValue = 1.0
//        animation.duration = 1
//        animation.timingFunction = CAMediaTimingFunction(
//            name: .easeInEaseOut)
//        statusLabelView.layer?.opacity = 1
//        statusLabelView.layer?.add(animation, forKey: "fade")
//
//        fadeOutTimer = Timer.scheduledTimer(
//            timeInterval: 5.0, target: self,
//            selector: #selector(fadeOutStatusLabel), userInfo: nil,
//            repeats: false)
    }

    @objc private func fadeOutStatusLabel() {
        let animation = CABasicAnimation(keyPath: #keyPath(CALayer.opacity))
        animation.fromValue = statusLabelView.layer?.opacity ?? 1.0
        animation.toValue = 0
        animation.duration = 1
        animation.timingFunction = CAMediaTimingFunction(
            name: .easeInEaseOut)
        statusLabelView.layer?.opacity = 0
        statusLabelView.layer?.add(animation, forKey: "fade")
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
        if topImageView.layer?.opacity ?? 0.0 < 1 {
            showTopImage()
        } else {
            hideTopImage()
        }
    }
}

extension EalainView: CAAnimationDelegate {
    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        if flag {
            viewModel?.animationStopped()
        }
    }
}
