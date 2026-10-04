//
//  RemoteUserLoader.swift
//  DummyJsonFramework
//
//  Created by Amin faruq on 04/10/26.
//

import Foundation

public final class RemoteUserLoader: UserLoader {
    
    public enum Error: Swift.Error, LocalizedError, Equatable {
        case connectivity
        case invalidData
        
        public var errorDescription: String? {
            switch self {
                case .connectivity:
                    return "Cannot connect to the server. Check your internet connection."
                case .invalidData:
                    return "The server returned an unexpected response."
            }
        }
        
    }
    
    private let url: URL
    private let client: HTTPClient
    
    public init(url: URL, client: HTTPClient) {
        self.url = url
        self.client = client
    }
    
    public func loadUsers() async throws -> [UserModel] {
        try await withCheckedThrowingContinuation { continuation in
            client.get(from: url) { result in
                switch result {
                    case let .success((data, response)):
                        switch response.statusCode {
                            case 200:
                                guard let root = try? JSONDecoder().decode(RemoteUserRootDTO.self, from: data) else {
                                    return continuation.resume(throwing: Error.invalidData)
                                }
                                continuation.resume(returning: root.users.map({ $0.toModel() }))
                            default:
                                continuation.resume(throwing: Error.invalidData)
                        }
                    case .failure:
                        continuation.resume(throwing: Error.connectivity)
                        
                }
            }
        }
    }
    
    private struct RemoteUserDTO: Decodable {
        let id: Int
        let username: String
        let email: String
        
        func toModel() -> UserModel {
            UserModel(id: id, username: username, email: email)
        }
    }
    
    private struct RemoteUserRootDTO: Decodable {
        let users: [RemoteUserDTO]
    }
    
}
