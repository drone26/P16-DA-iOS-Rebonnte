//
//  SessionStoreTests.swift
//  MediStockTests
//
//  Created by Mathieu Arrio on 2026/08/30.
//

import XCTest
@testable import MediStock

@MainActor
final class SessionStoreTests: XCTestCase {

    private var auth: MockAuthService!
    private var sut: SessionStore!

    /// A password that clears the 20-character minimum.
    private let validPassword = String(repeating: "a", count: 20)

    override func setUp() {
        super.setUp()
        auth = MockAuthService()
        sut = SessionStore(auth: auth)
    }

    override func tearDown() {
        sut = nil
        auth = nil
        super.tearDown()
    }

    // MARK: - Validators

    func testIsValidEmail() {
        XCTAssertTrue(sut.isValidEmail("user@example.com"))
        XCTAssertTrue(sut.isValidEmail("first.last+tag@sub.domain.co"))
        XCTAssertFalse(sut.isValidEmail("user@example"))
        XCTAssertFalse(sut.isValidEmail("userexample.com"))
        XCTAssertFalse(sut.isValidEmail(""))
    }

    func testIsValidPassword() {
        XCTAssertFalse(sut.isValidPassword(String(repeating: "a", count: 19)))
        XCTAssertTrue(sut.isValidPassword(String(repeating: "a", count: 20)))
    }

    // MARK: - listen

    func testListenRegistersListenerOnlyOnce() {
        sut.listen()
        sut.listen()
        XCTAssertEqual(auth.addStateListenerCallCount, 1)
    }

    func testListenPropagatesAuthState() {
        sut.listen()

        auth.emitUser(User(uid: "u1", email: "user@example.com"))
        XCTAssertEqual(sut.session?.uid, "u1")

        auth.emitUser(nil)
        XCTAssertNil(sut.session)
    }

    // MARK: - signIn

    func testSignInRejectsInvalidEmail() async {
        await sut.signIn(email: "bad", password: validPassword)
        XCTAssertEqual(sut.errorMessage, "Please enter a valid email address.")
        XCTAssertTrue(auth.signInCalls.isEmpty)
    }

    func testSignInRejectsShortPassword() async {
        await sut.signIn(email: "user@example.com", password: "short")
        XCTAssertEqual(sut.errorMessage, "Password must be at least 20 characters.")
        XCTAssertTrue(auth.signInCalls.isEmpty)
    }

    func testSignInSuccessSetsSession() async {
        auth.stubUser = User(uid: "u1", email: "user@example.com")
        await sut.signIn(email: "user@example.com", password: validPassword)
        XCTAssertEqual(sut.session?.uid, "u1")
        XCTAssertNil(sut.errorMessage)
    }

    func testSignInFailureSetsErrorAndLeavesSession() async {
        auth.errorToThrow = TestError.boom
        await sut.signIn(email: "user@example.com", password: validPassword)
        XCTAssertNil(sut.session)
        XCTAssertEqual(sut.errorMessage, TestError.boom.localizedDescription)
    }

    // MARK: - signUp

    func testSignUpRejectsInvalidEmail() async {
        await sut.signUp(email: "bad", password: validPassword)
        XCTAssertEqual(sut.errorMessage, "Please enter a valid email address.")
        XCTAssertTrue(auth.signUpCalls.isEmpty)
    }

    func testSignUpRejectsShortPassword() async {
        await sut.signUp(email: "user@example.com", password: "short")
        XCTAssertEqual(sut.errorMessage, "Password must be at least 20 characters.")
        XCTAssertTrue(auth.signUpCalls.isEmpty)
    }

    func testSignUpSuccessSetsSession() async {
        auth.stubUser = User(uid: "u2", email: "user@example.com")
        await sut.signUp(email: "user@example.com", password: validPassword)
        XCTAssertEqual(sut.session?.uid, "u2")
        XCTAssertNil(sut.errorMessage)
    }

    func testSignUpFailureSetsError() async {
        auth.errorToThrow = TestError.boom
        await sut.signUp(email: "user@example.com", password: validPassword)
        XCTAssertNil(sut.session)
        XCTAssertEqual(sut.errorMessage, TestError.boom.localizedDescription)
    }

    // MARK: - signOut

    func testSignOutClearsSession() {
        auth.emitUserAfterListen(sut: sut, user: User(uid: "u1", email: "user@example.com"))
        sut.signOut()
        XCTAssertTrue(auth.signOutCalled)
        XCTAssertNil(sut.session)
    }

    func testSignOutFailureSetsError() {
        auth.signOutError = TestError.boom
        sut.signOut()
        XCTAssertEqual(sut.errorMessage, TestError.boom.localizedDescription)
    }

    // MARK: - unbind

    func testUnbindCancelsListener() {
        sut.listen()
        sut.unbind()
        XCTAssertEqual(auth.cancelledTokenCount, 1)

        sut.listen()
        XCTAssertEqual(auth.addStateListenerCallCount, 2)
    }
}

private extension MockAuthService {
    /// Convenience: wires the listener then pushes a user, so a test can put the
    /// `SessionStore` into a signed-in state without reaching for Firebase.
    func emitUserAfterListen(sut: SessionStore, user: User) {
        sut.listen()
        emitUser(user)
    }
}
