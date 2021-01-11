import UIKit
import Metal

class ViewController: UIViewController {

    var gameOfLife: GameOfLife!

    var metalLayer: CAMetalLayer!

    var timer: CADisplayLink!

    override func viewDidLoad() {
        super.viewDidLoad()

        let factory = GameOfLifeFactory()

        gameOfLife = factory.create(
            cellsWide: Int(self.view.frame.width),
            cellsHigh: Int(self.view.frame.height)
        )
        gameOfLife.restart(random: true)

        metalLayer = factory.createMetalLayer(frame: view.layer.frame)
        view.layer.addSublayer(metalLayer)

        timer = CADisplayLink(target: self, selector: #selector(gameloop))
        timer.add(to: RunLoop.main, forMode: .default)
    }

    @objc func gameloop() {
      autoreleasepool {
        guard let drawable = metalLayer?.nextDrawable() else { return }
        gameOfLife.render(drawable: drawable)
      }
    }

}
