import UIKit

class SelectionViewController: UITableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        self.fullyTranslucentNavigationBar(withTitle: "Select a cellular automaton")

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 3
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)

        switch indexPath.row {
        case 0:
            cell.textLabel!.text = "Game of Life (Metal)"
        case 1:
            cell.textLabel!.text = "SmoothLife (vDSP)"
        case 2:
            cell.textLabel!.text = "SmoothLife (Metal)"
        default:
            fatalError()
        }

        cell.accessoryType = .disclosureIndicator

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        let life: Life

        switch indexPath.row {
        case 0:
            life = GameOfLife(shape: (Int(self.view.bounds.height), Int(self.view.bounds.width)))
        case 1:
            life = SmoothLifevDSP(shape: (512, 512))
        case 2:
            life = SmoothLifeMetal(shape: (512, 512))
        default:
            fatalError()
        }

        self.navigationController!.pushViewController(RendererViewController(renderer: LifeRenderer(life: life)), animated: true)
    }

}

extension UIViewController {
    /// Sets the navigation bar to have a fully translucent appearance
    func fullyTranslucentNavigationBar(withTitle: String? = nil) {
        // Set attributes to navigation controller
        self.navigationController?.navigationBar.barStyle = .black
        self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: UIBarMetrics.default)
        self.navigationController?.navigationBar.isTranslucent = true
        self.navigationController?.navigationBar.shadowImage = UIImage()
        self.navigationController?.navigationBar.tintColor = UIColor.white
        self.navigationController?.navigationBar.backgroundColor = UIColor.clear

        // Hide title
        if let title = withTitle {
            self.navigationItem.title = title
        } else {
            self.navigationItem.titleView = UIView()
        }
    }
}
