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
}

final class UserViewModelTests : XCTestCase {
    
    
    func test_init_hasEmptyUsersAndNotLoading() {
        let (sut, _) = makeSUT()
        
        XCTAssertTrue(sut.users.isEmpty)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
    }
    
    // MARK: - Helpers
    
    private func makeSUT(
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (sut: UserViewModel, spy: UserLoader) {
        let spy = UserLoaderSpy()
        let sut = UserViewModel(loader: spy)
        trackForMemoryLeaks(spy, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        return (sut, spy)
    }
    
    private class UserLoaderSpy: UserLoader {
        
        func loadUsers(completion: @escaping (UserLoader.Result) -> Void) {
            
        }
        
        
        
    }
    
}
