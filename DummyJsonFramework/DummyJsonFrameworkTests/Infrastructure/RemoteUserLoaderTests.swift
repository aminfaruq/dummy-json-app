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
                case let .success((data, response)):
                    switch response.statusCode {
                        case 200:
                            guard let root = try? JSONDecoder().decode(RemoteUserRootDTO.self, from: data) else {
                                return completion(.failure(Error.invalidData))
                            }
                            return completion(.success(root.users.map({ $0.toModel() })))
                        default:
                            completion(.failure(Error.invalidData))
                    }
                case .failure:
                    completion(.failure(Error.connectivity))
            }
           
        }
    }
    
    private struct RemoteUserDTO: Decodable {
        let id: Int
        let username: String
        let email: String

        func toModel() -> UserModel {
            UserModel(id: id, username: username, email: email)
        }
    }
    
    private struct RemoteUserRootDTO: Decodable {
        let users: [RemoteUserDTO]
    }

}


final class RemoteUserLoaderTests: XCTestCase {
    
    func test_init_doesNotRequestDataFromURL() {
        let (_, client) = makeSUT()
        
        XCTAssertTrue(client.receivedMessages.isEmpty)
    }
    
    func test_loadUsers_requestDataFromURL() {
        let url = anyURL()
        let (sut, spy) = makeSUT(baseURL: url)
        
        sut.loadUsers { _ in }
        
        XCTAssertEqual(spy.requestedURLs, [url])
    }
    
    func test_loadUsers_requestDataFromURLTwice() {
        let url = anyURL()
        let (sut, spy) = makeSUT(baseURL: url)
        
        sut.loadUsers { _ in }
        sut.loadUsers { _ in }
        
        XCTAssertEqual(spy.requestedURLs, [url, url])
    }
    
    func test_loadUsers_deliversConnectivityErrorOnClientError() {
        let (sut, spy) = makeSUT()
        let clientError = anyNSError()
        
        expect(sut, toCompleteWith: failure(.connectivity), when: {
            spy.complete(with: clientError)
        })
    }
    
    func test_loadUsers_deliversInvalidDataOnNon200Status() {
        let samples = [199, 201, 300, 400, 500]
        
        samples.forEach { code in
            let (sut, spy) = makeSUT()
            expect(sut, toCompleteWith: failure(.invalidData), when: {
                spy.complete(withStatusCode: code, data: anyData())
            })
        }
    }
    
    func test_loadUsers_deliversInvalidDataOn200WithInvalidJSON() {
        let (sut, spy) = makeSUT()
        
        expect(sut, toCompleteWith: failure(.invalidData), when: {
            spy.complete(withStatusCode: 200, data: Data("invalid json".utf8))
        })
    }
    
    
    func test_loadUsers_deliversNoUsersOn200WithEmptyJSONList() {
        let (sut, client) = makeSUT()
        let emptyListJSON = makeUsersJSON([])
        
        expect(sut, toCompleteWith: .success([]), when: {
            client.complete(withStatusCode: 200, data: emptyListJSON)
        })
    }
    
    func test_load_deliversUsersOn200WithValidJSON() {
        let (sut, client) = makeSUT()
        
        let user1 = makeUser(id: 1, username: "emilys", email: "emily@dummyjson.com")
        let user2 = makeUser(id: 2, username: "john_doe", email: "john@dummyjson.com")
        
        let expectedUsers = [user1.model, user2.model]
        let jsonData = makeUsersJSON([user1.json, user2.json])
        
        expect(sut, toCompleteWith: .success(expectedUsers), when: {
            client.complete(withStatusCode: 200, data: jsonData)
        })
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
    
    
    private func makeUser(
        id: Int,
        username: String,
        email: String
    ) -> (model: UserModel, json: [String: Any]) {
        let model = UserModel(id: id, username: username, email: email)
        let json: [String: Any] = [
            "id": id,
            "username": username,
            "email": email
        ]
        
        return (model, json)
    }
    
    private func makeUsersJSON(_ users: [[String: Any]]) -> Data {
        let json: [String: Any] = ["users": users]
        return try! JSONSerialization.data(withJSONObject: json)
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
                case let (.success(received), .success(expected)):
                    XCTAssertEqual(received, expected, file: file, line: line)
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
