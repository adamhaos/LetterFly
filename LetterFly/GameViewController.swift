//
//  GameViewController.swift
//  LetterFly
//
//  Created by Adam Moore on 9/27/26.
//

import UIKit
import SpriteKit

class GameViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let spriteView = view as? SKView else { return }
        let scene = GameScene(size: spriteView.bounds.size)
        scene.scaleMode = .resizeFill
        spriteView.presentScene(scene)
        spriteView.ignoresSiblingOrder = true
        spriteView.isMultipleTouchEnabled = false
        becomeFirstResponder()
    }

    override var canBecomeFirstResponder: Bool { true }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        guard motion == .motionShake,
              let scene = (view as? SKView)?.scene as? GameScene else { return }
        scene.shuffleAvailableTiles()
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .allButUpsideDown
        } else {
            return .all
        }
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    override var prefersHomeIndicatorAutoHidden: Bool { true }
}
