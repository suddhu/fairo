import Foundation
import FBSDKCoreKit
import FBSDKLoginKit
import FirebaseAuth
import Combine

class LoginViewModel: ObservableObject {    
    let loginManager = LoginManager()
    let loginService = LoginService()
    
    var settings: UserSettings = .shared
    
    var cancellables = Set<AnyCancellable>()

    func loginFacebook() {
        loginManager.logIn(permissions: ["email"], from: nil) { (result, error) in
            if error != nil {
                SessionManage.shared.logout()
                self.settings.expride = false
                return
            }
            guard let token = AccessToken.current else {
                print("Failed to get access token")
                SessionManage.shared.logout()
                self.settings.expride = false
                return
            }
            
            if let cancel = result?.isCancelled, cancel {
                SessionManage.shared.logout()
                self.settings.expride = false
                return
            }
            
            FirebaseAuthManager().login(credential: FacebookAuthProvider.credential(withAccessToken: token.tokenString)) {[weak self] (success, token) in
                if let token = token {
                    self?.login(token)
                }
            }
        }
    }
    
    func login(_ token: String) {
        loginService.login(token)
            .sink { completion in
                switch completion {
                case .failure(let error):
                    Logger.logDebug(error.localizedDescription)
                    SessionManage.shared.logout()
                    DispatchQueue.main.async {
                        self.settings.expride = false
                    }
                case .finished:
                    break
                }
            } receiveValue: { model in
                SessionManage.shared.storeAccessToken(model.access_token)
                DispatchQueue.main.async {
                    self.settings.expride = false
                }
            }
            .store(in: &cancellables)
    }
}
