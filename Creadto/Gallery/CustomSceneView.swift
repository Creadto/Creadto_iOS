//
//  CustomSceneView.swift
//  Creadto
//
//  Created by 이상진 on 2022/10/05.
//

import SwiftUI
import SceneKit

struct CustomSceneView: UIViewRepresentable {
    @Binding var scene: SCNScene?
    
    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = true
        view.antialiasingMode = .multisampling2X
        view.scene = scene
        view.pointOfView = scene?.rootNode.childNode(withName: "camera", recursively: true)
        
        let currentFOV = view.pointOfView!.camera!.fieldOfView
        let pointSize = 10.0 - 0.078 * currentFOV
        if let pointsElement = scene?.rootNode.childNode(withName: "cloud", recursively: true)?.geometry?.elements.first{
            pointsElement.pointSize = pointSize
            pointsElement.minimumPointScreenSpaceRadius = pointSize
            pointsElement.maximumPointScreenSpaceRadius = pointSize
        }
        
        return view
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {
        
    }
    
}
