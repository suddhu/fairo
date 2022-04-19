import SwiftUI

struct LoginView: View {
    @ObservedObject var viewModel: LoginViewModel
    @State var username: String = ""
    @State var password: String = ""
    @State private var isLoading: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {            
            Text("Welcome")
                .font(Font.largeTitle)
                .foregroundColor(Color.black)
                .padding(.top, 50)
            
            TextField("username", text: $username)
                .padding(.leading, 20)
            SecureField("password", text: $password)
                .padding(.leading, 20)
            
            Button {
                isLoading = true
                viewModel.loginFacebook()
            } label: {
                Text("Facebook Login")
                    .padding(5)
                    .background(Color.blue)
                    .foregroundColor(Color.white)
                    .cornerRadius(55/2)
            }
            
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                    .scaleEffect(3)
            }

            Spacer()
        }
        .onReceive(viewModel.settings.$expride) { _ in
            isLoading = false
        }
        .onAppear {
            viewModel.settings.expride = false
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView(viewModel: LoginViewModel())
    }
}
