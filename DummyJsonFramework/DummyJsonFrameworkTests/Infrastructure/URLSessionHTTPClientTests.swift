//
//  URLSessionHTTPClientTests.swift
//  DummyJsonFramework
//
//  Created by Amin faruq on 04/10/26.
//

import XCTest
import Foundation
import DummyJsonFramework

final class URLSessionHTTPClientTests: XCTestCase {
    
    private var underlyingSession: URLSession?
    
    override func tearDown() {
        underlyingSession?.invalidateAndCancel()
        underlyingSession = nil
        URLProtocolStub.removeStub()
        super.tearDown()
    }
    
    // MARK: - Request
    
    func test_getFromURL_performsGETRequest() async {
        let url = anyURL()
        let exp = expectation(description: "Wait for GET request")
        
        URLProtocolStub.observe { request in
            XCTAssertEqual(request.url, url)
            XCTAssertEqual(request.httpMethod, "GET")
            exp.fulfill()
        }
        
        _ = try? await makeSUT().get(from: url)
        
        await fulfillment(of: [exp], timeout: 1.0)
    }
    
    // MARK: - Delivery
    
    func test_getFromURL_deliversErrorOnRequestFailure() async {
        let expectedError = anyNSError()
        
        URLProtocolStub.stub { _ in 
            throw expectedError
        }
        
        do {
            _ = try await makeSUT().get(from: anyURL())
            XCTFail("Expected failure, got success")
        } catch {
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, expectedError.domain)
            XCTAssertEqual(nsError.code, expectedError.code)
        }
    }
    
    func test_getFromURL_deliversDataAndResponseOnSuccess() async throws {
        let expectedData = anyData()
        let expectedResponse = makeHTTPURLResponse(statusCode: 200)
        
        URLProtocolStub.stub { _ in
            .success(data: expectedData, response: expectedResponse)
        }
        
        let (data, response) = try await makeSUT().get(from: anyURL())
        XCTAssertEqual(data, expectedData)
        XCTAssertEqual(response.statusCode, expectedResponse.statusCode)
        XCTAssertEqual(response.url, expectedResponse.url)
    }
    
    func test_getFromURL_deliversFailureOnNonHTTPResponse() async {
        let nonHTTPResponse = URLResponse(url: anyURL(), mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
        
        URLProtocolStub.stub { _ in
            .success(data: anyData(), response: nonHTTPResponse)
        }
        
        do {
            _ = try await makeSUT().get(from: anyURL())
            XCTFail("Expected failure")
        } catch {
            XCTAssertTrue(error is URLSessionHTTPClient.UnexpectedValuesRepresentation)
        }
    }
    
    // MARK: - Helpers
    
    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> URLSessionHTTPClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        let session = URLSession(configuration: configuration)
        underlyingSession = session
        let sut = URLSessionHTTPClient(session: session)
        trackForMemoryLeaks(sut, file: file, line: line)
        return sut
    }
    
    private func makeHTTPURLResponse(statusCode: Int, url: URL = anyURL()) -> HTTPURLResponse {
        HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
    }
    
    private final class URLProtocolStub: URLProtocol {
        enum StubResult {
            case failure(Error)
            case success(data: Data?, response: URLResponse?)
        }
        
        private static var result: ((URLRequest) throws -> StubResult)?
        private static var observer: ((URLRequest) -> Void)?
     
        static func stub(_ handler: @escaping (URLRequest) throws -> StubResult) {
            result = handler
            observer = nil
        }
        
        static func observe(_ handler: @escaping (URLRequest) -> Void) {
            observer = handler
            result = nil
        }
        
        static func removeStub() {
            result = nil
            observer = nil
        }
        
        override class func canInit(with request: URLRequest) -> Bool {
            true
        }
        
        override class func canonicalRequest(for request: URLRequest) -> URLRequest {
            request
        }
        
        override func startLoading() {
            if let observer = URLProtocolStub.observer {
                observer(request)
                deliverDefaultResponse()
                return
            }
            
            guard let result = URLProtocolStub.result else {
                deliverDefaultResponse()
                return
            }
            
            do {
                let stub = try result(request)
                switch stub {
                    case let .failure(error):
                        client?.urlProtocol(self, didFailWithError: error)
                    case let .success(data, response):
                        if let response {
                            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                        }
                        if let data {
                            client?.urlProtocol(self, didLoad: data)
                        }
                        client?.urlProtocolDidFinishLoading(self)
                }
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
        }
        
        override func stopLoading() {}
        
        private func deliverDefaultResponse() {
            let response = HTTPURLResponse(url: request.url ?? anyURL(), statusCode: 200, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data())
            client?.urlProtocolDidFinishLoading(self)
        }
    }
}
