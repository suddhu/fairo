import UIKit
import Foundation
import ARKit
import Combine
import ARCoreCloudAnchors
import SwiftUI

enum ARState: Int {
    case defaultState
    case creatingRoom
    case roomCreated
    case hosting
    case hostingFinished
    case enterRoomCode
    case resolving
    case resolvingFinished
}

protocol IosARViewDelegate: AnyObject {
    func tapGesture(_ frame: ARFrame, raycastResult: ARRaycastResult)
}

class DroidletARView: UIView, ARSCNViewDelegate, UIGestureRecognizerDelegate, ARSessionDelegate {
    let sceneView: ARSCNView
    let coachingView: ARCoachingOverlayView
    var showPlanes = false
    var customPlaneTexturePath: String? = nil
    private var trackedPlanes = [UUID: (SCNNode, SCNNode)]()
    
    var cancellableCollection = Set<AnyCancellable>() //Used to store all cancellables in (needed for working with Futures)
    var anchorCollection = [String: ARAnchor]() //Used to bookkeep all anchors created by Flutter calls
    
    var arcoreSession: GARSession? = nil
    private var arcoreMode: Bool = true
    private var configuration: ARWorldTrackingConfiguration!
    private var tappedPlaneAnchorAlignment = ARPlaneAnchor.Alignment.horizontal // default alignment
    
    private var panStartLocation: CGPoint?
    private var panCurrentLocation: CGPoint?
    private var panCurrentVelocity: CGPoint?
    private var panCurrentTranslation: CGPoint?
    private var rotationStartLocation: CGPoint?
    private var rotation: CGFloat?
    private var rotationVelocity: CGFloat?
    private var panningNode: SCNNode?
    private var panningNodeCurrentWorldLocation: SCNVector3?
    
    weak var delegate: IosARViewDelegate?
    private var state = ARState(rawValue: 0)
    
    private var arAnchor: ARAnchor?
    private var garAnchor: GARAnchor?
    
    var settings: UserSettings = .shared
    
    override init(frame: CGRect) {
        self.sceneView = ARSCNView(frame: frame)
        self.coachingView = ARCoachingOverlayView(frame: frame)
        
        super.init(frame: frame)
        
        let configuration = ARWorldTrackingConfiguration() // Create default configuration before initializeARView is called
        self.sceneView.delegate = self
        self.coachingView.delegate = self
        self.sceneView.session.run(configuration)
        self.sceneView.session.delegate = self
        
        initializeARView(arguments: ["planeDetectionConfig": 1,
                                     "showPlanes": true,
                                     "showFeaturePoints": true,
                                     "showWorldOrigin": false,
                                     "handleTaps": true])
    }
    
    required init?(coder: NSCoder) {
        self.sceneView = ARSCNView(frame: CGRect.zero)
        self.coachingView = ARCoachingOverlayView(frame: CGRect.zero)
        
        super.init(coder: coder)
    }
    
    func initializeARView(arguments: Dictionary<String,Any>){
        // Set plane detection configuration
        self.configuration = ARWorldTrackingConfiguration()
        if let planeDetectionConfig = arguments["planeDetectionConfig"] as? Int {
            switch planeDetectionConfig {
            case 1:
                configuration.planeDetection = .horizontal
                
            case 2:
                if #available(iOS 11.3, *) {
                    configuration.planeDetection = .vertical
                }
            case 3:
                if #available(iOS 11.3, *) {
                    configuration.planeDetection = [.horizontal, .vertical]
                }
            default:
                configuration.planeDetection = []
            }
        }
        
        // Set plane rendering options
        if let configShowPlanes = arguments["showPlanes"] as? Bool {
            showPlanes = configShowPlanes
            if (showPlanes){
                // Visualize currently tracked planes
                for plane in trackedPlanes.values {
                    plane.0.addChildNode(plane.1)
                }
            } else {
                // Remove currently visualized planes
                for plane in trackedPlanes.values {
                    plane.1.removeFromParentNode()
                }
            }
        }
        if let configCustomPlaneTexturePath = arguments["customPlaneTexturePath"] as? String {
            customPlaneTexturePath = configCustomPlaneTexturePath
        }
        
        // Set debug options
        var debugOptions = ARSCNDebugOptions().rawValue
        if let showFeaturePoints = arguments["showFeaturePoints"] as? Bool {
            if (showFeaturePoints) {
                debugOptions |= ARSCNDebugOptions.showFeaturePoints.rawValue
            }
        }
        if let showWorldOrigin = arguments["showWorldOrigin"] as? Bool {
            if (showWorldOrigin) {
                debugOptions |= ARSCNDebugOptions.showWorldOrigin.rawValue
            }
        }
        self.sceneView.debugOptions = ARSCNDebugOptions(rawValue: debugOptions)
        
        if let configHandleTaps = arguments["handleTaps"] as? Bool {
            if (configHandleTaps){
                let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
                tapGestureRecognizer.delegate = self
                self.sceneView.gestureRecognizers?.append(tapGestureRecognizer)
            }
        }
        
        // Add coaching view
        if let configShowAnimatedGuide = arguments["showAnimatedGuide"] as? Bool {
            if configShowAnimatedGuide {
                if self.sceneView.superview != nil && self.coachingView.superview == nil {
                    self.sceneView.addSubview(self.coachingView)
                    self.coachingView.autoresizingMask = [
                        .flexibleWidth, .flexibleHeight
                    ]
                    self.coachingView.session = self.sceneView.session
                    self.coachingView.activatesAutomatically = true
                    if configuration.planeDetection == .horizontal {
                        self.coachingView.goal = .horizontalPlane
                    }else{
                        self.coachingView.goal = .verticalPlane
                    }
                }
            }
        }
        
        // Update session configuration
        self.sceneView.session.run(configuration)
        
        self.addSubview(sceneView)
        sceneView.translatesAutoresizingMaskIntoConstraints = false
        sceneView.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        sceneView.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
        sceneView.leadingAnchor.constraint(equalTo: self.leadingAnchor).isActive = true
        sceneView.trailingAnchor.constraint(equalTo: self.trailingAnchor).isActive = true
        
        sceneView.delegate = self
        sceneView.session.delegate = self
        
        arcoreSession = try! GARSession(apiKey: "AIzaSyBzDk0TNpw87G0mE3AKfEaoSm08Kc5mhtU", bundleIdentifier: nil)
        arcoreSession?.delegate = self
        arcoreSession?.delegateQueue = DispatchQueue.main
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        
        let width = CGFloat(planeAnchor.extent.x)
        let height = CGFloat(planeAnchor.extent.z)
        let plane = SCNPlane(width: width, height: height)
        
        plane.materials.first?.diffuse.contents = UIColor.blue.withAlphaComponent(0.3)
        
        let planeNode = SCNNode(geometry: plane)
        
        let x = CGFloat(planeAnchor.center.x)
        let y = CGFloat(planeAnchor.center.y)
        let z = CGFloat(planeAnchor.center.z)
        
        planeNode.position = SCNVector3(x, y, z)
        planeNode.eulerAngles.x = -.pi / 2
        
        node.addChildNode(planeNode)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        
        guard let planeAnchor = anchor as?  ARPlaneAnchor,
              let planeNode = node.childNodes.first,
              let plane = planeNode.geometry as? SCNPlane
        else { return }
        
        let width = CGFloat(planeAnchor.extent.x)
        let height = CGFloat(planeAnchor.extent.z)
        
        plane.width = width
        plane.height = height
        
        let x = CGFloat(planeAnchor.center.x)
        let y = CGFloat(planeAnchor.center.y)
        let z = CGFloat(planeAnchor.center.z)
        
        planeNode.position = SCNVector3(x, y, z)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        guard let _ = anchor as?  ARPlaneAnchor,
              let planeNode = node.childNodes.first
        else { return }
        
        planeNode.removeFromParentNode()
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        if (arcoreMode) {
            do {
                try arcoreSession!.update(frame)
            } catch {
                print(error)
            }
        }
    }
    
    func transformNode(name: String, transform: Array<NSNumber>) {
        let node = sceneView.scene.rootNode.childNode(withName: name, recursively: true)
        node?.transform = deserializeMatrix4(transform)
    }
    
    @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard let sceneView = recognizer.view as? ARSCNView else {
            return
        }
        let touchLocation = recognizer.location(in: sceneView)
        let raycastQuery = sceneView.raycastQuery(from: touchLocation, allowing: .estimatedPlane, alignment: .any)
        
        guard let raycastQuery = raycastQuery else { return }
        let planeAndPointHitResults = sceneView.session.raycast(raycastQuery)
        
        if planeAndPointHitResults.count > 0, let hitAnchor = planeAndPointHitResults.first, let currentFrame = sceneView.session.currentFrame {
            
            let posX = hitAnchor.worldTransform.columns.3.x
            let posY = hitAnchor.worldTransform.columns.3.y
            let posZ = hitAnchor.worldTransform.columns.3.z
            let previousPoint = SCNVector3(posX, posY, posZ)
            
            let sphereNode = SCNNode(geometry: SCNSphere(radius: 0.01))
            sphereNode.position = previousPoint
            sphereNode.name = "test"
            sphereNode.simdPivot.columns.3.x = 0
            sphereNode.geometry?.firstMaterial?.diffuse.contents = UIColor.orange
            
            sceneView.scene.rootNode.addChildNode(sphereNode)
            
            settings.anchors.append(ARAnchorModel(currentFrame: currentFrame, hitAnchor: hitAnchor))
        }
        
    }
    
    // Recursive helper function to traverse a node's parents until a node with a name starting with the specified characters is found
    func nearestParentWithNameStart(node: SCNNode?, characters: String) -> SCNNode? {
        if let nodeNamePrefix = node?.name?.prefix(characters.count) {
            if (nodeNamePrefix == characters) { return node }
        }
        if let parent = node?.parent { return nearestParentWithNameStart(node: parent, characters: characters) }
        return nil
    }
    
    func addPlaneAnchor(transform: Array<NSNumber>, name: String){
        let arAnchor = ARAnchor(transform: simd_float4x4(deserializeMatrix4(transform)))
        anchorCollection[name] = arAnchor
        sceneView.session.add(anchor: arAnchor)
        while (sceneView.node(for: arAnchor) == nil) {
            usleep(1) // wait 1 millionth of a second
        }
    }
    
    func deleteAnchor(anchorName: String) {
        if let anchor = anchorCollection[anchorName]{
            // Delete all child nodes
            if var attachedNodes = sceneView.node(for: anchor)?.childNodes {
                attachedNodes.removeAll()
            }
            // Remove anchor
            sceneView.session.remove(anchor: anchor)
            // Update bookkeeping
            anchorCollection.removeValue(forKey: anchorName)
        }
    }
    
    func decodeCloudAnchorState(state: GARCloudAnchorState) -> String? {
        switch state {
        case .errorCloudIdNotFound:
            return "Cloud anchor id not found"
        case .errorHostingDatasetProcessingFailed:
            return "Dataset processing failed, feature map insufficient"
        case .errorHostingServiceUnavailable:
            return "Hosting service unavailable"
        case .errorInternal:
            return "Internal error"
        case .errorNotAuthorized:
            return "Authentication failed: Not Authorized"
        case .errorResolvingSdkVersionTooNew:
            return "Resolving Sdk version too new"
        case .errorResolvingSdkVersionTooOld:
            return "Resolving Sdk version too old"
        case .errorResourceExhausted:
            return " Resource exhausted"
        case .none:
            return "Empty state"
        case .taskInProgress:
            return "Task in progress"
        case .success:
            return "Success"
        case .errorServiceUnavailable:
            return "Cloud Anchor Service unavailable"
        case .errorResolvingLocalizationNoMatch:
            return "No match"
        }
    }
    
    func enter(_ state: ARState) {
        switch state {
        case .defaultState:
            if arAnchor != nil {
                sceneView.session.remove(anchor: arAnchor!)
                arAnchor = nil
            }
            if garAnchor != nil {
                arcoreSession?.remove(garAnchor!)
                garAnchor = nil
            }
        default:
            break
        }
        
        self.state = state
        
    }
    
}

// MARK: - ARCoachingOverlayViewDelegate
extension DroidletARView: ARCoachingOverlayViewDelegate {
    
    func coachingOverlayViewWillActivate(_ coachingOverlayView: ARCoachingOverlayView){
        // use this delegate method to hide anything in the UI that could cover the coaching overlay view
    }
    
    func coachingOverlayViewDidRequestSessionReset(_ coachingOverlayView: ARCoachingOverlayView) {
        // Reset the session.
        self.sceneView.session.run(configuration, options: [.resetTracking])
    }
}

extension DroidletARView {
    func hostCloudAnchor(withTransform transform: matrix_float4x4) {
        arAnchor = ARAnchor(transform: transform)
        
        guard let arAnchor = arAnchor else { return }
        
        sceneView.session.add(anchor: arAnchor)
        // To share an anchor, we call host anchor here on the ARCore session.
        // session:disHostAnchor: session:didFailToHostAnchor: will get called appropriately.
        garAnchor = try? arcoreSession?.hostCloudAnchor(arAnchor)
        enter(.hosting)
    }
}

extension DroidletARView: GARSessionDelegate {
    func session(_ session: GARSession, didHost anchor: GARAnchor) {
        if state != .hosting || !(anchor == garAnchor) {
            return
        }
        garAnchor = anchor
        enter(.hostingFinished)
    }
    
    func session(_ session: GARSession, didFailToHost anchor: GARAnchor) {
        if state != .hosting || !(anchor == garAnchor) {
            return
        }
        garAnchor = anchor
        enter(.hostingFinished)
    }
    
    func session(_ session: GARSession, didResolve anchor: GARAnchor) {
        if state != .resolving || !(anchor == garAnchor) {
            return
        }
        garAnchor = anchor
        arAnchor = ARAnchor(transform: anchor.transform)
        sceneView.session.add(anchor: arAnchor!)
        enter(.resolvingFinished)
    }
    
    func session(_ session: GARSession, didFailToResolve anchor: GARAnchor) {
        if state != .resolving || !(anchor == garAnchor) {
            return
        }
        garAnchor = anchor
        enter(.resolvingFinished)
    }
    
}

