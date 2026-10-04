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
    
}

final class RemoteUserLoaderTests: XCTestCase {
    
    func test_init_doesNotRequestDataFromURL() {
        let (_, client) = makeSUT()
        
        XCTAssertTrue(client.receivedMessages.isEmpty)
    }
    
    
    // MARK: HELPERS
    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> (sut: RemoteUserLoader, spy: HTTPClientSpy) {
        let sut = RemoteUserLoader()
        let spy = HTTPClientSpy()
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
        
        func get(from url: URL, completion: @escaping (HTTPClient.Result) -> Void) -> any DummyJsonFramework.HTTPClientTask {
            return Task()
        }
        
        
        private struct Task: HTTPClientTask {
            func cancel() {
                
            }
        }
        
    }
}
