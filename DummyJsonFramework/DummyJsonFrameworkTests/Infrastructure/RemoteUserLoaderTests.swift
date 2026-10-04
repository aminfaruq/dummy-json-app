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
        
        XCTAssertTrue(client.requestedURLs.isEmpty)
    }
    
    func test_loadUsers_requestsDataFromURL() async {
        let url = anyURL()
        let (sut, spy) = makeSUT(baseURL: url)
        spy.stub(with: .failure(anyNSError()))
        
        _ = try? await sut.loadUsers()
        
        XCTAssertEqual(spy.requestedURLs, [url])
    }
    
    func test_loadUsers_requestsDataFromURLTwice() async {
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
        
        await assertThat(sut, throws: .connectivity)
    }
    
    func test_loadUsers_deliversInvalidDataOnNon200Status() async {
        let samples = [199, 201, 300, 400, 500]
        
        for code in samples {
            let (sut, spy) = makeSUT()
            spy.stub(statusCode: code, data: anyData())
            
            await assertThat(sut, throws: .invalidData)
        }
    }
    
    func test_loadUsers_deliversInvalidDataOn200WithInvalidJSON() async {
        let (sut, spy) = makeSUT()
        spy.stub(statusCode: 200, data: Data("invalid json".utf8))
        
        await assertThat(sut, throws: .invalidData)
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

    // MARK: - Helpers
    
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
    
    private func assertThat(
        _ sut: RemoteUserLoader,
        throws expectedError: RemoteUserLoader.Error,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await sut.loadUsers()
            XCTFail("Expected \(expectedError), got success instead", file: file, line: line)
        } catch let error as RemoteUserLoader.Error {
            XCTAssertEqual(error, expectedError, file: file, line: line)
        } catch {
            XCTFail("Expected \(expectedError), got \(error) instead", file: file, line: line)
        }
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
        private(set) var requestedURLs = [URL]()
        private var stub: Result<(Data, HTTPURLResponse), Error>?
        
        func stub(with result: Result<(Data, HTTPURLResponse), Error>) {
            self.stub = result
        }
        
        func stub(statusCode: Int, data: Data) {
            let response = HTTPURLResponse(url: anyURL(), statusCode: statusCode, httpVersion: nil, headerFields: nil)!
            self.stub = .success((data, response))
        }
        
        func get(from url: URL) async throws -> (Data, HTTPURLResponse) {
            requestedURLs.append(url)
            return try stub?.get() ?? (Data(), HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
    }
}
