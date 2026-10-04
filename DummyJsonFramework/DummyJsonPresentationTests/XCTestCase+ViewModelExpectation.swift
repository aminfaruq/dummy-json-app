//
//  XCTestCase+ViewModelExpectation.swift
//  DummyJsonFramework
//
//  Created by Amin faruq on 04/10/26.
//

import XCTest

extension XCTestCase {
    /// Runs `action`, lets the first spy completion fire, then asserts once the
    /// view model has re-dispached back to the main actor.
    func expect<T: Any>(
           _ sut: T,
           when action: () -> Void,
           complete completion: (() -> Void)? = nil,
           toSatisfy assertion: @escaping () -> Void,
           timeout: TimeInterval = 1.0,
           file: StaticString = #filePath,
           line: UInt = #line
       ) {
           let exp = expectation(description: "Wait for async completion")

           action()
           DispatchQueue.main.async {
               completion?()          // ← optional chaining
               Task { @MainActor in
                   assertion()
                   exp.fulfill()
               }
           }

           wait(for: [exp], timeout: timeout)
       }
}
