//
//  UserViewModel.swift
//  DummyJsonFramework
//
//  Created by Amin faruq on 04/10/26.
//

import DummyJsonFramework
import Foundation
import Combine

public final class UserViewModel {
    
    @Published public private(set) var users: [UserModel] = []
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var errorMessage: String?
    
    private let loader: UserLoader
    
    public init(loader: UserLoader) {
        self.loader = loader
    }
    
    public func load() {
        isLoading = true
        
        loader.loadUsers { [weak self] result in
            guard let self = self else { return }
            self.isLoading = false
            
            switch result {
                case .success(let users):
                    self.users = users
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
            }
        }
    }
}
