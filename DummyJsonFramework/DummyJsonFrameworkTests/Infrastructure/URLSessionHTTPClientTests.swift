//
//  URLSessionHTTPClientTests.swift
//  DummyJsonFramework
//
//  Created by Amin faruq on 04/10/26.
//

import XCTest
import Foundation
import DummyJsonFramework

final class URLSessionHTTPClient: HTTPClient {
    
    struct UnexpectedValuesRepresentation: Error {}
    
    private let session: URLSession
    
    public convenience init() {
        self.init(session: URLSession(configuration: .ephemeral))
    }
    
    public init(session: URLSession) {
        self.session = session
    }
    
    @discardableResult
    func get(from url: URL, completion: @escaping (HTTPClient.Result) -> Void) -> any HTTPClientTask {
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

final class URLSessionHTTPClientTests: XCTestCase {
    
    private var underlyingSession: URLSession?
    
    override func tearDown() {
        underlyingSession?.invalidateAndCancel()
        underlyingSession = nil
        URLProtocolStub.removeStub()
        super.tearDown()
    }
    
    // MARK: - Request
    
    func test_getFromURL_performsGETRequest() {
        let url = anyURL()
        let exp = expectation(description: "Wait for GET request")
        
        URLProtocolStub.observe { request in
            XCTAssertEqual(request.url, url)
            XCTAssertEqual(request.httpMethod, "GET")
            exp.fulfill()
        }
        
        makeSUT()
            .get(from: url) { _ in }
        
        wait(for: [exp], timeout: 1.0)
    }
    
    // MARK: - Delivery
    
    func test_getFromURL_deliversErrorOnRequestFailure() {
        let expectedError = anyNSError()
        let exp = expectation(description: "Wait for request failure")
        
        URLProtocolStub.stub { _ in 
            throw expectedError
        }
        
        makeSUT().get(from: anyURL()) { result in
            switch result {
                case let .failure(error):
                    let nsError = error as NSError
                    XCTAssertEqual(nsError.domain, expectedError.domain)
                    XCTAssertEqual(nsError.code, expectedError.code)
                case .success:
                    XCTFail("Expected failure, got success")
            }
            exp.fulfill()
        }
        
        wait(for: [exp], timeout: 1.0)
    }
    
    func test_getFromURL_deliversDataAndResponseOnSuccess() {
        let expectedData = anyData()
        let expectedResponse = makeHTTPURLResponse(statusCode: 200)
        let exp = expectation(description: "Wait for success")
        
        URLProtocolStub.stub { _ in
                .success(data: expectedData, response: expectedResponse)
        }
        
        makeSUT().get(from: anyURL()) { result in
            switch result {
                case let .success((data, response)):
                    XCTAssertEqual(data, expectedData)
                    XCTAssertEqual(response.statusCode, expectedResponse.statusCode)
                    XCTAssertEqual(response.url, expectedResponse.url)
                case let .failure(error):
                    XCTFail("Expected failute, got \(error)")
            }
            
            exp.fulfill()
            
        }
        
        wait(for: [exp], timeout: 1.0)
    }
    
    
    func test_getFromURL_deliversFailureOnNilDataAndNilResponse() {
        let exp = expectation(description: "Wait for nil data + nil response")
        
        URLProtocolStub.stub { _ in
                .success(data: nil, response: nil)
        }
        
        makeSUT().get(from: anyURL()) { result in
            switch result {
            case .success:
                XCTFail("Expected failure")
            case let .failure(error):
                XCTAssertTrue(error is URLSessionHTTPClient.UnexpectedValuesRepresentation)
            }
            exp.fulfill()
        }
        
        wait(for: [exp], timeout: 1.0)
    }
    
    func test_getFromURL_deliversFailureOnNonHTTPResponse() {
        let exp = expectation(description: "Wait for non-HTTP response")
        let nonHTTPResponse = URLResponse(url: anyURL(), mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
        
        URLProtocolStub.stub { _ in
                .success(data: anyData(), response: nonHTTPResponse)
        }
        
        makeSUT().get(from: anyURL()) { result in
            switch result {
            case .success:
                XCTFail("Expected failure")
            case let .failure(error):
                XCTAssertTrue(error is URLSessionHTTPClient.UnexpectedValuesRepresentation)
            }
            exp.fulfill()
        }
        
        wait(for: [exp], timeout: 1.0)
    }
    
    func test_getFromURL_deliversFailureOnNonNilDataNilResponse() {
        let exp = expectation(description: "Wait for non-nil data + nil response")
        
        URLProtocolStub.stub { _ in
                .success(data: anyData(), response: nil)
        }
        
        makeSUT().get(from: anyURL()) { result in
            switch result {
            case .success:
                XCTFail("Expected failure")
            case let .failure(error):
                XCTAssertTrue(error is URLSessionHTTPClient.UnexpectedValuesRepresentation)
            }
            exp.fulfill()
        }
        
        wait(for: [exp], timeout: 1.0)
    }
    
    func test_getFromURL_returnsCancellableTask() {
        let exp = expectation(description: "Wait for request to be observed")

        URLProtocolStub.observe { request in
            exp.fulfill()
        }

        let sut = makeSUT()
        let task = sut.get(from: anyURL()) { _ in }

        XCTAssertNotNil(task)
        wait(for: [exp], timeout: 1.0)
        task.cancel()
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
