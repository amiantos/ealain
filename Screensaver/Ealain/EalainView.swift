import Foundation
import ScreenSaver

class EalainView: ScreenSaverView {

    var count: Int = 0
    var urlRefreshCount: Int = 0

    let imageView1 = EalainImageView()
    let imageView2 = EalainImageView()

    let loadingLabelView = NSView()
    let loadingLabel = NSTextField(labelWithString: "Ealain requires internet access to function. Please wait...")

    var currentUrl1: String = ""
    var currentUrl2: String = ""
    var urls: [String] = []
    var recentUrls: [String] = []

    override init?(frame: CGRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        self.animationTimeInterval = 1 / 30.0

        addSubview(loadingLabelView)
        loadingLabelView.wantsLayer = true
        loadingLabelView.addSubview(loadingLabel)
        addSubview(imageView1)
        addSubview(imageView2)
        imageView2.layer?.opacity = 0
        imageView1.layer?.opacity = 0

        loadingLabel.textColor = .white
        loadingLabel.sizeToFit()

        fadeLabelOut()

        fetchFreshImageUrls(firstLaunch: true)
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
        imageView1.frame = squareFrame
        imageView2.frame = squareFrame
        loadingLabelView.frame = squareFrame

    }

    override func animateOneFrame() {
        count += 1
        urlRefreshCount += 1

        if count == 20 * 30 {
            print("Updating...")
            swapImageViews()
            count = 0
        }

        if urlRefreshCount == 108000 {
            fetchFreshImageUrls()
            urlRefreshCount = 0
        }
    }

    @objc fileprivate func fadeLabelOut() {
        print("Fading label out...")
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
        print("Fetching fresh image URLs...")
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
        if imageView2.layer?.opacity ?? 0.0 < 1 {
            let animation = CABasicAnimation(keyPath: #keyPath(CALayer.opacity))
            animation.fromValue = 0.0
            animation.toValue = 1.0
            animation.duration = 5.0
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animation.delegate = self
            imageView2.layer?.opacity = 1
            imageView2.layer?.add(animation, forKey: "fade")
            print("Displaying Image 2")
        } else {
            let animation = CABasicAnimation(keyPath: #keyPath(CALayer.opacity))
            animation.fromValue = 1.0
            animation.toValue = 0.0
            animation.duration = 5.0
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animation.delegate = self
            imageView2.layer?.opacity = 0
            imageView2.layer?.add(animation, forKey: "fade")
            print("Hiding Image 2")
        }
    }

    fileprivate func swapHiddenImage() {
        if recentUrls.count == urls.count {
            print("Image list exahusted, pruning.")
            recentUrls.removeFirst(recentUrls.count/2)
        }

        if imageView2.layer?.opacity == 1.0 || imageView1.layer?.opacity == 0.0 {
            while true {
                guard let newUrl = urls.randomElement() else { break }
                if recentUrls.firstIndex(of: newUrl) == nil {
                    currentUrl1 = newUrl
                    break
                }
            }
            imageView1.loadImage(url: currentUrl1)
            recentUrls.append(currentUrl1)
            print("Swapped Image 1")

            if imageView1.layer?.opacity == 0.0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    let animation = CABasicAnimation(keyPath: #keyPath(CALayer.opacity))
                    animation.fromValue = 0.0
                    animation.toValue = 1.0
                    animation.duration = 5.0
                    animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    animation.delegate = self
                    self.imageView1.layer?.opacity = 1
                    self.imageView1.layer?.add(animation, forKey: "fade")
                    print("Displaying Image 1")
                }
            }
        } else if imageView2.layer?.opacity == 0.0 {
            while true {
                guard let newUrl = urls.randomElement() else { break }
                if recentUrls.firstIndex(of: newUrl) == nil {
                    currentUrl2 = newUrl
                    break
                }
            }
            imageView2.loadImage(url: currentUrl2)
            recentUrls.append(currentUrl2)
            print("Swapped Image 2")
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
