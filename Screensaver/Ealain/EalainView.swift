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

    let viewModel: EalainView.ViewModel = .init()

    override init?(frame: CGRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)

        Log.logLevel = .debug

        self.animationTimeInterval = TimeInterval(1 / viewModel.framesPerSecond)

        viewModel.delegate = self

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

        statusLabelShadow.shadowColor = NSColor.black
        statusLabelShadow.shadowOffset = CGSize(width: 0, height: 0)
        statusLabelShadow.shadowBlurRadius = 4
        statusLabel.shadow = statusLabelShadow

        DistributedNotificationCenter.default.addObserver(
            self,
            selector: #selector(EalainView.willStop(_:)),
            name: Notification.Name("com.apple.screensaver.willstop"),
            object: nil)

        viewModel.start()
        updateOrientation()
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

        statusLabel.frame.origin = CGPoint(x: 10, y: 10)
        statusLabelView.frame.origin = statusLabel.frame.origin

        var squareFrame = NSRect.zero
        squareFrame.size = NSSize(
            width: window?.frame.width ?? 200,
            height: window?.frame.height ?? 200)
        squareFrame.origin.x = 0
        squareFrame.origin.y = 0
        bottomImageView.frame = squareFrame
        topImageView.frame = squareFrame
        statusLabelView.frame = squareFrame

        updateOrientation()
    }

    override func animateOneFrame() {
        viewModel.animateOneFrame()
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
            viewModel.setOrientation(.portrait)
        } else {
            viewModel.setOrientation(.landscape)
        }
    }

}

extension EalainView: EalainView.ViewModelDelegate {

    func updateStatusLabel(_ text: String) {
        statusLabel.stringValue = text
    }

    internal func swapHiddenImage() {
        if topImageView.layer?.opacity == 1.0
            || bottomImageView.layer?.opacity == 0.0
        {
            bottomImageView.loadImage(url: viewModel.getImageUrl(for: .bottom))
            Log.debug("Swapped Bottom Image")

            if bottomImageView.layer?.opacity == 0.0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
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
            }
        } else if topImageView.layer?.opacity == 0.0 {
            topImageView.loadImage(url: viewModel.getImageUrl(for: .top))
            Log.debug("Swapped Top Image")
        }
    }

    internal func swapImageViews() {
        Log.debug("Swapping images...")
        if topImageView.layer?.opacity ?? 0.0 < 1 {
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
        } else {
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
}

extension EalainView: CAAnimationDelegate {
    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        if flag {
            swapHiddenImage()
        }
    }
}
