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
        
    override func tearDown() {
        URLProtocolStub.stub = nil
        super.tearDown()
    }
    
    func test_getFromURL_performsGETRequest() async {
        let url = anyURL()
        let exp = expectation(description: "Wait for GET request")
        
        URLProtocolStub.stub = { request in
            XCTAssertEqual(request.url, url)
            XCTAssertEqual(request.httpMethod, "GET")
            exp.fulfill()
            return (anyData(), self.makeHTTPURLResponse(statusCode: 200))
        }
        
        _ = try? await makeSUT().get(from: url)
        
        await fulfillment(of: [exp], timeout: 1.0)
    }
    
    func test_getFromURL_deliversErrorOnRequestFailure() async {
        let expectedError = anyNSError()
        
        URLProtocolStub.stub =  { _ in
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
        
        URLProtocolStub.stub  =  { _ in
           (expectedData , expectedResponse)
        }
        
        let (data, response) = try await makeSUT().get(from: anyURL())
        XCTAssertEqual(data, expectedData)
        XCTAssertEqual(response.statusCode, expectedResponse.statusCode)
        XCTAssertEqual(response.url, expectedResponse.url)
        
    }
    
    func test_getFromURL_deliversFailureOnNonHTTPResponse() async {
        let nonHTTPResponse = URLResponse(
            url: anyURL(),
            mimeType: nil,
            expectedContentLength: 0,
            textEncodingName: nil
        )

        URLProtocolStub.stub = { _ in
            (anyData(), nonHTTPResponse)
        }
        
        do {
            _ = try await makeSUT().get(from: anyURL())
            XCTFail("Expected failure")
        } catch {
            XCTAssertTrue(error is URLSessionHTTPClient.UnexpectedValuesRepresentation)
        }
        
    }
    
    // MARK: Helpers
    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> URLSessionHTTPClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        let session = URLSession(configuration: configuration)
        let sut = URLSessionHTTPClient(session: session)
        trackForMemoryLeaks(sut, file: file, line: line)
        return sut
    }
    
    private func makeHTTPURLResponse(statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: anyURL(), statusCode: statusCode, httpVersion: nil, headerFields: nil)!
    }
    
    private final class URLProtocolStub: URLProtocol {
        static var stub: ((URLRequest) throws -> (Data, URLResponse))?
        
        override class func canInit(with request: URLRequest) -> Bool { true }
        
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
        
        override func startLoading() {
            guard let stub = Self.stub else { return }
            
            do {
                let (data, response) = try stub(request)
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
        }
        
        override func stopLoading() {}
    }
}
