//
//  UserLoader.swift
//  DummyJsonFramework
//
//  Created by Amin faruq on 04/10/26.
//

import Foundation

public protocol UserLoader {
    typealias Result = Swift.Result<[UserModel], Error>
    
    func loadUsers(completion: @escaping (Result) -> Void)
}
