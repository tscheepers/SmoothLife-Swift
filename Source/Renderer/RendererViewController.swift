import UIKit
import Metal

class RendererViewController: UIViewController {

    convenience init(renderer: LifeRenderer) {
        self.init(nibName: nil, bundle: nil)
        self.renderer = renderer
    }

    var renderer: LifeRenderer!

    var metalLayer: CAMetalLayer!

    var timer: CADisplayLink?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.fullyTranslucentNavigationBar()

        metalLayer = renderer.createMetalLayer(frame: view.layer.frame)
        view.layer.addSublayer(metalLayer)
        view.clipsToBounds = true

        timer = CADisplayLink(target: self, selector: #selector(gameloop))
        timer?.add(to: RunLoop.main, forMode: .default)
    }

    override func viewDidDisappear(_ animated: Bool) {
        timer?.remove(from: RunLoop.main, forMode: .default)
        timer = nil
    }

    @objc func gameloop() {
      autoreleasepool {
        guard let drawable = metalLayer?.nextDrawable() else { return }
        renderer.render(drawable: drawable)
      }
    }

}
