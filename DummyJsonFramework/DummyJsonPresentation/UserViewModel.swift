//
//  UserViewModel.swift
//  DummyJsonFramework
//
//  Created by Amin faruq on 04/10/26.
//

import DummyJsonFramework
import Foundation
import Combine

@MainActor
public final class UserViewModel: ObservableObject {
    
    @Published public private(set) var users: [UserModel] = []
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var errorMessage: String?
    
    private let loader: UserLoader
    
    public init(loader: UserLoader) {
        self.loader = loader
    }
    
    public func load() async {
        isLoading = true
        errorMessage = nil
        
        do {
            users = try await loader.loadUsers()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}
