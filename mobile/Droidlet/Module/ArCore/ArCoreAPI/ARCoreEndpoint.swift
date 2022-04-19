import Foundation

enum ARCoreEndpoint {
    case uploadImage(data: Data, fileName: String)
    case getImage(fileName: String)
}

extension ARCoreEndpoint: APIRequest {
    var urlRequest: URLRequest {
        switch self {
        case .uploadImage(let data, let fileName):
            let urlComponents = NSURLComponents(string: APIMainEnvironmentConfig.baseURL + "/image/upload")!
            guard let url = urlComponents.url
                else {preconditionFailure("Invalid URL format")}
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            let accessToken = SessionManage.shared.accessToken ?? ""
            let boundary = UUID().uuidString

            let headers = [
                        "Authorization": "Bearer \(accessToken)",
                        "Content-Type": "multipart/form-data; boundary=\(boundary)"
                    ]
            request.allHTTPHeaderFields = headers
            
            var body = Data()
            body.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
            body.append(data)
            body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
            return request
        case .getImage(let fileName):
            let urlComponents = NSURLComponents(string: APIMainEnvironmentConfig.baseURL + "/image/get")!
            guard let url = urlComponents.url
                else {preconditionFailure("Invalid URL format")}
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            let accessToken = SessionManage.shared.accessToken ?? ""
            let headers = [
                        //"content-type": "image/png",
                        "Authorization": "Bearer \(accessToken)"
                    ]
            request.allHTTPHeaderFields = headers
            return request
        }
    }
}
