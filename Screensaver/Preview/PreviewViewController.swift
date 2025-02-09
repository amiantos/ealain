import AppKit

class PreviewViewController: NSViewController {
    var screensaverView: EalainView? = nil

    var timer: Timer? = nil

    var isAnimating: Bool = false {
        didSet {
            toggleAnimationTimer()
        }
    }

    override func loadView() {
        screensaverView = EalainView(frame: CGRect.zero, isPreview: false)
        self.view = screensaverView ?? NSView()
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        isAnimating = true
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()

        isAnimating = false
    }

    private func toggleAnimationTimer() {
        if isAnimating {
            if timer == nil {
                timer = Timer.scheduledTimer(
                    withTimeInterval: 1 / 30.0, repeats: true
                ) { [weak self] (_) in
                    self?.animate()
                }
            }
        } else {
            if let timer = timer {
                timer.invalidate()
                self.timer = nil
            }
        }
    }

    func animate() {
        if isAnimating, let screensaverView = screensaverView {
            screensaverView.animateOneFrame()
        }
    }
}
