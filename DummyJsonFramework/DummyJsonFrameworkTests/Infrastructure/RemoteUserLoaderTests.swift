//
//  RemoteUserLoaderTests.swift
//  DummyJsonFramework
//
//  Created by Amin faruq on 04/10/26.
//

import DummyJsonFramework
import Foundation
import XCTest

final class RemoteUserLoader {
    
    private let baseURL: URL
    private let client: HTTPClient
    
    public init(baseURL: URL, client: HTTPClient) {
        self.baseURL = baseURL
        self.client = client
    }
    
    func loadUsers(completion: @escaping (UserLoader.Result) -> Void) {
        client.get(from: baseURL) { _  in }
    }
}

final class RemoteUserLoaderTests: XCTestCase {
    
    func test_init_doesNotRequestDataFromURL() {
        let (_, client) = makeSUT()
        
        XCTAssertTrue(client.receivedMessages.isEmpty)
    }
    
    func test_load_requestDataFromURL() {
        let url = anyURL()
        let (sut, spy) = makeSUT(baseURL: url)
        
        sut.loadUsers { _ in }
        
        XCTAssertEqual(spy.requestedURLs, [url])
    }
    
    
    // MARK: HELPERS
    private func makeSUT(
        baseURL: URL = anyURL(),
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (sut: RemoteUserLoader, spy: HTTPClientSpy) {
        let spy = HTTPClientSpy()
        let sut = RemoteUserLoader(baseURL: baseURL, client: spy)
        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(spy, file: file, line: line)
        return (sut, spy)
    }
    
    private class HTTPClientSpy: HTTPClient {
        
        struct ReceivedMessages: Equatable {
            let url: URL
            let method: String
        }
        
        private(set) var receivedMessages = [ReceivedMessages]()
        private var completions = [(url: URL, completion: (HTTPClient.Result) -> Void)]()
        private(set) var cancelledURLs = [URL]()
        
        var requestedURLs: [URL] {
            receivedMessages.map(\.url)
        }
        
        func get(from url: URL, completion: @escaping (HTTPClient.Result) -> Void) -> any DummyJsonFramework.HTTPClientTask {
            receivedMessages.append(ReceivedMessages(url: url, method: ""))
            completions.append((url, completion))
            return Task(onCancel: { [weak self] in self?.cancelledURLs.append(url) })
        }
        
        
        private struct Task: HTTPClientTask {
            let onCancel: () -> Void
            
            func cancel() {
                onCancel()
            }
        }
        
    }
}
