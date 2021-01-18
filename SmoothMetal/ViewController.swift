import UIKit
import Metal

class ViewController: UIViewController {

    var life: SmoothLife!

    var metalLayer: CAMetalLayer!

    var timer: CADisplayLink!

    override func viewDidLoad() {
        super.viewDidLoad()

        let factory = SmoothLifeFactory()

        life = factory.create(
            cellsWide: 64,
            cellsHigh: 64
        )
        life.restart()

        metalLayer = factory.createMetalLayer(frame: view.layer.frame)
        view.layer.addSublayer(metalLayer)

        timer = CADisplayLink(target: self, selector: #selector(gameloop))
        timer.add(to: RunLoop.main, forMode: .default)
    }

    @objc func gameloop() {
      autoreleasepool {
        guard let drawable = metalLayer?.nextDrawable() else { return }
        life.render(drawable: drawable)
      }
    }

}
