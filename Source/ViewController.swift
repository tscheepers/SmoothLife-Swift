import UIKit
import Metal

class ViewController: UIViewController {

    var renderer: LifeRenderer!

    var metalLayer: CAMetalLayer!

    var timer: CADisplayLink!

    override func viewDidLoad() {
        super.viewDidLoad()

        let life = SmoothLifeMetal(shape: (1024, 1024))
        //let life = SmoothLifevDSP(shape: (1024, 1024))
        //let life = GameOfLife(shape: (1024, 1024))
        
        renderer = LifeRenderer(life: life)

        metalLayer = renderer.createMetalLayer(frame: view.layer.frame)
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
