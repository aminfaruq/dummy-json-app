//
//  UserModel.swift
//  DummyJsonFramework
//
//  Created by Amin faruq on 04/10/26.
//

import Foundation

public struct UserModel {
    let id: Int
    let username: String
    let email: String
    
    public init(id: Int, username: String, email: String) {
        self.id = id
        self.username = username
        self.email = email
    }
}
