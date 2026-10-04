//
//  UserViewModelTests.swift
//  DummyJsonFramework
//
//  Created by Amin faruq on 04/10/26.
//

import XCTest
import DummyJsonFramework
import Combine

final class UserViewModel {
    
    @Published public private(set) var users: [UserModel] = []
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var errorMessage: String?
    
    private let loader: UserLoader
    
    public init(loader: UserLoader) {
        self.loader = loader
    }
    
    public func load() {
        isLoading = true
        
        loader.loadUsers { _ in
            
        }
    }
}

final class UserViewModelTests : XCTestCase {
    
    
    func test_init_hasEmptyUsersAndNotLoading() {
        let (sut, _) = makeSUT()
        
        XCTAssertTrue(sut.users.isEmpty)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
    }
    
    func test_load_setsIsLoading() {
        let (sut, _) = makeSUT()
        
        sut.load()
        
        XCTAssertTrue(sut.isLoading)
    }
    
    func test_load_requestUsersFromLoader() {
        let (sut, spy) = makeSUT()
        XCTAssertEqual(spy.loadCallCount, 0)
        
        sut.load()
        XCTAssertEqual(spy.loadCallCount,  1)
        
        sut.load()
        XCTAssertEqual(spy.loadCallCount, 2)
    }
    
    // MARK: - Helpers
    
    private func makeSUT(
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (sut: UserViewModel, spy: UserLoaderSpy) {
        let spy = UserLoaderSpy()
        let sut = UserViewModel(loader: spy)
        trackForMemoryLeaks(spy, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        return (sut, spy)
    }
    
    private class UserLoaderSpy: UserLoader {
        private var completions = [(UserLoader.Result) -> Void]()
        
        var loadCallCount: Int {
            completions.count
        }
        
        func loadUsers(completion: @escaping (UserLoader.Result) -> Void) {
            completions.append(completion)
        }
        
        func complete(with users: [UserModel] = [], at index: Int = 0) {
            completions[index](.success(users))
        }
        
        func complete(withError error: Error, at index: Int = 0) {
            completions[index](.failure(error))
        }
    }
    
}
