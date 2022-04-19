import SwiftUI

struct ChatView: View {
    @ObservedObject var viewModel: HomeViewModel
    @State private var editing = false
    
    var body: some View {
        VStack(spacing: 5) {
            Spacer()
            VStack {
                HStack(spacing: 5) {
                    Spacer()
                    Button {
                        viewModel.showChat = false
                    } label: {
                        Text("Close")
                            .foregroundColor(Color.white)
                    }
                    .padding(.trailing)
                }
                
                if viewModel.showChat {
                    ChatDetailView(viewModel: viewModel)
                }
                
                HStack {
                    TextField("Chat", text: $viewModel.inputTextChat, onEditingChanged: { edit in
                        self.editing = edit
                        viewModel.showChat = true
                    }, onCommit: {
                        print("COMITTED!")
                        if viewModel.inputTextChat.isEmpty {return}
                        let model = ChatModel(text: viewModel.inputTextChat, isUserInput: true)
                        viewModel.listChat.append(model)
                        viewModel.emit(viewModel.inputTextChat)
                        viewModel.inputTextChat = ""
                    })
                        .textFieldStyle(CustomTextFieldStyle(focused: $editing))
                }
            }
        }
    }
}
