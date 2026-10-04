//
//  UserLoader.swift
//  DummyJsonFramework
//
//  Created by Amin faruq on 04/10/26.
//

import Foundation

public protocol UserLoader {
    func loadUsers() async throws -> [UserModel]
}
