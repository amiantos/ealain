import Foundation
import ScreenSaver

class EalainView: ScreenSaverView {
    
    let framesPerSecond: Int = 30

    var count: Int = 0
    var urlRefreshCount: Int = 0

    let bottomImageView = EalainImageView()
    let topImageView = EalainImageView()

    let loadingLabelView = NSView()
    let loadingLabel = NSTextField(labelWithString: "Ealain requires internet access to function. Please wait...")

    var currentUrl1: String = ""
    var currentUrl2: String = ""
    var urls: [String] = []
    var recentUrls: [String] = []

    override init?(frame: CGRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        
        Log.logLevel = .debug
        
        self.animationTimeInterval = TimeInterval(1 / framesPerSecond)

        addSubview(loadingLabelView)
        loadingLabelView.wantsLayer = true
        loadingLabelView.addSubview(loadingLabel)
        addSubview(bottomImageView)
        addSubview(topImageView)
        topImageView.layer?.opacity = 0
        bottomImageView.layer?.opacity = 0

        loadingLabel.textColor = .white
        loadingLabel.sizeToFit()

        setupLabelAnimation()

        fetchFreshImageUrls(firstLaunch: true)
        
        DistributedNotificationCenter.default.addObserver(self,
            selector: #selector(EalainView.willStop(_:)),
                    name: Notification.Name("com.apple.screensaver.willstop"), object: nil)
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

        loadingLabel.frame.origin = CGPoint(x: ((window?.frame.width)!/2)-(loadingLabel.frame.width/2), y: (window?.frame.height)!/2)
        loadingLabelView.frame.origin = loadingLabel.frame.origin

        var squareFrame = NSRect.zero
        squareFrame.size = NSSize(width: window?.frame.width ?? 200, height: window?.frame.height ?? 200)
        squareFrame.origin.x = 0
        squareFrame.origin.y = 0
        bottomImageView.frame = squareFrame
        topImageView.frame = squareFrame
        loadingLabelView.frame = squareFrame

    }

    override func animateOneFrame() {
        count += 1
        urlRefreshCount += 1

        if count == 20 * framesPerSecond {
            swapImageViews()
            count = 0
        }

        if urlRefreshCount == 3600 * framesPerSecond {
            fetchFreshImageUrls()
            urlRefreshCount = 0
        }
    }
    
    
    @objc fileprivate func willStop(_ aNotification: Notification) {
        Log.debug("🖼️ 📢📢📢 willStop")
           if #available(macOS 14.0, *) {
               exit(0)
           }
           self.stopAnimation()
       }

    fileprivate func setupLabelAnimation() {
        Log.debug("Fading label out...")
        let animation = CABasicAnimation(keyPath: #keyPath(CALayer.opacity))
        animation.fromValue = 1.0
        animation.toValue = 0.2
        animation.duration = 3.0
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        animation.autoreverses = true
        animation.repeatCount = .infinity

        loadingLabelView.layer?.opacity = 0.2
        loadingLabelView.layer?.add(animation, forKey: "labelFadeOut")
    }

    fileprivate func fetchFreshImageUrls(firstLaunch: Bool = false) {
        Log.debug("Fetching fresh image URLs...")
        DispatchQueue.global(qos: .background).async {
            if let data = try? Data(contentsOf: URL(string: "https://ealain.s3.amazonaws.com/latest.json")!), let urls = try? JSONDecoder().decode(
                [String].self,
                from: data
            ) {
                self.urls = urls
                if firstLaunch {
                    DispatchQueue.main.async {
                        self.swapHiddenImage()
                    }
                }
            }
        }
    }

    fileprivate func swapImageViews() {
        Log.debug("Swapping images...")
        if topImageView.layer?.opacity ?? 0.0 < 1 {
            let animation = CABasicAnimation(keyPath: #keyPath(CALayer.opacity))
            animation.fromValue = 0.0
            animation.toValue = 1.0
            animation.duration = 5.0
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animation.delegate = self
            topImageView.layer?.opacity = 1
            topImageView.layer?.add(animation, forKey: "fade")
            Log.debug("Displaying Top Image")
        } else {
            let animation = CABasicAnimation(keyPath: #keyPath(CALayer.opacity))
            animation.fromValue = 1.0
            animation.toValue = 0.0
            animation.duration = 5.0
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animation.delegate = self
            topImageView.layer?.opacity = 0
            topImageView.layer?.add(animation, forKey: "fade")
            Log.debug("Hiding Top Image")
        }
    }

    fileprivate func swapHiddenImage() {
        if recentUrls.count == urls.count {
            Log.debug("Image list exahusted, pruning recent urls by half...")
            recentUrls.removeFirst(recentUrls.count/2)
        }

        if topImageView.layer?.opacity == 1.0 || bottomImageView.layer?.opacity == 0.0 {
            while true {
                guard let newUrl = urls.randomElement() else { break }
                if recentUrls.firstIndex(of: newUrl) == nil {
                    currentUrl1 = newUrl
                    break
                }
            }
            bottomImageView.loadImage(url: currentUrl1)
            recentUrls.append(currentUrl1)
            Log.debug("Swapped Bottom Image")

            if bottomImageView.layer?.opacity == 0.0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    let animation = CABasicAnimation(keyPath: #keyPath(CALayer.opacity))
                    animation.fromValue = 0.0
                    animation.toValue = 1.0
                    animation.duration = 5.0
                    animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    animation.delegate = self
                    self.bottomImageView.layer?.opacity = 1
                    self.bottomImageView.layer?.add(animation, forKey: "fade")
                    Log.debug("Displaying Bottom Image")
                }
            }
        } else if topImageView.layer?.opacity == 0.0 {
            while true {
                guard let newUrl = urls.randomElement() else { break }
                if recentUrls.firstIndex(of: newUrl) == nil {
                    currentUrl2 = newUrl
                    break
                }
            }
            topImageView.loadImage(url: currentUrl2)
            recentUrls.append(currentUrl2)
            Log.debug("Swapped Top Image")
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
