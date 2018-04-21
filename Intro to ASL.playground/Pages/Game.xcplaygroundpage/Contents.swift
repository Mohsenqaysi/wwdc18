//: # Intro to ASL  ![Logo](sign-language.png)
//: by Roland Horváth (made for WWDC18)
//: ##### An AR based Swift Playground where you can learn basic signs from the American Sign Language (ASL)
//: - - -
//: ## Welcome to the game!
//: 1. First up, tap the *"Run your code"* button to start the game.
//:
//: 2. Next, move your device around to detect a surface for AR
//:
//: 3. Then you'll see the hands pop up!
//:
//: Tapping the **menu button** will bring up a list of available signs you can check out!
//:
//: Tap one and watch the hands do the sign for you!
//: You can learn signs like:
//:
//: ✋ Excuse me, ✅ Yes, 🚫 No, 👫 Friend, 🐌 Slow, 📄 Paper, 🏫 School, 🕓 Time, 🎲 Game, 🤲 Help, 🏀 Ball, 🌈 Rainbow, 🚶‍♀️ Walk
//:
//: ---
//:
//: One of the biggest problems of learning sign language from books or videos is that since those materials are 2D, it's hard to properly see the gestures.
//:
//: Here, you can move your device around, so you can see the hands from a different angle.
//:
//: Also, if the hands happen to be too large or face a different direction, you can use the naturally pinch and pan the hands to scale or rotate them
//:
//: **I hope this makes you more interested about ASL and sign language!**
//:
//: **Have fun!**
//:
//: - - -
//: Sources I used for this project:
//: - handspeak.com
//: - WHO
//: - lifeprint.com
//: - nad.org
//: - lds.org
//: - medicinenet.com

import PlaygroundSupport
import SceneKit
import ARKit
import UIKit
//import Speech
import AVFoundation

// Data model

struct Sign: Decodable {
    var key: String
    var word: String
    var dialect: String
    var note: String
    var emoji: String
}

enum GameState {
    case searchingPlane
    case planeFound
    case ready
}

enum SpeechState {
    case idle
    case recording
    case recognizing
    case success
    case failed
}

struct Colors {
    
    static let dictationButton = UIColor(displayP3Red: 0/255, green: 122/255, blue: 255/255, alpha: 1)
    static let menuButton = UIColor(displayP3Red: 65/255, green: 170/255, blue: 240/255, alpha: 1)
}

func loadSigns(fileName: String) -> [Sign] {
    
    if let url = Bundle.main.url(forResource: fileName, withExtension: "json") {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let jsonData = try decoder.decode([Sign].self, from: data)
            return jsonData
        } catch {
            print("Couldn't load data: \(error)")
            UIAlertController.showAlert(title: "Error", body: "Couldn't load data: \(error.localizedDescription)")
        }
    }
    else {
        print("Signs file not found")
        UIAlertController.showAlert(title: "Error", body: "Signs file not found")
    }
    return []
}


class Hands: SCNNode {

    var animations = [String: SCNAnimationPlayer]()
    
    override init() {
        super.init()
        
        let scene = SCNScene(named: "Hands.scn")!
        addChildNode(scene.rootNode)
        self.scale = SCNVector3(0.01, 0.01, 0.01)
        
        animations = SCNAnimation.loadAnimations(fromScene: "Animations.scn")
        
        print("Loaded \(animations.count) anims")
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func play(_ key: String) {
        
        if let animation = animations[key] {
            addAnimationPlayer(animation, forKey: key)
        }
        else {
            UIAlertController.showAlert(title: "Something went wrong", body: "Animation not found")
        }
    }
}


class MainViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {
    
    // References
    
    var hands: Hands?
    
    var state: GameState = .searchingPlane {
        didSet {
            if state == .searchingPlane {
                moveAroundLabel.text = "Move around\nto find surface"
                moveAroundLabel.alpha = 1
                
                panHintLabel.alpha = 0
                menuButton.alpha = 0
            }
            else if state == .planeFound {
                moveAroundLabel.text = "Tap to confirm\nsurface"
                moveAroundLabel.alpha = 1
            }
            if state == .ready {
                
                hide(moveAroundLabel)
                panHintLabel.alpha = 1
                menuButton.alpha = 1
                hide(panHintLabel, afterSeconds: 7)
            }
        }
    }
    
    // AR
    
    var sceneView: ARSCNView!
    let session = ARSession()

    // UI
    
    var moveAroundLabel = UILabel()
    var panHintLabel = UILabel()
    
    var wordLabel = UILabel()
    var noteLabel = UILabel()
    
    var menuButton = UIButton()
    let menuView = MenuView()
    
    // Speech
    
    let synthesizer = AVSpeechSynthesizer()
    
    // Other

    var zoomScale: CGFloat = 1.0
    var targetRotation = SCNVector4()
    
    
    // MARK: - Initialization, data loading and other logic
    
    override func loadView() {
        super.loadView()
        
        // Setup SceneKit and ARKit
        
        sceneView = ARSCNView(frame: CGRect(x: 0, y: 0, width: 640, height: 480))
        
        sceneView.delegate = self
        sceneView.session = session
        sceneView.session.delegate = self
        
        sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints]
        
        let scene = SCNScene()
        sceneView.scene = scene
        
        sceneView.autoenablesDefaultLighting = true
        sceneView.automaticallyUpdatesLighting = true
        
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = .horizontal
        
        sceneView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        
        self.view = sceneView
        
        state = .searchingPlane
        
        // UI and Gesture Recognizers
        
        setupUI()
        menuView.delegate = self
        
        let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panGesture(_:)))
        let pinchRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(pinchGesture(_:)))
        
        sceneView.addGestureRecognizer(panRecognizer)
        sceneView.addGestureRecognizer(pinchRecognizer)
    }
    
    func play (sign: Sign) {
        
        // Play animation
        hands?.play(sign.key)
        
        // Say word out loud
        let utterance = AVSpeechUtterance(string: sign.word)
        utterance.rate = 0.5
        synthesizer.speak(utterance)
        
        // Update UI
        noteLabel.alpha = 1
        wordLabel.alpha = 1
        
        wordLabel.text = sign.word
        noteLabel.text = sign.note
        
        noteLabel.frame.size = CGSize(width: self.view.frame.size.width - 16 - menuButton.frame.width - 16 - 16, height: 1600)
        noteLabel.frame.size = noteLabel.sizeThatFits(noteLabel.frame.size)
        noteLabel.frame.origin = CGPoint(x: 16, y: self.view.frame.height - noteLabel.frame.height - 16)
        
        wordLabel.sizeToFit()
        wordLabel.frame.origin = CGPoint(x: 16, y: noteLabel.frame.origin.y - wordLabel.frame.height - 16)
        
        hide(wordLabel, afterSeconds: 6)
        hide(noteLabel, afterSeconds: 6)
    }
    
    // MARK: - UI setup, refreshing and other helper functions
    
    func setupUI () {
        
        moveAroundLabel.numberOfLines = 0
        moveAroundLabel.textColor = .white
        moveAroundLabel.font = UIFont.systemFont(ofSize: 50, weight: .bold)
        moveAroundLabel.textAlignment = .center
        
        panHintLabel.text = "Pinch and pan to\nrotate and scale the hands"
        panHintLabel.numberOfLines = 0
        panHintLabel.textColor = .white
        panHintLabel.font = UIFont.systemFont(ofSize: 24, weight: .medium)
        panHintLabel.textAlignment = .center
        
        wordLabel.textColor = .white
        wordLabel.font = UIFont.systemFont(ofSize: 46, weight: .bold)
        
        noteLabel.numberOfLines = 0
        noteLabel.textColor = .white
        noteLabel.font = UIFont.systemFont(ofSize: 25, weight: .medium)
        
        menuButton.setImage(#imageLiteral(resourceName: "menu.png"), for: .normal)
        menuButton.imageEdgeInsets = UIEdgeInsetsMake(20, 20, 20, 20)
        menuButton.layer.cornerRadius = 35
        menuButton.backgroundColor = Colors.menuButton
        menuButton.tintColor = .white
        menuButton.frame.size = CGSize(width: 70, height: 70)
        menuButton.addTarget(nil, action: #selector(toggleMenu), for: .touchUpInside)
        
        addShadow(to: wordLabel)
        addShadow(to: moveAroundLabel)
        addShadow(to: panHintLabel)
        addShadow(to: noteLabel)
        
        sceneView.addSubview(moveAroundLabel)
        sceneView.addSubview(panHintLabel)
        sceneView.addSubview(menuButton)
        sceneView.addSubview(menuView)
        sceneView.addSubview(wordLabel)
        sceneView.addSubview(noteLabel)
    }
    
    func hide(_ view: UIView, afterSeconds: TimeInterval = 0) {
        
        DispatchQueue.main.asyncAfter(deadline: .now() + afterSeconds) {
            
            UIView.animate(withDuration: 0.5, animations: {
                view.alpha = 0
            })
        }
    }
    
    func addShadow(to view: UIView) {
        
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowRadius = 12.0
        view.layer.shadowOpacity = 1.0
        view.layer.shadowOffset = CGSize.zero
        view.layer.masksToBounds = false
    }
    
    @objc func toggleMenu() {
        
        menuView.open = !menuView.open
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        moveAroundLabel.center = self.view.center
        moveAroundLabel.sizeToFit()
        
        panHintLabel.center = self.view.center
        panHintLabel.sizeToFit()
        
        menuButton.frame.origin = CGPoint(x: self.view.frame.width - menuButton.frame.width - 16 , y: self.view.frame.height - menuButton.frame.height - 16)
        
        menuView.frame.size = CGSize(width: 200, height: 400)
        menuView.frame.origin = CGPoint(x: self.view.frame.width - menuView.frame.width - 16, y: menuButton.frame.origin.y - 16 - menuView.frame.height)
    }

    // MARK: - Gesture Recognizer handling
    
    @objc func pinchGesture(_ sender: UIPinchGestureRecognizer) {
        
        if sender.state == .began || sender.state == .changed {
            
            zoomScale = sender.scale
            sender.scale = 1
        }
    }

    @objc func panGesture(_ sender: UIPanGestureRecognizer) {
        
        let translation = sender.translation(in: sender.view!)
        
        let panX = Float(translation.x)
        let panY = Float(-translation.y)
        let anglePan = sqrt(pow(panX, 2) + pow(panY, 2)) * (Float.pi) / 180.0
        var rotationVector = SCNVector4()
        
        rotationVector.x = 0
        rotationVector.y = panX
        rotationVector.z = 0
        rotationVector.w = anglePan
        
        if hands != nil {
            targetRotation = rotationVector
        }
    }
    
    
    // MARK: - ARKit and SceneKit delegate methods
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        
        self.hands?.runAction(SCNAction.scale(by: self.zoomScale, duration: 0.1))
        self.hands?.runAction(SCNAction.rotate(toAxisAngle: self.targetRotation, duration: 0.1))
    }
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        
        guard state == .searchingPlane else { return }
        
        if let anchor = anchors.first {
    
            let center = SCNVector3(anchor.transform.columns.3.x, anchor.transform.columns.3.y, anchor.transform.columns.3.z)
            
            DispatchQueue.main.async {
            
                self.hands = Hands()
                self.hands!.position = center
                self.sceneView.scene.rootNode.addChildNode(self.hands!)
            
                self.state = .ready
            }
        }
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        if let anchor = anchors.first {
            let center = SCNVector3(anchor.transform.columns.3.x, anchor.transform.columns.3.y, anchor.transform.columns.3.z)
            hands?.position = center
        }
    }
    
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        hands?.removeFromParentNode()
        state = .searchingPlane
    }
}


// MARK: - Custom View for Menu UI

class MenuView: UIView, UITableViewDelegate, UITableViewDataSource {
    
    let background = UIView()
    let arrow = UIImageView()
    let tableView = UITableView()
    var delegate: MainViewController?
    
    var open = false {
        didSet {
            UIView.animate(withDuration: 0.1, animations: {
                self.alpha = self.open ? 1 : 0
            })
        }
    }
    
    let data = loadSigns(fileName: "Data")
    
    init() {
        super.init(frame: CGRect.zero)
        
        arrow.image = #imageLiteral(resourceName: "arrow.png")
    
        background.backgroundColor = .white
        background.layer.cornerRadius = 10
        
        addSubview(arrow)
        addSubview(background)
        background.addSubview(tableView)
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.tableFooterView = nil
        tableView.alwaysBounceVertical = false;
        tableView.backgroundColor = .clear
        
        background.clipsToBounds = true
        
        alpha = 0
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        self.frame.size = CGSize(width: 200, height: 400)
        background.frame = CGRect(x: 0, y: 0, width: 200, height: 380)
        arrow.frame = CGRect(x: self.frame.width - 52, y: background.frame.height, width: 38, height: 16)
        
        tableView.frame = background.bounds
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return data.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = UITableViewCell()
        let sign = data[indexPath.row]
        
        cell.textLabel?.text = "\(sign.emoji) \(sign.word)"
        cell.textLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        delegate!.play(sign: data[indexPath.row])
        open = false
    }
}

// MARK: - Class extensions

extension SCNAnimation {
    
    class func loadAnimations(fromScene scene: String) -> [String: SCNAnimationPlayer] {
        
        let scene = SCNScene(named: scene)!
        var players = [String: SCNAnimationPlayer]()
        
        scene.rootNode.enumerateChildNodes { child, stop in
            
            if !child.animationKeys.isEmpty {
                child.animationKeys.forEach { key in
                    let player = child.animationPlayer(forKey: key)!
                    
                    player.animation.repeatCount = 1
                    player.animation.blendInDuration = 0.5
                    player.animation.blendOutDuration = 0.5
                    player.animation.isRemovedOnCompletion = true
                    
                    players[key] = player
                }
            }
        }
        
        return players
    }
}

extension UIAlertController {

    class func showAlert (title: String?, body: String?, callback: (() -> ())? = nil) {
        
        let alert = UIAlertController(title: title, message: body, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: {_ in callback?()}))
        viewController.present(alert, animated: true, completion: nil)
    }
}


// MARK: - Playgrounds setup

let viewController = MainViewController()

PlaygroundPage.current.liveView = viewController
PlaygroundPage.current.needsIndefiniteExecution = true

