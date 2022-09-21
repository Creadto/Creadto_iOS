import UIKit
import Metal
import MetalKit
import ARKit
import CoreImage.CIFilterBuiltins

final class MainController: UIViewController, ARSessionDelegate {
    //private weak var mtkView : MTKView!
    public let isUIEnabled = true
    private var clearButton = UIButton(type: .system)
    private let confidenceControl = UISegmentedControl(items: ["Low", "Medium", "High"])
    private var rgbButton = UIButton(type: .system)
    private var showSceneButton = UIButton(type: .system)
    private var saveButton = UIButton(type: .system)
    
    // session은 한개만 있어야 할 것 같은데 일단 이대로 진행해보고 안되면 session만 이용하고 capture하기
    // todo : ARSession만 이용해서 capture된 frame을 가져올 수 있다. 따라서, captureSession은 버려도 될듯
    public var session = ARSession()
    //public var captureSession : AVCaptureSession?
    
    var renderer: Renderer!
    private  var isPasued = false
    
    // Segmentation Request
    private let requestHandler = VNSequenceRequestHandler()
    private var facePoseRequest: VNDetectFaceRectanglesRequest!
    private var segmentationRequest = VNGeneratePersonSegmentationRequest()
    
    // A structure that contains RGB color intensity values
    private var colors: AngleColors?
    
    @IBOutlet weak var cameraView: MTKView!{
        didSet{
            guard metalDevice == nil else { return }
            setupUI()
            setupMetal()
            setupCoreImage()
        }
    }
    // The Metal pipeline.
    public var metalDevice: MTLDevice!
    public var metalCommandQueue: MTLCommandQueue!
    
    // The Core Image pipeline.
    public var ciContext: CIContext!
    public var currentCIImage: CIImage? {
        didSet {
            cameraView.draw()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Create a world-tracking configuration, and
        // enable the scene depth frame-semantic.
        let configuration = ARWorldTrackingConfiguration()
        configuration.frameSemantics = [.sceneDepth, .smoothedSceneDepth]
        // Run the view's session
        session.run(configuration)
        
//        ios 16 버전 이상부터
//        session.captureHighResolutionFrame{(frame, error) in
//            if let frame = frame{
//
//            }
//        }
        
        // The screen shouldn't dim during AR experiences.
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        intializeRequests()
    }
    
    private func setupUI(){
        clearButton = createButton(mainView: self, iconName: "trash.circle.fill",
            tintColor: .red, hidden: !isUIEnabled)
        cameraView.addSubview(clearButton)
        
        saveButton = createButton(mainView: self, iconName: "tray.and.arrow.down.fill",
            tintColor: .white, hidden: !isUIEnabled)
        cameraView.addSubview(saveButton)
        
        showSceneButton = createButton(mainView: self, iconName: "livephoto",
            tintColor: .yellow, hidden: !isUIEnabled)
        cameraView.addSubview(showSceneButton)
        
        rgbButton = createButton(mainView: self, iconName: "eye",
            tintColor: .blue, hidden: !isUIEnabled)
        cameraView.addSubview(rgbButton)
        
        NSLayoutConstraint.activate([
            clearButton.leftAnchor.constraint(equalTo: cameraView.leftAnchor, constant: 50),
            clearButton.topAnchor.constraint(equalTo: cameraView.topAnchor, constant: 50),
            clearButton.widthAnchor.constraint(equalToConstant: 50),
            clearButton.heightAnchor.constraint(equalToConstant: 50),
            
            saveButton.widthAnchor.constraint(equalToConstant: 50),
            saveButton.heightAnchor.constraint(equalToConstant: 50),
            saveButton.rightAnchor.constraint(equalTo: cameraView.rightAnchor, constant: -50),
            saveButton.topAnchor.constraint(equalTo: cameraView.topAnchor, constant: 50),
            
            showSceneButton.widthAnchor.constraint(equalToConstant: 60),
            showSceneButton.heightAnchor.constraint(equalToConstant: 60),
            showSceneButton.bottomAnchor.constraint(equalTo: cameraView.bottomAnchor, constant: -50),
            showSceneButton.centerXAnchor.constraint(equalTo: cameraView.centerXAnchor),
        
            rgbButton.rightAnchor.constraint(equalTo: cameraView.rightAnchor, constant: -50),
            rgbButton.bottomAnchor.constraint(equalTo: cameraView.bottomAnchor, constant: -50),
            rgbButton.widthAnchor.constraint(equalToConstant: 60),
            rgbButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func intializeRequests() {
        
        // Create a request to detect face rectangles.
        facePoseRequest = VNDetectFaceRectanglesRequest { [weak self] request, _ in
            guard let face = request.results?.first as? VNFaceObservation else { return }
            // Generate RGB color intensity values for the face rectangle angles.
            self?.colors = AngleColors(roll: face.roll, pitch: face.pitch, yaw: face.yaw)
        }
        facePoseRequest.revision = VNDetectFaceRectanglesRequestRevision3
        
        // Create a request to segment a person from an image.
        segmentationRequest = VNGeneratePersonSegmentationRequest()
        segmentationRequest.qualityLevel = .accurate
        segmentationRequest.outputPixelFormat = kCVPixelFormatType_OneComponent8
    }
    
    @objc
    func viewValueChanged(view: UIView) {
        switch view {
        case confidenceControl:
            renderer.confidenceThreshold = confidenceControl.selectedSegmentIndex
            
        case rgbButton:
            renderer.rgbOn = !renderer.rgbOn
            let iconName = renderer.rgbOn ? "eye.slash": "eye"
            rgbButton.setBackgroundImage(.init(systemName: iconName), for: .normal)
            // run the segmentation model
            
        case clearButton:
            renderer.isInViewSceneMode = true
            setShowSceneButtonStyle(isScanning: false)
            renderer.clearParticles()
            
        case saveButton:
            renderer.isInViewSceneMode = true
            setShowSceneButtonStyle(isScanning: false)
//            goToSaveCurrentScanView()
        
        case showSceneButton:
            renderer.isInViewSceneMode = !renderer.isInViewSceneMode
            if !renderer.isInViewSceneMode {
                renderer.showParticles = true
                self.setShowSceneButtonStyle(isScanning: true)
            } else {
                self.setShowSceneButtonStyle(isScanning: false)
            }
            
        default:
            break
        }
    }
    
    func setShowSceneButtonStyle(isScanning: Bool) -> Void {
        if isScanning {
            self.showSceneButton.setBackgroundImage(
                .init(systemName: "livephoto.slash"), for: .normal)
            self.showSceneButton.tintColor = .red
        } else {
            self.showSceneButton.setBackgroundImage(
                .init(systemName: "livephoto"), for: .normal)
            self.showSceneButton.tintColor = .white
        }
    }
    
    
    
    // Auto-hide the home indicator to maximize immersion in AR experiences.
    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }
    
    // Hide the status bar to maximize immersion in AR experiences.
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    
    // Deal with Error about rendering session
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user.
        guard error is ARError else { return }
        let errorWithInfo = error as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]
        let errorMessage = messages.compactMap({ $0 }).joined(separator: "\n")
        DispatchQueue.main.async {
            // Present an alert informing about the error that has occurred.
            let alertController = UIAlertController(title: "The AR session failed.", message: errorMessage, preferredStyle: .alert)
            let restartAction = UIAlertAction(title: "Restart Session", style: .default) { _ in
                alertController.dismiss(animated: true, completion: nil)
                if let configuration = self.session.configuration {
                    self.session.run(configuration, options: .resetSceneReconstruction)
                }
            }
            alertController.addAction(restartAction)
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    
}


// MARK: - MTKViewDelegate
extension MainController: MTKViewDelegate {
    // Called whenever view changes orientation or layout is changed
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        if renderer != nil {
            renderer.drawRectResized(size: size)
        }
    }
    
    // Called whenever the view needs to render
    func draw(in view: MTKView) {
        // Segmentation Draw
        guard let commandBuffer = metalCommandQueue.makeCommandBuffer() else {
            return
        }

        // grab image
        guard let ciImage = currentCIImage else {
            return
        }

        // ensure drawable is free and not tied in the preivous drawing cycle
        guard let currentDrawable = view.currentDrawable else {
            return
        }
        
        // make sure the image is full screen
        let drawSize = view.drawableSize
        let scaleX = drawSize.width / ciImage.extent.width
        let scaleY = drawSize.height / ciImage.extent.height
        
        let newImage = ciImage.transformed(by: .init(scaleX: scaleX, y: scaleY))
        //render into the metal texture
        self.ciContext.render(newImage,
                              to: currentDrawable.texture,
                              commandBuffer: commandBuffer,
                              bounds: newImage.extent,
                              colorSpace: CGColorSpaceCreateDeviceRGB())

        // register drawwable to command buffer
        commandBuffer.present(currentDrawable)
        commandBuffer.commit()
        
        // PointCloud Draw
        renderer.draw()
    }
}
//
//extension MainController: AVCaptureVideoDataOutputSampleBufferDelegate {
//    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
//        // Grab the pixelbuffer frame from the camera output
//        guard let pixelBuffer = sampleBuffer.imageBuffer else { return }
//        processVideoFrame(pixelBuffer)
//    }
//}


// MARK: - RenderDestinationProvider
protocol RenderDestinationProvider {
    var currentRenderPassDescriptor: MTLRenderPassDescriptor? { get }
    var currentDrawable: CAMetalDrawable? { get }
    var colorPixelFormat: MTLPixelFormat { get set }
    var depthStencilPixelFormat: MTLPixelFormat { get set }
    var sampleCount: Int { get set }
}

extension SCNNode {
    func cleanup() {
        for child in childNodes {
            child.cleanup()
        }
        self.geometry = nil
    }
}

func createButton(mainView: MainController, iconName: String, tintColor: UIColor, hidden: Bool) -> UIButton {
    let button = UIButton(type: .system)
    button.isHidden = hidden
    button.translatesAutoresizingMaskIntoConstraints = false
    button.setBackgroundImage(.init(systemName: iconName), for: .normal)
    button.tintColor = tintColor
    button.addTarget(mainView, action: #selector(mainView.viewValueChanged), for: .touchDown)
    return button
}

extension MTKView: RenderDestinationProvider {
    
}

// A structure that provides an RGB color intensity value for the roll, pitch, and yaw angles.
struct AngleColors {
    
    let red: CGFloat
    let blue: CGFloat
    let green: CGFloat
    
    init(roll: NSNumber?, pitch: NSNumber?, yaw: NSNumber?) {
        red = AngleColors.convert(value: roll, with: -.pi, and: .pi)
        blue = AngleColors.convert(value: pitch, with: -.pi / 2, and: .pi / 2)
        green = AngleColors.convert(value: yaw, with: -.pi / 2, and: .pi / 2)
    }
    
    static func convert(value: NSNumber?, with minValue: CGFloat, and maxValue: CGFloat) -> CGFloat {
        guard let value = value else { return 0 }
        let maxValue = maxValue * 0.8
        let minValue = minValue + (maxValue * 0.2)
        let facePoseRange = maxValue - minValue
        
        guard facePoseRange != 0 else { return 0 } // protect from zero division
        
        let colorRange: CGFloat = 1
        return (((CGFloat(truncating: value) - minValue) * colorRange) / facePoseRange)
    }
}
