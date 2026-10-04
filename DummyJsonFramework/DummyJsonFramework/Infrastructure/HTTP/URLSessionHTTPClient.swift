//
//  URLSessionHTTPClient.swift
//  DummyJsonFramework
//
//  Created by Amin faruq on 04/10/26.
//

import Foundation

public final class URLSessionHTTPClient: HTTPClient {
    
    public struct UnexpectedValuesRepresentation: Error {}
    
    private let session: URLSession
    
    public convenience init() {
        self.init(session: URLSession(configuration: .ephemeral))
    }
    
    public init(session: URLSession) {
        self.session = session
    }
    
    @discardableResult
    public func get(from url: URL, completion: @escaping (HTTPClient.Result) -> Void) -> any HTTPClientTask {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        return perform(request, completion: completion)
    }
    
    private final class URLSessionHTTPClientTask: HTTPClientTask {
        private let task: URLSessionTask
        
        init(task: URLSessionTask) {
            self.task = task
        }
        
        func cancel() {
            task.cancel()
        }
    }
    
    private func perform(_ request: URLRequest, completion: @escaping (HTTPClient.Result) -> Void) -> HTTPClientTask {
        let task = session.dataTask(with: request) { data, response, error in
        
            completion(URLSessionHTTPClient.map(data: data, response: response, error: error))
        }
        task.resume()
        return URLSessionHTTPClientTask(task: task)
    }
    
    private static func map(data: Data?, response: URLResponse?, error: Error?) -> HTTPClient.Result {
        if let error {
            return .failure(error)
        } else if let data, let response = response as? HTTPURLResponse {
            return .success((data, response))
        } else {
            return .failure(UnexpectedValuesRepresentation())
        }
    }
   
}
