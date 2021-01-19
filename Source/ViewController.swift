import UIKit
import Metal

class ViewController: UIViewController {

    var renderer: SmoothLifeRenderer!

    var metalLayer: CAMetalLayer!

    var timer: CADisplayLink!

    override func viewDidLoad() {
        super.viewDidLoad()

        let factory = SmoothLifeRendererFactory()
        renderer = factory.createRenderer(
            forSmoothLife: SmoothLife(shape: (height: 512, width: 512))
        )
        metalLayer = factory.createMetalLayer(frame: view.layer.frame)
        view.layer.addSublayer(metalLayer)

        timer = CADisplayLink(target: self, selector: #selector(gameloop))
        timer.add(to: RunLoop.main, forMode: .default)
    }

    @objc func gameloop() {
      autoreleasepool {
        guard let drawable = metalLayer?.nextDrawable() else { return }
        renderer.render(drawable: drawable)
      }
    }

}
