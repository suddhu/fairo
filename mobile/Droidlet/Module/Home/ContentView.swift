import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject var viewModel: HomeViewModel = HomeViewModel()
    @StateObject var settings: UserSettings = .shared

    var body: some View {
        ZStack {
            switch viewModel.dashboardMode {
            case .camera:
                ZStack {
                    CameraPreview(session: viewModel.session)
                        .edgesIgnoringSafeArea(.all)
                        .onAppear {
                            viewModel.startCamera()
                        }
                        .onDisappear {
                            // stop camera
                            viewModel.stopCamera()
                        }
                    VStack {
                        HStack(spacing: 5) {
                            Button {
                                viewModel.capturePhoto()
                            } label: {
                                Text("Take Photo")
                                    .foregroundColor(Color.gray)
                            }
                            .padding(.trailing)
                            Spacer()
                        }
                        Spacer()
                    }.padding(.top, 30)
                }
                .fullScreenCover(isPresented: $viewModel.showEditPhotoVC) {
                    PhotoEditorViewControllerRepresentation(viewModel: viewModel, image: viewModel.image)
                }

            case .ar:
                ZStack {
                    DroidletARViewContainer(viewModel: viewModel)
                        .edgesIgnoringSafeArea(.all)
                    
                    VStack {
                        HStack(spacing: 5) {
                            Button {
                                viewModel.sendAnchor()
                            } label: {
                                Text("Send")
                                    .foregroundColor(Color.gray)
                            }
                            .padding(.trailing)
                            Spacer()
                        }
                        Spacer()
                    }.padding(.top, 30)
                }
                .fullScreenCover(isPresented: $viewModel.showingEditARVC) {
                    InsertPreviewControllerRepresentation(viewModel: viewModel)
                }
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("Notification"))) { _ in
                    let alert = settings.alert(message: "", inputText: "") { name in
                        let message_id = self.settings.notificationObject.message_id
                        HomeService.shared.markImage(value: .no, message_id: message_id, option: name)
                    }

                    if let delegate = UIApplication.shared.delegate as? AppDelegate,
                       let parentViewController = delegate.window?.rootViewController {
                        parentViewController.present(alert, animated: true)
                    }
                    
                }
                .onReceive(settings.$deviceToken) { token in
                    settings.sendTokenToBE(token)
                }
                .onReceive(settings.$reload, perform: { value in
                    if value {
                        viewModel.iosView.sceneView.scene.rootNode.childNodes.forEach { node in
                            if node.name ==  "test" {
                                node.removeFromParentNode()
                            }
                        }
                    }
                })
                .onAppear {
                    viewModel.startARSection()
                }
                .onDisappear() {
                    viewModel.pauseARSection()
                }
            case .video:
                ZStack {
                    Image(uiImage: viewModel.depthImg ?? UIImage())
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                    
                    if viewModel.depthImg != nil {
                        VStack {
                            HStack(spacing: 5) {
                                Button {
                                    viewModel.showEditVideoVC = true
                                } label: {
                                    Text("Edit")
                                        .foregroundColor(Color.gray)
                                }
                                .padding(.leading)
                                Spacer()
                            }
                            Spacer()
                        }
                    }
                }
                .fullScreenCover(isPresented: $viewModel.showEditVideoVC) {
                    PhotoEditorViewControllerRepresentation(viewModel: viewModel, image: viewModel.depthImg)
                }
            }
            
            ControlsView(viewModel: viewModel)
            ChatView(viewModel: viewModel)
        }
        .onAppear {
            viewModel.connectSocket()
            settings.sendTokenToBE(settings.deviceToken)
        }
    }
}
