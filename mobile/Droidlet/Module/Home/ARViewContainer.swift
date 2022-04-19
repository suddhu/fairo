import ARKit
import RealityKit
import SwiftUI
import VideoToolbox
import Vision
import MetalKit

// The UI view for the augmented reality
// Supports one user story with these steps:
// 0. Display the camera view
// 1. User taps on something
// 2. Ask ML model what the camera is looking at
// 3. Ask user to confirm what the ML says
// 4. Sticks the result on the object as AR text

struct ARViewContainer: UIViewRepresentable {

    let resnetModel: Resnet50 = {
        do {
            let configuration = MLModelConfiguration()
            return try Resnet50(configuration: configuration)
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }()

    var rayCastResultValue: ARRaycastResult!
    var visionRequests = [VNRequest]()
    @ObservedObject var viewModel: HomeViewModel
    @ObservedObject var settings: UserSettings = .shared

    func makeUIView(context: Context) -> ARView {
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            let tapGesture = UITapGestureRecognizer(
                target: context.coordinator,
                action: #selector(Coordinator.handleTap(_:))
            )
            viewModel.arView.addGestureRecognizer(tapGesture)
        } else {
            let tapGesture = UITapGestureRecognizer(
                target: context.coordinator,
                action: #selector(Coordinator.tapGestureMethod(_:))
            )
            viewModel.arView.addGestureRecognizer(tapGesture)
        }
        
        viewModel.delegate = context.coordinator
                
        // Manually configure what kind of AR session to run since
        // ARView on its own does not turn on mesh classification.
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            viewModel.arView.session.delegate = context.coordinator
            viewModel.arView.automaticallyConfigureSession = false
            let configuration = ARWorldTrackingConfiguration()
            configuration.sceneReconstruction = .meshWithClassification

            configuration.environmentTexturing = .automatic
            viewModel.arView.session.run(configuration)
        }
        
        return viewModel.arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }

    final class Coordinator: NSObject, ARControlsViewDelegate, ARSessionDelegate {
        var parent: ARViewContainer
        
        // Cache for 3D text geometries representing the classification values.
        var modelsForClassification: [ARMeshClassification: ModelEntity] = [:]

        // So that we evaluate and save the image right side up
        var deviceOrientation: CGImagePropertyOrientation {
            switch UIDevice.current.orientation {
                case .portrait:           return .right
                case .portraitUpsideDown: return .left
                case .landscapeLeft:      return .up
                case .landscapeRight:     return .down
                default:                  return .right
            }
        }

        init( _ parent: ARViewContainer) {
            self.parent = parent
            guard ARWorldTrackingConfiguration.isSupported else {
                fatalError("ARKit is not available on this device.")
            }
        }
        
        @objc func handleTap(_ sender: UITapGestureRecognizer) {
            // 1. Perform a ray cast against the mesh.
            // Note: Ray-cast option ".estimatedPlane" with alignment ".any" also takes the mesh into account.
            let tapLocation = sender.location(in: parent.viewModel.arView)
            if let result = parent.viewModel.arView.raycast(from: tapLocation, allowing: .estimatedPlane, alignment: .any).first {
                // ...
                // 2. Visualize the intersection point of the ray with the real-world surface.
                let resultAnchor = AnchorEntity(world: result.worldTransform)
                resultAnchor.addChild(sphere(radius: 0.01, color: .lightGray))
                parent.viewModel.arView.scene.addAnchor(resultAnchor, removeAfter: 3)
                
                // 3. Try to get a classification near the tap location.
                //    Classifications are available per face (in the geometric sense, not human faces).
                nearbyFaceWithClassification(to: result.worldTransform.position) { (centerOfFace, classification) in
                    // ...
                    DispatchQueue.main.async {
                        // 4. Compute a position for the text which is near the result location, but offset 10 cm
                        // towards the camera (along the ray) to minimize unintentional occlusions of the text by the mesh.
                        let rayDirection = normalize(result.worldTransform.position - self.parent.viewModel.arView.cameraTransform.translation)
                        let textPositionInWorldCoordinates = result.worldTransform.position - (rayDirection * 0.1)
                        
                        // 5. Create a 3D text to visualize the classification result.
                        let textEntity = self.model(for: classification)
                        
                        // 6. Scale the text depending on the distance, such that it always appears with
                        //    the same size on screen.
                        let raycastDistance = distance(result.worldTransform.position, self.parent.viewModel.arView.cameraTransform.translation)
                        textEntity.scale = .one * raycastDistance
                        
                        // 7. Place the text, facing the camera.
                        var resultWithCameraOrientation = self.parent.viewModel.arView.cameraTransform
                        resultWithCameraOrientation.translation = textPositionInWorldCoordinates
                        let textAnchor = AnchorEntity(world: resultWithCameraOrientation.matrix)
                        textAnchor.addChild(textEntity)
                        self.parent.viewModel.arView.scene.addAnchor(textAnchor, removeAfter: 3)
                        
                        // 8. Visualize the center of the face (if any was found) for three seconds.
                        //    It is possible that this is nil, e.g. if there was no face close enough to the tap location.
                        if let centerOfFace = centerOfFace {
                            let faceAnchor = AnchorEntity(world: centerOfFace)
                            faceAnchor.addChild(self.sphere(radius: 0.01, color: classification.color))
                            self.parent.viewModel.arView.scene.addAnchor(faceAnchor, removeAfter: 3)
                        }
                    }
                }
            }
        }
        
        // Step 1: user taps on an object
        @objc func tapGestureMethod(_ sender: UITapGestureRecognizer) {
            guard let sceneView = sender.view as? ARView else { return }

            let touchLocation = parent.viewModel.arView.center
            let result = parent.viewModel.arView.raycast(from: touchLocation,
                                               allowing: .estimatedPlane,
                                               alignment: .any)
            guard let raycastHitTestResult: ARRaycastResult = result.first,
                  let currentFrame = sceneView.session.currentFrame else {
                return
            }

            parent.rayCastResultValue = raycastHitTestResult
            visionRequest(currentFrame.capturedImage)
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
                self.createText(name)
                //Droidbase.shared.saveToCloud(self.parent.arView, name, UIImage(ciImage: image))
            }

            if let delegate = UIApplication.shared.delegate as? AppDelegate,
               let parentViewController = delegate.window?.rootViewController {
                parentViewController.present(alert, animated: true)
            }
        }
        
        // Step 4: put the name on the object
        func createText(_ generatedText: String) {
            let mesh = MeshResource.generateText(generatedText,
                                                 extrusionDepth: 0.01,
                                                 font: UIFont(name: "HelveticaNeue", size: 0.05)!,
                                                 containerFrame: CGRect.zero,
                                                 alignment: .center,
                                                 lineBreakMode: .byCharWrapping)
            
            let material = SimpleMaterial(color: .green, roughness: 1, isMetallic: true)
            let modelEntity = ModelEntity(mesh: mesh, materials: [material])
            let anchorEntity = AnchorEntity(world: SIMD3<Float>(parent.rayCastResultValue.worldTransform.columns.3.x,
                                                                parent.rayCastResultValue.worldTransform.columns.3.y,
                                                                parent.rayCastResultValue.worldTransform.columns.3.z))
            anchorEntity.addChild(modelEntity)
            parent.viewModel.arView.scene.addAnchor(anchorEntity)
        }
        
        func session(_ session: ARSession, didFailWithError error: Error) {
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
                    //self.resetButtonPress()
                }
                alertController.addAction(restartAction)
                
                if let delegate = UIApplication.shared.delegate as? AppDelegate,
                   let parentViewController = delegate.window?.rootViewController {
                    parentViewController.present(alertController, animated: true)
                }
            }
        }
        
        func startPlaneDetectionButtonPressed() {
            guard let configuration = parent.viewModel.arView.session.configuration as? ARWorldTrackingConfiguration else {
                return
            }
            if configuration.planeDetection == [] {
                configuration.planeDetection = [.horizontal, .vertical]
                parent.viewModel.startPlaneDetection = false
            } else {
                configuration.planeDetection = []
                parent.viewModel.startPlaneDetection = true
            }
            parent.viewModel.arView.session.run(configuration)
        }
        
        func hideMeshButtonPressed() {
            let isShowingMesh = parent.viewModel.arView.debugOptions.contains(.showSceneUnderstanding)
            if isShowingMesh {
                parent.viewModel.arView.debugOptions.remove(.showSceneUnderstanding)
                parent.viewModel.hideMesh = false
            } else {
                parent.viewModel.arView.debugOptions.insert(.showSceneUnderstanding)
                parent.viewModel.hideMesh = true
            }
        }
        
        func resetButtonPress() {
            if let configuration = parent.viewModel.arView.session.configuration {
                parent.viewModel.arView.session.run(configuration, options: .resetSceneReconstruction)
            }
        }
        
        func saveButtonPressed() {
            guard let camera = parent.viewModel.arView.session.currentFrame?.camera else {return}

            func convertToAsset(meshAnchors: [ARMeshAnchor]) -> MDLAsset? {
                guard let device = MTLCreateSystemDefaultDevice() else {return nil}

                let asset = MDLAsset()

                for anchor in meshAnchors {
                    let mdlMesh = anchor.geometry.toMDLMesh(device: device, camera: camera, modelMatrix: anchor.transform)
                    asset.add(mdlMesh)
                }
                
                return asset
            }
            
            func export(asset: MDLAsset) throws -> URL {
                let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let url = directory.appendingPathComponent("scan.obj")
                parent.viewModel.fileUrl = url

                try asset.export(to: url)

                return url
            }
            
            if let meshAnchors = parent.viewModel.arView.session.currentFrame?.anchors.compactMap({ $0 as? ARMeshAnchor }),
               let asset = convertToAsset(meshAnchors: meshAnchors) {
                do {
                    let _ = try export(asset: asset)
                    parent.viewModel.showingEditARVC = true
                } catch {
                    Logger.logDebug("export error")
                }
            }
        }
                
        func nearbyFaceWithClassification(to location: SIMD3<Float>, completionBlock: @escaping (SIMD3<Float>?, ARMeshClassification) -> Void) {
            guard let frame = parent.viewModel.arView.session.currentFrame else {
                completionBlock(nil, .none)
                return
            }
        
            var meshAnchors = frame.anchors.compactMap({ $0 as? ARMeshAnchor })
            
            // Sort the mesh anchors by distance to the given location and filter out
            // any anchors that are too far away (4 meters is a safe upper limit).
            let cutoffDistance: Float = 4.0
            meshAnchors.removeAll { distance($0.transform.position, location) > cutoffDistance }
            meshAnchors.sort { distance($0.transform.position, location) < distance($1.transform.position, location) }

            // Perform the search asynchronously in order not to stall rendering.
            DispatchQueue.global().async {
                for anchor in meshAnchors {
                    for index in 0..<anchor.geometry.faces.count {
                        // Get the center of the face so that we can compare it to the given location.
                        let geometricCenterOfFace = anchor.geometry.centerOf(faceWithIndex: index)
                        
                        // Convert the face's center to world coordinates.
                        var centerLocalTransform = matrix_identity_float4x4
                        centerLocalTransform.columns.3 = SIMD4<Float>(geometricCenterOfFace.0, geometricCenterOfFace.1, geometricCenterOfFace.2, 1)
                        let centerWorldPosition = (anchor.transform * centerLocalTransform).position
                         
                        // We're interested in a classification that is sufficiently close to the given location––within 5 cm.
                        let distanceToFace = distance(centerWorldPosition, location)
                        if distanceToFace <= 0.05 {
                            // Get the semantic classification of the face and finish the search.
                            let classification: ARMeshClassification = anchor.geometry.classificationOf(faceWithIndex: index)
                            completionBlock(centerWorldPosition, classification)
                            return
                        }
                    }
                }
                
                // Let the completion block know that no result was found.
                completionBlock(nil, .none)
            }
        }
        
        func model(for classification: ARMeshClassification) -> ModelEntity {
            // Return cached model if available
            if let model = modelsForClassification[classification] {
                model.transform = .identity
                return model.clone(recursive: true)
            }
            
            // Generate 3D text for the classification
            let lineHeight: CGFloat = 0.05
            let font = MeshResource.Font.systemFont(ofSize: lineHeight)
            let textMesh = MeshResource.generateText(classification.description, extrusionDepth: Float(lineHeight * 0.1), font: font)
            let textMaterial = SimpleMaterial(color: classification.color, isMetallic: true)
            let model = ModelEntity(mesh: textMesh, materials: [textMaterial])
            // Move text geometry to the left so that its local origin is in the center
            model.position.x -= model.visualBounds(relativeTo: nil).extents.x / 2
            // Add model to cache
            modelsForClassification[classification] = model
            return model
        }
        
        func sphere(radius: Float, color: UIColor) -> ModelEntity {
            let sphere = ModelEntity(mesh: .generateSphere(radius: radius), materials: [SimpleMaterial(color: color, isMetallic: false)])
            // Move sphere up by half its diameter so that it does not intersect with the mesh
            sphere.position.y = radius
            return sphere
        }
    }
}
