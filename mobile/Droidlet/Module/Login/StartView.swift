import SwiftUI

struct StartView: View {
    @StateObject var viewModel: LoginViewModel = LoginViewModel()
    @StateObject var settings: UserSettings = .shared

    var body: some View {
        if (SessionManage.shared.accessToken != nil) && !settings.expride {
            return AnyView(ContentView())
        } else {
            return AnyView(LoginView(viewModel: viewModel))
        }
    }
}

struct StartView_Previews: PreviewProvider {
    static var previews: some View {
        StartView()
    }
}
