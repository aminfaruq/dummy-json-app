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
    
    private let baseURL: URL
    private let client: HTTPClient
    
    public init(baseURL: URL, client: HTTPClient) {
        self.baseURL = baseURL
        self.client = client
    }
    
    func loadUsers(completion: @escaping (UserLoader.Result) -> Void) {
        client.get(from: baseURL) { result in
            switch result {
                case .success:
                    completion(.failure(Error.invalidData))
                case .failure:
                    completion(.failure(Error.connectivity))
            }
           
        }
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
    
    func test_load_requestDataFromURLTwice() {
        let url = anyURL()
        let (sut, spy) = makeSUT(baseURL: url)
        
        sut.loadUsers { _ in }
        sut.loadUsers { _ in }
        
        XCTAssertEqual(spy.requestedURLs, [url, url])
    }
    
    func test_load_deliversConnectivityErrorOnClientError() {
        let (sut, spy) = makeSUT()
        let clientError = anyNSError()
        
        expect(sut, toCompleteWith: failure(.connectivity), when: {
            spy.complete(with: clientError)
        })
    }
    
    func test_load_deliversInvalidDataOnNon200Status() {
        let samples = [199, 201, 300, 400, 500]
        
        samples.forEach { code in
            let (sut, spy) = makeSUT()
            expect(sut, toCompleteWith: failure(.invalidData), when: {
                spy.complete(withStatusCode: code, data: anyData())
            })
        }
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
    
    private func failure(_ error: RemoteUserLoader.Error) -> UserLoader.Result {
        .failure(error)
    }
    
    private func expect(
        _ sut: RemoteUserLoader,
        toCompleteWith expectedResult: UserLoader.Result,
        when action: () -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let exp = expectation(description: "Wait for load completion")
        
        sut.loadUsers { receivedResult in
            switch (receivedResult, expectedResult) {
                case let (.failure(received as RemoteUserLoader.Error), .failure(expected as RemoteUserLoader.Error)):
                    XCTAssertEqual(received, expected, file: file, line: line)
                default:
                    XCTFail("Expected \(expectedResult) got \(receivedResult)", file: file, line: line)
            }
            exp.fulfill()
        }
        
        action()
        wait(for: [exp], timeout: 1.0)
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
        
        func complete(with error: Error, at index: Int = 0) {
            completions[index].completion(.failure(error))
        }
        
        func complete(
            withStatusCode code: Int,
            data: Data,
            at index: Int = 0
        ) {
            let response = HTTPURLResponse(
                url: completions[index].url,
                statusCode: code,
                httpVersion: nil,
                headerFields: nil)!
            completions[index].completion(.success((data, response)))
        }
        
        private struct Task: HTTPClientTask {
            let onCancel: () -> Void
            
            func cancel() {
                onCancel()
            }
        }
        
    }
}
