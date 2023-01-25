//
//  PreviewController.swift
//  Creadto
//
//  Created by 이상진 on 2022/11/27.
//

import UIKit
import SceneKit

class PreviewController: UIViewController {
    private let scnURL : URL
    private let scnView = SCNView()
    private var scene : SCNScene!
    private var cameraNode : SCNNode!
    var mainController : MainController!
    
    init(scnURL : URL){
        self.scnURL = scnURL
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder){
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        
        view.backgroundColor = UIColor.white
        view.addSubview(scnView)
        view.addSubview(deleteButton)
        view.addSubview(saveButton)
    }
    
    private let deleteButton : UIButton = {
        let button = UIButton(type: UIButton.ButtonType.custom)
        button.setTitleColor(UIColor.black, for: UIControl.State.normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: UIFont.Weight.semibold)
        button.backgroundColor = UIColor(red: 1.0, green: 0.27, blue: 0.27, alpha: 1.0)
        button.layer.cornerRadius = 10
        button.setTitle("Delete", for: UIControl.State.normal)
        button.addTarget(self, action: #selector(deleteTapped(_:)), for: UIControl.Event.touchUpInside)
        return button
    }()
    
    private let saveButton : UIButton = {
        let button = UIButton(type: UIButton.ButtonType.custom)
        button.setTitleColor(UIColor.black, for: UIControl.State.normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: UIFont.Weight.semibold)
        button.backgroundColor = UIColor(red: 0.14, green: 0.54, blue: 1.0, alpha: 1.0)
        button.layer.cornerRadius = 10
        button.setTitle("Save", for: UIControl.State.normal)
        button.addTarget(self, action: #selector(saveTapped(_:)), for: UIControl.Event.touchUpInside)
        return button
    }()
    
    override func viewDidLayoutSubviews() {
        scnView.frame = view.bounds
        let buttonHeight: CGFloat = 56
        let buttonSpacing: CGFloat = 20
        let buttonInsets = UIEdgeInsets(top: 0, left: 20, bottom: 5, right: 20)
        
        var buttonFrame = CGRect.zero
        buttonFrame.size.width = CGFloat(1) / CGFloat(2) * (view.bounds.width - buttonInsets.left - buttonInsets.right - CGFloat(1) * buttonSpacing)
        buttonFrame.size.height = buttonHeight
        buttonFrame.origin.x = buttonInsets.left
        buttonFrame.origin.y = view.bounds.height - view.safeAreaInsets.bottom - buttonInsets.bottom - buttonHeight
        deleteButton.frame = buttonFrame
        saveButton.frame = buttonFrame.offsetBy(dx: buttonFrame.width + buttonSpacing, dy: 0)
    }
    
    func setupView() {
        scene = try! SCNScene(url: scnURL, options: nil)
        scnView.scene = scene
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = true
        scnView.antialiasingMode = .multisampling2X
        scnView.backgroundColor = UIColor(hue: 0.9556, saturation: 0, brightness: 0.97, alpha: 1.0) /* #f7f7f7 */
        
        scnView.pointOfView = scene?.rootNode.childNode(withName: "camera", recursively: true)

        let currentFOV = scnView.pointOfView!.camera!.fieldOfView
        let pointSize = 10.0 - 0.078 * currentFOV
        if let pointsElement = scene.rootNode.childNode(withName: "cloud", recursively: true)?.geometry?.elements.first{
            pointsElement.pointSize = pointSize
            pointsElement.minimumPointScreenSpaceRadius = pointSize
            pointsElement.maximumPointScreenSpaceRadius = pointSize
        }
    }
    
    @objc
    private func deleteTapped(_ sender: UIButton){
        // MARK: Delete SCN file
        try? FileManager.default.removeItem(at: mainController.renderer.savedCloudURLs.last!)
        mainController.renderer.savedCloudURLs.removeLast()
        
        // MARK: Delete ply file
        try? FileManager.default.removeItem(at: mainController.renderer.savedCloudURLs.last!)
        mainController.renderer.savedCloudURLs.removeLast()
        
        mainController.plyCounter -= 1
        
        if(mainController.plyCounter == 0){
            try? FileManager.default.removeItem(at: mainController.renderer.directoryURL!)
            mainController.renderer.directoryURL = nil
        }
        dismiss(animated: true)
    }
    
    @objc
    private func saveTapped(_ sender: UIButton){
        let previewImage = scnView.snapshot()
        let pngData = previewImage.pngData()
        let fileName = mainController.fileNameList[mainController.plyCounter-1].dropLast()
        let previewImageURL = mainController.renderer.directoryURL!.appendingPathComponent("\(fileName).png")
        try? pngData!.write(to: previewImageURL)
        dismiss(animated: true)
    }
    
}
