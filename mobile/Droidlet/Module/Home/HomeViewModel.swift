import Foundation
import FirebaseDatabase
import SocketIO
import ARKit
import RealityKit

import Starscream
import AVFoundation
import UIKit
import SwiftUI

struct CustomData : SocketData {
   let msg: String

   func socketRepresentation() -> SocketData {
       return ["msg": msg]
   }
}

class HomeViewModel: ObservableObject {
    var settings: UserSettings = .shared

    @Published var listChat: [ChatModel] = []
    @Published var inputTextChat: String = ""
    
    @Published var agentState: AgentState = .none
    @Published var dashboardMode: DashboardMode = .ar
    @Published var showChat: Bool = false
    
    var image: UIImage?
    var name: String = ""
    @Published var showEditPhotoVC = false
    
    // AR Scene Understanding
    @Published var startPlaneDetection = true
    @Published var hideMesh = true
    @Published var showingEditARVC = false
    var fileUrl: URL?
    
    @Published var depthImg: UIImage? = nil
    @Published var showEditVideoVC = false
    
    private let service = CameraService()
    var session: AVCaptureSession
    
    var anchor: AnchorEntity?
    
    var manager: SocketManager!
    var socket: SocketIOClient!
    
    var iosView: DroidletARView!
    
    init() {
        session = service.session
        service.delegate = self
    }
    
    func startARSection() {
        guard let configuration = iosView.sceneView.session.configuration as? ARWorldTrackingConfiguration else {
            return
        }

        iosView.sceneView.session.run(configuration)
    }

    func pauseARSection() {
        iosView.sceneView.session.pause()
    }
    
    func logout() {
        SessionManage.shared.logout()
        settings.expride = false
    }
    
    // MARK: - Camera
    func startCamera() {
        service.checkForPermissions()
        service.configure()
    }
    
    func stopCamera() {
        service.stop(completion: {
            
        })
    }
    
    func capturePhoto() {
        service.capturePhoto()
    }
    
    // MARK: - Firebase
    func upload(image: UIImage, name: String, url: URL?) {
        switch dashboardMode {
        case .camera:
            Droidbase.shared.saveToCloud(nil, name, image)
        case .ar:
            Droidbase.shared.save3DToCloud(nil, name, url: url)
        default:
            break
        }
    }
    
    func getObjectAPI() {
        Droidbase.shared.getObjectAPI(completion: { image in
            //self.image = image
        })
    }
    
    func downloadImageAPI(_ name: String) {
        Droidbase.shared.downloadImageAPI(name, completion: nil)
    }
    
    // MARK: - Socket
    func connectSocket() {
        manager = SocketManager(socketURL: URL(string: APIMainEnvironmentConfig.api)!, config: [.log(false), .compress])
        socket = manager.defaultSocket

        socket.on(clientEvent: .connect) {data, ack in
            print("socket connected")
        }
        
        socket.on("showAssistantReply") { data, ack in
            if let items = data as? [[String: String]], !items.isEmpty {
                self.agentState = .none
                let agent_reply = items.first!["agent_reply"] ?? ""
                
                /*
                 // Strip out the 'Agent: ' prefix if it's there
                     replies.forEach(function (reply) {
                       if (reply["msg"].includes("Agent: ")) {
                         reply["msg"] = reply["msg"].substring(7);
                       }
                     });
                 */
                
                if agent_reply.hasPrefix("Agent: ") {
                    let model = ChatModel(text: agent_reply, isUserInput: false)
                    self.listChat.append(model)
                }
            }
        }
        
        socket.on("updateAgentType") { data, ask in
            if let items = data as? [[String: String]], !items.isEmpty, items.first!["agent_type"] == "craftassist" {
                self.agentState = .thingking
            }
        }
        
        socket.on("depth") { value, ask in
            Logger.logDebug("recipe depthImg")
            guard let value = value as? [NSDictionary] else { return }
            guard let base64String = value.first?["depthImg"] as? String else { return }
            self.depthImg = self.decodeImage(base64String)
        }
        
        socket.on("rgb") { value, ask in
            Logger.logDebug("recipe rgb data")
            guard let value = value as? [String] else { return }
            self.depthImg = self.decodeImage(value.first ?? "")
        }
        
        socket.connect()
    }
    
    func emit(_ message: String) {
        agentState = .send
        socket.emit("sendCommandToAgent", with: [CustomData(msg: message)], completion: {
            Logger.logDebug("Emit success")
        })
    }
    
    private func decodeImage(_ base64String: String) -> UIImage? {
        guard let data = Data(base64Encoded: base64String) else { return nil }
        let image = UIImage(data: data)
        return image
    }
}

extension HomeViewModel {
    func markImage(value: NotificationAnswer, message_id: String, option: String?) {
        HomeService.shared.markImage(value: value, message_id: message_id, option: option)
    }
    
    func downloadImage(url: String) {
        HomeService.shared.getImage(url: url) { image in
            DispatchQueue.main.async {
                self.settings.notificationObject.setImage(image)
            }
        }
    }
    
    func sendAnchor() {
        settings.request()
    }
}
