//
//  UserViewModelTests.swift
//  DummyJsonFramework
//
//  Created by Amin faruq on 04/10/26.
//

import XCTest
import DummyJsonFramework
import DummyJsonPresentation

final class UserViewModelTests: XCTestCase {
    
    @MainActor
    func test_init_hasEmptyUsersAndNotLoading() {
        let (sut, _) = makeSUT()
        
        XCTAssertTrue(sut.users.isEmpty)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
    }
    
    @MainActor
    func test_load_requestsUsersFromLoader() async {
        let (sut, spy) = makeSUT()
        XCTAssertEqual(spy.loadCallCount, 0)
        
        await sut.load()
        XCTAssertEqual(spy.loadCallCount, 1)
        
        await sut.load()
        XCTAssertEqual(spy.loadCallCount, 2)
    }
    
    @MainActor
    func test_load_updatesLoadingStateCorrectly() async {
        let (sut, spy) = makeSUT()
        
        spy.onLoad = { [weak sut] in
            XCTAssertTrue(sut?.isLoading == true, "Expected isLoading to be true while request is in flight")
        }
        
        await sut.load()
        XCTAssertFalse(sut.isLoading, "Expected isLoading to be false after request completes")
    }
    
    @MainActor
    func test_load_deliversUsersOnSuccess() async {
        let (sut, spy) = makeSUT()
        let expectedUsers = [
            UserModel(id: 1, username: "amin", email: "amin@test.com"),
            UserModel(id: 2, username: "faruq", email: "faruq@test.com")
        ]
        spy.stub(with: expectedUsers)
        
        await sut.load()
        
        XCTAssertEqual(sut.users, expectedUsers)
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)
    }
    
    @MainActor
    func test_load_deliversErrorMessageOnFailure() async {
        let (sut, spy) = makeSUT()
        let error = anyNSError()
        spy.stub(with: error)
        
        await sut.load()
        
        XCTAssertTrue(sut.users.isEmpty)
        XCTAssertEqual(sut.errorMessage, error.localizedDescription)
        XCTAssertFalse(sut.isLoading)
    }
    
    // MARK: - Helpers
    
    @MainActor
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
        private(set) var loadCallCount = 0
        private var stub: Result<[UserModel], Error>?
        var onLoad: (() -> Void)?
        
        func stub(with users: [UserModel]) {
            self.stub = .success(users)
        }
        
        func stub(with error: Error) {
            self.stub = .failure(error)
        }
        
        func loadUsers() async throws -> [UserModel] {
            loadCallCount += 1
            onLoad?()
            return try stub?.get() ?? []
        }
    }
}
