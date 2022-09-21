//
//  MainController+Extras.swift
//  Creadto
//
//  Created by 이상진 on 2022/09/21.
//

import Foundation
import MetalKit

// MARK: - Added controller functionality
extension MainController {
    func setupMetal(){
        metalDevice = MTLCreateSystemDefaultDevice()
        metalCommandQueue = metalDevice.makeCommandQueue()
        session.delegate = self
        
        // Set the view to use the defualt device
        cameraView.device = metalDevice
        cameraView.delegate = self
            
        // Segmentation View setup
        cameraView.isPaused = true
        cameraView.enableSetNeedsDisplay = false
        cameraView.framebufferOnly = false
            
        // PointCloud View setup
        cameraView.depthStencilPixelFormat = .depth32Float
        cameraView.contentScaleFactor = 1
        cameraView.backgroundColor = UIColor.clear
        
        // Configure the renderer to draw to the view
        renderer = Renderer(session: session, metalDevice: metalDevice, renderDestination: cameraView)
        renderer.drawRectResized(size: cameraView.bounds.size)
    }
    
    
    func setupCoreImage() {
        ciContext = CIContext(mtlDevice: metalDevice)
    }
    
    func onSaveError(error: XError) {
        displayErrorMessage(error: error)
        renderer.savingError = nil
    }
    
    func export(url: URL) -> Void {
        present(
            UIActivityViewController(
                activityItems: [url as Any],
                applicationActivities: .none),
            animated: true)
    }
    
    func afterSave() -> Void {
        let err = renderer.savingError
        if err == nil {
            return export(url: renderer.savedCloudURLs.last!)
        }
        try? FileManager.default.removeItem(at: renderer.savedCloudURLs.last!)
        renderer.savedCloudURLs.removeLast()
        onSaveError(error: err!)
    }
    
//    func goToSaveCurrentScanView() {
//        let saveContoller = SaveController()
//        saveContoller.mainController = self
//        present(saveContoller, animated: true, completion: nil)
//    }
//
//    func goToExportView() -> Void {
//        let exportController = ExportController()
//        exportController.mainController = self
//        present(exportController, animated: true, completion: nil)
//    }
    
    func displayErrorMessage(error: XError) -> Void {
        var title: String
        switch error {
            case .alreadySavingFile: title = "Save in Progress Please Wait."
            case .noScanDone: title = "No scan to Save."
            case.savingFailed: title = "Failed To Write File."
        }
        
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        present(alert, animated: true, completion: nil)
        let when = DispatchTime.now() + 1.75
        DispatchQueue.main.asyncAfter(deadline: when) {
            alert.dismiss(animated: true, completion: nil)
        }
    }

}
