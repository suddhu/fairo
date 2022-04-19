import Foundation
import Combine
import UIKit

class HomeService {
    static let shared = HomeService()

    func markImage(value: NotificationAnswer, message_id: String, option: String?) {
        guard let _ = HomeEndpoint.markImage(value: value, message_id: message_id, option: option).urlRequest.url else {
            return
        }
        
        let urlRequest = HomeEndpoint.markImage(value: value, message_id: message_id, option: option).urlRequest
        let dataTask = URLSession.shared.dataTask(with: urlRequest) { (data, response, error) in
            if let error = error {
                Logger.logDebug(error.localizedDescription)
                return
            }
            
            guard let response = response as? HTTPURLResponse else { return }
            
            if response.statusCode == 200 {
                guard let data = data else { return }
                Logger.logDebug(String(data: data, encoding: .utf8) ?? "")
            }
        }
        
        dataTask.resume()
    }
    
    func getImage(url: String, completion: @escaping (UIImage?)->()) {
        guard let _ = HomeEndpoint.getImage(url: url).urlRequest.url else { return }
        let dataTask = URLSession.shared.dataTask(with: HomeEndpoint.getImage(url: url).urlRequest) { (data, response, error) in
            if let error = error {
                Logger.logDebug(error.localizedDescription)
                return
            }
            
            guard let response = response as? HTTPURLResponse else { return }
            
            if response.statusCode == 200 {
                guard let data = data else { return }
                completion(UIImage(data: data))
            }
        }
        
        dataTask.resume()
    }
}
