//
//  HTTPClient.swift
//  DummyJsonFramework
//
//  Created by Amin faruq on 04/10/26.
//

import Foundation

public protocol HTTPClient {
    func get(from url: URL) async throws -> (Data, HTTPURLResponse)
}
