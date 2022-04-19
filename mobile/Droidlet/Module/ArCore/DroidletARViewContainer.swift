import SwiftUI
import ARKit
import Combine

struct DroidletARViewContainer: UIViewRepresentable {
    @ObservedObject var viewModel: HomeViewModel
    var settings: UserSettings = .shared

    private var cancellable: AnyCancellable?

    var rayCastResultValue: ARRaycastResult?
    var visionRequests = [VNRequest]()
    
    let resnetModel: Resnet50 = {
        do {
            let configuration = MLModelConfiguration()
            return try Resnet50(configuration: configuration)
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }()
    
    init(viewModel: HomeViewModel) {
        self.viewModel = viewModel
    }

    func makeUIView(context: Context) -> DroidletARView {
        viewModel.iosView = DroidletARView(frame: .zero)
        viewModel.iosView.delegate = context.coordinator
        return viewModel.iosView
    }
    
    func updateUIView(_ uiView: DroidletARView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
    
    final class Coordinator: NSObject, IosARViewDelegate {
        var parent: DroidletARViewContainer
        
        var deviceOrientation: CGImagePropertyOrientation {
            switch UIDevice.current.orientation {
                case .portrait:           return .right
                case .portraitUpsideDown: return .left
                case .landscapeLeft:      return .up
                case .landscapeRight:     return .down
                default:                  return .right
            }
        }

        init( _ parent: DroidletARViewContainer) {
            self.parent = parent
        }
        
        func tapGesture(_ frame: ARFrame, raycastResult: ARRaycastResult) {
            parent.rayCastResultValue = raycastResult
            visionRequest(frame.capturedImage)
        }
        
        // Step 2: ask the model what this is
        private func visionRequest(_ pixelBuffer: CVPixelBuffer) {
            let visionModel = try! VNCoreMLModel(for: parent.resnetModel.model)
            let request = VNCoreMLRequest(model: visionModel) { request, error in
                guard error == nil else {
                    print(error!.localizedDescription)
                    return
                }
                guard let observations = request.results ,
                      let observation = observations.first as? VNClassificationObservation else {
                    print("Could not classify")
                    return
                }
                DispatchQueue.main.async {
                    let named = observation.identifier.components(separatedBy: ", ").first!
                    let confidence = "\(named): \((Int)(observation.confidence * 100))% confidence"
                    self.askName(suggestion: named, confidence: confidence, pixelBuffer)
                }
            }
            request.imageCropAndScaleOption = .centerCrop
            parent.visionRequests = [request]
            let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                                            orientation: deviceOrientation, // or .upMirrored?
                                                            options: [:])
            DispatchQueue.global().async {
                try! imageRequestHandler.perform(self.parent.visionRequests)
            }
        }

        // Step 3: ask the user to confirm
        func askName(suggestion: String, confidence: String, _ pixelBuffer: CVPixelBuffer) {            
            let alert = parent.settings.alert(message: confidence, inputText: suggestion) { name in
                let image = CIImage(cvPixelBuffer: pixelBuffer).oriented(self.deviceOrientation)
                //self.createText(name)
                Droidbase.shared.saveToCloud(nil, name, UIImage(ciImage: image))
            }

            if let delegate = UIApplication.shared.delegate as? AppDelegate,
               let parentViewController = delegate.window?.rootViewController {
                parentViewController.present(alert, animated: true)
            }
        }
        
        // Step 4: put the name on the object
        func createText(_ generatedText: String) {

        }
    }
}
