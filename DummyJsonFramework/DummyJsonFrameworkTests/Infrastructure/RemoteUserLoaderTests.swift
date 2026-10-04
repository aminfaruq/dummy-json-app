//
//  RemoteUserLoaderTests.swift
//  DummyJsonFramework
//
//  Created by Amin faruq on 04/10/26.
//

import DummyJsonFramework
import Foundation
import XCTest

final class RemoteUserLoaderTests: XCTestCase {
    
    func test_init_doesNotRequestDataFromURL() {
        let (_, client) = makeSUT()
        
        XCTAssertTrue(client.receivedMessages.isEmpty)
    }
    
    func test_loadUsers_requestDataFromURL() async {
        let url = anyURL()
        let (sut, spy) = makeSUT(baseURL: url)
        spy.stub(with: .failure(anyNSError()))
        
        _ = try? await sut.loadUsers()
        
        XCTAssertEqual(spy.requestedURLs, [url])
    }
    
    func test_loadUsers_requestDataFromURLTwice() async {
        let url = anyURL()
        let (sut, spy) = makeSUT(baseURL: url)
        spy.stub(with: .failure(anyNSError()))
        
        _ = try? await sut.loadUsers()
        _ = try? await sut.loadUsers()
        
        XCTAssertEqual(spy.requestedURLs, [url, url])
    }
    
    func test_loadUsers_deliversConnectivityErrorOnClientError() async {
        let (sut, spy) = makeSUT()
        spy.stub(with: .failure(anyNSError()))
        
        do {
            _ = try await sut.loadUsers()
            XCTFail("Expected failure, got success instead")
        } catch let error as RemoteUserLoader.Error {
            XCTAssertEqual(error, .connectivity)
        } catch {
            XCTFail("Expected RemoteUserLoader.Error, got \(error)")
        }
    }
    
    func test_loadUsers_deliversInvalidDataOnNon200Status() async {
        let samples = [199, 201, 300, 400, 500]
        
        for code in samples {
            let (sut, spy) = makeSUT()
            spy.stub(statusCode: code, data: anyData())
            
            do {
                _ = try await sut.loadUsers()
                XCTFail("Expected failure for status \(code)")
            } catch let error as RemoteUserLoader.Error {
                XCTAssertEqual(error, .invalidData)
            } catch {
                XCTFail("Expected RemoteUserLoader.Error, got \(error)")
            }
        }
    }
    
    func test_loadUsers_deliversInvalidDataOn200WithInvalidJSON() async throws {
        let (sut, spy) = makeSUT()
        
        spy.stub(statusCode: 200, data: Data("invalid json".utf8))
        
        do {
            _ = try await sut.loadUsers()
            XCTFail("Expected invalidData error, got success instead")
        } catch let error as RemoteUserLoader.Error {
            XCTAssertEqual(error, .invalidData)
        } catch {
            XCTFail("Expected RemoteUserLoader.Error, got \(error) instead")
        }
    }
    
    
    func test_loadUsers_deliversNoUsersOn200WithEmptyJSONList() async throws {
        let (sut, spy) = makeSUT()
        let emptyListJSON = makeUsersJSON([])
        
        spy.stub(statusCode: 200, data: emptyListJSON)
        
        let receivedUsers = try await sut.loadUsers()
        
        XCTAssertEqual(receivedUsers, [])
    }
    
    func test_loadUsers_deliversUsersOn200WithValidJSON() async throws {
        let (sut, spy) = makeSUT()
        
        let user1 = makeUser(id: 1, username: "emilys", email: "emily@dummyjson.com")
        let user2 = makeUser(id: 2, username: "john_doe", email: "john@dummyjson.com")
        let expectedUsers = [user1.model, user2.model]
        let jsonData = makeUsersJSON([user1.json, user2.json])
        
        spy.stub(statusCode: 200, data: jsonData)
        
        let receivedUsers = try await sut.loadUsers()
        XCTAssertEqual(receivedUsers, expectedUsers)
    }
    
    // MARK: HELPERS
    private func makeSUT(
        baseURL: URL = anyURL(),
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (sut: RemoteUserLoader, spy: HTTPClientSpy) {
        let spy = HTTPClientSpy()
        let sut = RemoteUserLoader(url: baseURL, client: spy)
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
    
    
    private class HTTPClientSpy: HTTPClient {
        struct ReceivedMessages: Equatable {
            let url: URL
            let method: String
        }
        
        private(set) var receivedMessages = [ReceivedMessages]()
        private var stub: HTTPClient.Result?
        
        var requestedURLs: [URL] {
            receivedMessages.map(\.url)
        }
        
        func get(from url: URL, completion: @escaping (HTTPClient.Result) -> Void) -> any HTTPClientTask {
            receivedMessages.append(ReceivedMessages(url: url, method: "GET"))
            
            if let stub = stub {
                completion(stub)
            }
            
            return Task()
        }
        
        func stub(with result: HTTPClient.Result) {
            self.stub = result
        }
        
        func stub(statusCode: Int, data: Data) {
            let response = HTTPURLResponse(url: anyURL(), statusCode: statusCode, httpVersion: nil, headerFields: nil)!
            self.stub = .success((data, response))
        }
        
        private struct Task: HTTPClientTask {
            func cancel() {}
        }
    }
}
