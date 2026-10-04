//
//  HTTPClient.swift
//  DummyJsonFramework
//
//  Created by Amin faruq on 04/10/26.
//

import Foundation

public protocol HTTPClientTask {
    func cancel()
}

public protocol HTTPClient {
    typealias Result = Swift.Result<(Data, HTTPURLResponse), Error>
    
    @discardableResult
    func get(
        from url: URL,
        completion: @escaping (Result) -> Void
    ) -> HTTPClientTask
}
