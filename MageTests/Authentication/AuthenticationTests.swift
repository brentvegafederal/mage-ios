//
//  AuthenticationTests.m
//  MAGETests
//
//  Created by Dan Barela on 1/9/18.
//  Copyright © 2018 National Geospatial Intelligence Agency. All rights reserved.
//

import XCTest
import OHHTTPStubs

@testable import MAGE

class AuthenticationTestDelegate: AuthenticationDelegate {
    var authenticationSuccessfulCalled = false
    var couldNotAuthenticateCalled = false
    var changeServerUrlCalled = false
    
    func authenticationSuccessful() {
        print("✅ authenticationSuccessful() was called in AuthenticationCoordinator")
        authenticationSuccessfulCalled = true
    }
    
    func couldNotAuthenticate() {
        couldNotAuthenticateCalled = true
    }
    
    func changeServerUrl() {
        changeServerUrlCalled = true
    }
}

final class AuthenticationTests: AsyncMageCoreDataTestCase {
    
    var window: UIWindow!
    
    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        window = TestHelpers.getKeyWindowVisible();
    }
    
    @MainActor
    override func tearDown() async throws {
        try await super.tearDown()
        window.rootViewController = nil;
    }
    
    @MainActor
    func testLoginWithRegisteredDevice() async {
        TestHelpers.setupTestSession()
        
        let navigationController = TestHelpers.initializeTestNavigation()
        let delegate = MockAuthenticationCoordinatorDelegate()
        let server: MageServer = await TestHelpers.getTestServer()
        let coordinator = AuthenticationCoordinator(
            navigationController: navigationController,
            andDelegate: delegate,
            andScheme: MAGEScheme.scheme(),
            context: context
        )!
        
        print("🚀 Starting AuthenticationCoordinator")
        coordinator.start(server)
        
        await TestHelpers.waitForLoginScreen(navigationController: navigationController)
        TestHelpers.executeTestLogin(coordinator: coordinator)
        await TestHelpers.handleDisclaimerAcceptance(coordinator: coordinator, navigationController: navigationController)
        await TestHelpers.waitForAuthenticationSuccess(delegate: delegate)
        
        print("🔍 Final Check: authenticationSuccessfulCalled = \(delegate.authenticationSuccessfulCalled)")
        XCTAssertTrue(delegate.authenticationSuccessfulCalled, "❌ Expected authenticationSuccessful to be called")
    }
    
    @MainActor
    func testRegisterDevice() async {
        TestHelpers.setupTestSession()
        MockMageServer.stubRegisterDeviceResponses() // ✅ Uses both general + custom stubs
        
        let navigationController = TestHelpers.initializeTestNavigation()
        let delegate = MockAuthenticationCoordinatorDelegate()
        let server: MageServer = await TestHelpers.getTestServer()
        
        let coordinator = AuthenticationCoordinator(
            navigationController: navigationController,
            andDelegate: delegate,
            andScheme: MAGEScheme.scheme(),
            context: context
        )!
        
        print("🚀 Starting AuthenticationCoordinator")
        coordinator.start(server)
        
        await TestHelpers.waitForLoginScreen(navigationController: navigationController)
        
        let deviceRegistered = XCTestExpectation(description: "device registered")
        TestHelpers.executeTestLoginForRegistration(coordinator: coordinator, expectation: deviceRegistered)
        
        await fulfillment(of: [deviceRegistered], timeout: 2)
        
        tester().waitForView(withAccessibilityLabel: "Registration Sent")
    }
    
    // TODO: Is this even a smart way to do this?
    @MainActor
    func testLoginWithUpdatedUser() async {
        // ✅ Step 1: Setup test session & pre-create user
        TestHelpers.setupTestSession()
        MageCoreDataFixtures.addUser(userId: "1a")
        
        let navigationController = TestHelpers.initializeTestNavigation()
        let delegate = MockAuthenticationCoordinatorDelegate()
        let server: MageServer = await TestHelpers.getTestServer()
        
        // ✅ Step 2: Verify user info BEFORE login
        context.performAndWait {
            let user = context.fetchFirst(User.self, key: UserKey.remoteId.key, value: "1a")!
            XCTAssertEqual(user.name, "User ABC", "❌ User name should be 'User ABC' before login")
        }
        
        // ✅ Step 3: Start authentication
        let coordinator = AuthenticationCoordinator(
            navigationController: navigationController,
            andDelegate: delegate,
            andScheme: MAGEScheme.scheme(),
            context: context
        )!
        
        print("🚀 Starting AuthenticationCoordinator")
        coordinator.start(server)
        
        await TestHelpers.waitForLoginScreen(navigationController: navigationController)
        
        // ✅ Step 4: Execute login
        let loginExpectation = XCTestExpectation(description: "User attempts to log in")
        TestHelpers.executeTestLogin(coordinator: coordinator, expectation: loginExpectation)
        
        // ✅ Step 5: Proceed through disclaimer if applicable
        await TestHelpers.waitForDisclaimerScreen(navigationController: navigationController)
        await TestHelpers.handleDisclaimerAcceptance(coordinator: coordinator, navigationController: navigationController)
        
        await TestHelpers.waitForAuthenticationSuccess(delegate: delegate)
        XCTAssertTrue(delegate.authenticationSuccessfulCalled, "❌ Authentication was not successful")
        
        // ✅ Step 6: Verify user info AFTER login
        context.performAndWait {
            let user = context.fetchFirst(User.self, key: UserKey.remoteId.key, value: "1a")!
            XCTAssertEqual(user.name, "Firstname Lastname", "❌ User name was not updated after login")
        }
    }
    
}   // BRENT: Added here to keep it close to rest of test

    // TODO: These tests need to be redone, if deemed needed
    // BRENT: This one "testWorkOffline" would fail because it is accessing UserDefaults for 1 thing
    //        Also, it would have "local" for authentication, but not "offline"
    //        Ended up being a rabbit-hole that is proving to not be worth going.
//
//    @MainActor
//    func testWorkOffline() async {
//        // ✅ Step 1: Setup test session with offline mode enabled
//        TestHelpers.setupTestSession()
//        UserDefaults.standard.set(true, forKey: "deviceRegistered")
//        UserDefaults.standard.set(TestHelpers.defaultLoginParameters(), forKey: "loginParameters")
//        
//        let navigationController = TestHelpers.initializeTestNavigation()
//        let delegate = MockAuthenticationCoordinatorDelegate()
//        let server: MageServer = await TestHelpers.getTestServer()
//        let coordinator = AuthenticationCoordinator(
//            navigationController: navigationController,
//            andDelegate: delegate,
//            andScheme: MAGEScheme.scheme(),
//            context: context
//        )!
//        
//        print("🚀 Starting AuthenticationCoordinator")
//        coordinator.start(server)
//        
//        // ✅ Step 2: Wait for login screen to appear
//        await TestHelpers.waitForLoginScreen(navigationController: navigationController)
//        
//        // ✅ Step 3: Setup network failure on /auth/local/signin
//        let apiSigninResponseArrived = XCTestExpectation(description: "response of /auth/local/signin complete")
//        
//        stub(condition: isMethodPOST() &&
//             isHost("magetest") &&
//             isPath("/auth/local/signin")
//        ) { request in
//            print("🚨 Stubbing network failure for request: \(request.url?.absoluteString ?? "Unknown")")
//            apiSigninResponseArrived.fulfill()
//            let notConnectedError = NSError(domain: NSURLErrorDomain, code: URLError.notConnectedToInternet.rawValue)
//            return HTTPStubsResponse(error: notConnectedError)
//        }
//        
//        // ✅ Step 4: Attempt login (which will fail due to no network)
//        let loginDelegate = coordinator as! LoginDelegate
//        let loginExpectation = XCTestExpectation(description: "Attempt to log in")
//        
//        print("🔄 Attempting login...")
//        print(TestHelpers.defaultLoginParameters())
//        
//        loginDelegate.login(withParameters: TestHelpers.defaultLoginParameters(), withAuthenticationStrategy: "local") { authenticationStatus, errorString in
//            print("🔍 Authentication status received: \(authenticationStatus), Error: \(errorString ?? "None")")
//            XCTAssertEqual(authenticationStatus, .UNABLE_TO_AUTHENTICATE, "❌ Expected authentication to fail due to no network.")
//            loginExpectation.fulfill()
//        }
//        
//        // ✅ Step 5: Verify offline authentication is attempted
//        let offlineAuthExpectation = XCTestExpectation(description: "Attempt offline authentication")
//        
//        coordinator.workOffline(parameters: TestHelpers.defaultLoginParameters()) { authenticationStatus, errorString in
//            print("🌐 Offline Authentication Attempted - Status: \(authenticationStatus).")
//            
//            if let _ = server.authenticationModules?["offline"] as? AuthenticationProtocol {
//                XCTAssertEqual(authenticationStatus, .AUTHENTICATION_SUCCESS, "❌ Expected successful offline authentication.")
//            } else {
//                XCTAssertEqual(authenticationStatus, .UNABLE_TO_AUTHENTICATE, "❌ Expected failure when offline authentication is unavailable.")
//            }
//            offlineAuthExpectation.fulfill()
//        }
//        
//        // ✅ Step 6: Ensure all expectations are met
//        //        await fulfillment(of: [apiSigninResponseArrived, loginExpectation, offlineAuthExpectation], timeout: 5)
//        //        await fulfillment(of: [apiSigninResponseArrived, loginExpectation], timeout: 5)
//        await fulfillment(of: [apiSigninResponseArrived], timeout: 5)
//    }
    

    
    // TODO: Flaky Test
    // TODO: This test does not appear to test what it says it is testing.
//    @MainActor
//    func testLoginWithInactiveUserOLD() async {
//        let baseUrlKey = "baseServerUrl"
//
//        let defaults = UserDefaults.standard
//        defaults.set("https://magetest", forKey: baseUrlKey)
//        defaults.set(true, forKey: "deviceRegistered")
//
//        let navigationController = UINavigationController()
//        window.rootViewController = navigationController
//
//        let delegate = AuthenticationTestDelegate()
//
//        let url = MageServer.baseURL()
//
//        let apiResponseArrived = XCTestExpectation(description: "response of /api complete")
//
//        stub(condition: isMethodGET() &&
//             isHost("magetest") &&
//             isPath("/api")
//        ) { (request) -> HTTPStubsResponse in
//            apiResponseArrived.fulfill()
//            return HTTPStubsResponse(fileAtPath: OHPathForFile("apiSuccess.json", AuthenticationTests.self)!, statusCode: 200, headers: ["Content-Type": "application/json"])
//        }
//
//        let server: MageServer = await withCheckedContinuation { continuation in
//            MageServer.server(url: url) { (server: MageServer) in
//                continuation.resume(returning: server)
//            } failure: { error in
//                XCTFail()
//            }
//        }
//        XCTAssertEqual(url?.absoluteString, "https://magetest")
//
//        let apiSigninResponseArrived = XCTestExpectation(description: "response of /auth/local/signin complete")
//
//        stub(condition: isMethodPOST() &&
//             isHost("magetest") &&
//             isPath("/auth/local/signin")
//        ) { (request) -> HTTPStubsResponse in
//            apiSigninResponseArrived.fulfill()
//            return HTTPStubsResponse(fileAtPath: OHPathForFile("signinSuccessInactiveUser.json", AuthenticationTests.self)!, statusCode: 200, headers: ["Content-Type": "application/json"])
//        }
//
//        let coordinator = AuthenticationCoordinator(navigationController: navigationController, andDelegate: delegate, andScheme: MAGEScheme.scheme(), context: context)!
//        coordinator.start(server)
//
//        await awaitBlockTrue(block: {
//            if let _ = navigationController.topViewController as? LoginViewController {
//                return true
//            }
//            return false
//        }, timeout: 2)
//
//        let parameters: [String: Any] = [
//            "username": "test",
//            "password": "test",
//            "uid": "uuid",
//            "strategy": [
//                "identifier": "local"
//            ],
//            "appVersion": "6.0.0"
//        ]
//
//        let deviceRegistered = XCTestExpectation(description: "device registered")
//
//        let loginDelegate = coordinator as! LoginDelegate
//        loginDelegate.login(withParameters: parameters, withAuthenticationStrategy: "local") { authenticationStatus, errorString in
//            // login complete
//            XCTAssertTrue(authenticationStatus == AuthenticationStatus.ACCOUNT_CREATION_SUCCESS)
//            let token = StoredPassword.retrieveStoredToken()
////            let mageSessionToken = MageSessionManager.shared().getToken()
//            XCTAssertEqual(token, "TOKEN")
////            XCTAssertEqual(token, mageSessionToken)
//        }
//
//        await awaitBlockTrue(block: {
//            self.viewTester().usingLabel("MAGE Account Created").view != nil
//        }, timeout: 2)
//
//        await fulfillment(of: [apiSigninResponseArrived], timeout: 2)
//    }
    
    /// TODO: This test does not appear to test what it says it is testing.
    /// TODO: Need to come back to this
//    @MainActor
//    func testLoginWithInactiveUser() async {
//        // ✅ Setup test session and mock responses
//        TestHelpers.setupTestSession()
//        MockMageServer.stubAPIResponses()
//
//        // ✅ Modify stub for inactive user response
//        stub(condition: isMethodPOST() && isHost("magetest") && isPath("/auth/local/signin")) { _ in
//            return HTTPStubsResponse(fileAtPath: OHPathForFile("signinSuccessInactiveUser.json", AuthenticationTests.self)!,
//                                     statusCode: 200, headers: ["Content-Type": "application/json"])
//        }
//
//        let navigationController = TestHelpers.setupNavigationController()
//        let delegate = MockAuthenticationCoordinatorDelegate()
//        let server: MageServer = await TestHelpers.getTestServer()
//
//        let coordinator = AuthenticationCoordinator(
//            navigationController: navigationController,
//            andDelegate: delegate,
//            andScheme: MAGEScheme.scheme(),
//            context: context
//        )!
//
//        print("🚀 Starting AuthenticationCoordinator")
//        coordinator.start(server)
//
//        // ✅ Ensure login screen appears
//        await TestHelpers.waitForLoginScreen(navigationController: navigationController)
//
//        // ✅ Execute login
//        let loginExpectation = XCTestExpectation(description: "User attempts to log in")
//        TestHelpers.executeTestLogin(coordinator: coordinator, expectation: loginExpectation)
//
//        // ✅ Check if "MAGE Account Created" message appears
//        await TestHelpers.waitForCondition({
//            let messageLabel = navigationController.topViewController?.view?.viewWithTag(99) as? UILabel
//            return messageLabel?.text == "MAGE Account Created"
//        }, timeout: 2, message: "❌ 'MAGE Account Created' label not found")
//
//        await fulfillment(of: [loginExpectation], timeout: 2)
//    }
    
    
    
    
//    @MainActor
//    func testWorkOffline_SuccessfulLogin() async {
//        // ✅ Setup test session and stored password
//        TestHelpers.setupTestSession()
//        StoredPassword.persistPassword(toKeyChain: "goodpassword")
//
//        let navigationController = TestHelpers.setupNavigationController()
//        let delegate = MockAuthenticationCoordinatorDelegate()
//        let server: MageServer = await TestHelpers.getTestServer()
//
//        // ✅ Stub login attempt to fail due to no internet connection
//        stub(condition: isMethodPOST() && isHost("magetest") && isPath("/auth/local/signin")) { _ in
//            print("📡 Simulating no internet connection")
//            let notConnectedError = NSError(domain: NSURLErrorDomain, code: URLError.notConnectedToInternet.rawValue)
//            return HTTPStubsResponse(error: notConnectedError)
//        }
//
//        // ✅ Start authentication process
//        let coordinator = AuthenticationCoordinator(
//            navigationController: navigationController,
//            andDelegate: delegate,
//            andScheme: MAGEScheme.scheme(),
//            context: context
//        )!
//
//        print("🚀 Starting AuthenticationCoordinator")
//        coordinator.start(server)
//
//        await TestHelpers.waitForLoginScreen(navigationController: navigationController)
//
//        // ✅ Execute login attempt (expecting failure)
//        let loginExpectation = XCTestExpectation(description: "User attempts to log in")
//        TestHelpers.executeTestLogin(coordinator: coordinator, expectation: loginExpectation)
//
//        // ✅ Simulate offline login
//        await TestHelpers.waitForCondition({
//            let alertController = navigationController.topViewController as? UIAlertController
//            return alertController?.title == "Disconnected Login"
//        }, timeout: 2, message: "❌ 'Disconnected Login' alert not displayed")
//
//        coordinator.workOffline(parameters: TestHelpers.defaultLoginParameters()) { authenticationStatus, errorString in
//            XCTAssertEqual(authenticationStatus, AuthenticationStatus.AUTHENTICATION_SUCCESS, "❌ Offline login should succeed")
//            loginExpectation.fulfill()
//        }
//
//        await fulfillment(of: [loginExpectation], timeout: 2)
//    }
//
//    
//    
//    @MainActor
//    func testLoginWithNoConnection() async {
//        let baseUrlKey = "baseServerUrl"
//        
//        let defaults = UserDefaults.standard
//        defaults.set("https://magetest", forKey: baseUrlKey)
//        defaults.set(true, forKey: "deviceRegistered")
//        
//        let navigationController = UINavigationController()
//        window.rootViewController = navigationController
//        
//        let delegate = AuthenticationTestDelegate()
//        
//        let url = MageServer.baseURL()
//        
//        let apiResponseArrived = XCTestExpectation(description: "response of /api complete")
//        
//        stub(condition: isMethodGET() &&
//             isHost("magetest") &&
//             isPath("/api")
//        ) { (request) -> HTTPStubsResponse in
//            apiResponseArrived.fulfill()
//            return HTTPStubsResponse(fileAtPath: OHPathForFile("apiSuccess.json", AuthenticationTests.self)!, statusCode: 200, headers: ["Content-Type": "application/json"])
//        }
//        
//        let server: MageServer = await withCheckedContinuation { continuation in
//            MageServer.server(url: url) { (server: MageServer) in
//                continuation.resume(returning: server)
//            } failure: { error in
//                XCTFail()
//            }
//        }
//        XCTAssertEqual(url?.absoluteString, "https://magetest")
//        
//        let apiSigninResponseArrived = XCTestExpectation(description: "response of /auth/local/signin complete")
//
//        stub(condition: isMethodPOST() &&
//             isHost("magetest") &&
//             isPath("/auth/local/signin")
//        ) { (request) -> HTTPStubsResponse in
//            apiSigninResponseArrived.fulfill()
//            let notConnectedError = NSError(domain: NSURLErrorDomain, code: URLError.notConnectedToInternet.rawValue)
//            return HTTPStubsResponse(error:notConnectedError)
//        }
//        
//        let coordinator = AuthenticationCoordinator(navigationController: navigationController, andDelegate: delegate, andScheme: MAGEScheme.scheme(), context: context)!
//        coordinator.start(server)
//        
//        await awaitBlockTrue(block: {
//            if let _ = navigationController.topViewController as? LoginViewController {
//                return true
//            }
//            return false
//        }, timeout: 2)
//        
//        let parameters: [String: Any] = [
//            "username": "test",
//            "password": "test",
//            "uid": "uuid",
//            "strategy": [
//                "identifier": "local"
//            ],
//            "appVersion": "6.0.0"
//        ]
//        
//        let deviceRegistered = XCTestExpectation(description: "device registered")
//
//        let loginDelegate = coordinator as! LoginDelegate
//        loginDelegate.login(withParameters: parameters, withAuthenticationStrategy: "local") { authenticationStatus, errorString in
//            // login complete
//            XCTAssertTrue(authenticationStatus == AuthenticationStatus.ACCOUNT_CREATION_SUCCESS)
//            let token = StoredPassword.retrieveStoredToken()
////            let mageSessionToken = MageSessionManager.shared().getToken()
//            XCTAssertEqual(token, "TOKEN")
////            XCTAssertEqual(token, mageSessionToken)
//        }
//        
//        await awaitBlockTrue(block: {
//            self.viewTester().usingLabel("Unable to Login").view != nil
//        }, timeout: 2)
//                
//        await fulfillment(of: [apiSigninResponseArrived], timeout: 2)
//    }
//    
//    // TODO: Flaky Test
//    @MainActor
//    func testLoginFailed() async {
//        let baseUrlKey = "baseServerUrl"
//        
//        let defaults = UserDefaults.standard
//        defaults.set("https://magetest", forKey: baseUrlKey)
//        defaults.set(true, forKey: "deviceRegistered")
//        
//        let navigationController = UINavigationController()
//        window.rootViewController = navigationController
//        
//        let delegate = AuthenticationTestDelegate()
//        
//        let url = MageServer.baseURL()
//        
//        let apiResponseArrived = XCTestExpectation(description: "response of /api complete")
//        
//        stub(condition: isMethodGET() &&
//             isHost("magetest") &&
//             isPath("/api")
//        ) { (request) -> HTTPStubsResponse in
//            apiResponseArrived.fulfill()
//            return HTTPStubsResponse(fileAtPath: OHPathForFile("apiSuccess.json", AuthenticationTests.self)!, statusCode: 200, headers: ["Content-Type": "application/json"])
//        }
//        
//        let server: MageServer = await withCheckedContinuation { continuation in
//            MageServer.server(url: url) { (server: MageServer) in
//                continuation.resume(returning: server)
//            } failure: { error in
//                XCTFail()
//            }
//        }
//        XCTAssertEqual(url?.absoluteString, "https://magetest")
//        
//        let apiSigninResponseArrived = XCTestExpectation(description: "response of /auth/local/signin complete")
//
//        stub(condition: isMethodPOST() &&
//             isHost("magetest") &&
//             isPath("/auth/local/signin")
//        ) { (request) -> HTTPStubsResponse in
//            apiSigninResponseArrived.fulfill()
//            let response = HTTPStubsResponse()
//            response.statusCode = 304
//            return response
//        }
//        
//        let coordinator = AuthenticationCoordinator(navigationController: navigationController, andDelegate: delegate, andScheme: MAGEScheme.scheme(), context: context)!
//        coordinator.start(server)
//        
//        await awaitBlockTrue(block: {
//            if let _ = navigationController.topViewController as? LoginViewController {
//                return true
//            }
//            return false
//        }, timeout: 2)
//        
//        let parameters: [String: Any] = [
//            "username": "test",
//            "password": "test",
//            "uid": "uuid",
//            "strategy": [
//                "identifier": "local"
//            ],
//            "appVersion": "6.0.0"
//        ]
//        
//        let deviceRegistered = XCTestExpectation(description: "device registered")
//
//        let loginDelegate = coordinator as! LoginDelegate
//        loginDelegate.login(withParameters: parameters, withAuthenticationStrategy: "local") { authenticationStatus, errorString in
//            // login complete
//            XCTAssertTrue(authenticationStatus == AuthenticationStatus.AUTHENTICATION_ERROR)
//            let token = StoredPassword.retrieveStoredToken()
////            let mageSessionToken = MageSessionManager.shared().getToken()
//            XCTAssertEqual(token, "TOKEN")
////            XCTAssertEqual(token, mageSessionToken)
//        }
//        
//        await awaitBlockTrue(block: {
//            self.viewTester().usingLabel("Login Failed").view != nil
//        }, timeout: 2)
//                
//        await fulfillment(of: [apiSigninResponseArrived], timeout: 2)
//    }
//    
//    @MainActor
//    func testLoginWithNoConnectionForToken() async {
//        let baseUrlKey = "baseServerUrl"
//        
//        let defaults = UserDefaults.standard
//        defaults.set("https://magetest", forKey: baseUrlKey)
//        defaults.set(true, forKey: "deviceRegistered")
//        
//        let navigationController = UINavigationController()
//        window.rootViewController = navigationController
//        
//        let delegate = AuthenticationTestDelegate()
//        
//        let url = MageServer.baseURL()
//        
//        let apiResponseArrived = XCTestExpectation(description: "response of /api complete")
//        
//        stub(condition: isMethodGET() &&
//             isHost("magetest") &&
//             isPath("/api")
//        ) { (request) -> HTTPStubsResponse in
//            apiResponseArrived.fulfill()
//            return HTTPStubsResponse(fileAtPath: OHPathForFile("apiSuccess.json", AuthenticationTests.self)!, statusCode: 200, headers: ["Content-Type": "application/json"])
//        }
//        
//        let server: MageServer = await withCheckedContinuation { continuation in
//            MageServer.server(url: url) { (server: MageServer) in
//                continuation.resume(returning: server)
//            } failure: { error in
//                XCTFail()
//            }
//        }
//        XCTAssertEqual(url?.absoluteString, "https://magetest")
//        
//        let apiSigninResponseArrived = XCTestExpectation(description: "response of /auth/local/signin complete")
//
//        stub(condition: isMethodPOST() &&
//             isHost("magetest") &&
//             isPath("/auth/local/signin")
//        ) { (request) -> HTTPStubsResponse in
//            apiSigninResponseArrived.fulfill()
//            return HTTPStubsResponse(fileAtPath: OHPathForFile("signinSuccess.json", AuthenticationTests.self)!, statusCode: 200, headers: ["Content-Type": "application/json"])
//        }
//        
//        let apiTokenStub = XCTestExpectation(description: "response of /auth/token complete")
//
//        stub(condition: isMethodPOST() &&
//             isHost("magetest") &&
//             isPath("/auth/token")
//        ) { (request) -> HTTPStubsResponse in
//            apiTokenStub.fulfill()
//            let notConnectedError = NSError(domain: NSURLErrorDomain, code: URLError.notConnectedToInternet.rawValue)
//            return HTTPStubsResponse(error:notConnectedError)
//        }
//        
//        let coordinator = AuthenticationCoordinator(navigationController: navigationController, andDelegate: delegate, andScheme: MAGEScheme.scheme(), context: context)!
//        coordinator.start(server)
//        
//        await awaitBlockTrue(block: {
//            if let _ = navigationController.topViewController as? LoginViewController {
//                return true
//            }
//            return false
//        }, timeout: 2)
//        
//        let parameters: [String: Any] = [
//            "username": "test",
//            "password": "test",
//            "uid": "uuid",
//            "strategy": [
//                "identifier": "local"
//            ],
//            "appVersion": "6.0.0"
//        ]
//        
//        let deviceRegistered = XCTestExpectation(description: "device registered")
//
//        let loginDelegate = coordinator as! LoginDelegate
//        loginDelegate.login(withParameters: parameters, withAuthenticationStrategy: "local") { authenticationStatus, errorString in
//            // login complete
//            XCTAssertTrue(authenticationStatus == AuthenticationStatus.AUTHENTICATION_SUCCESS)
//            let token = StoredPassword.retrieveStoredToken()
////            let mageSessionToken = MageSessionManager.shared().getToken()
//            XCTAssertEqual(token, "TOKEN")
////            XCTAssertEqual(token, mageSessionToken)
//        }
//        
//        await awaitBlockTrue(block: {
//            self.viewTester().usingLabel("Unable to Login").view != nil
//        }, timeout: 2)
//       
//        await fulfillment(of: [apiSigninResponseArrived, apiTokenStub], timeout: 2)
//    }
//    
//    // TODO: Flaky Test
//    @MainActor
//    func testLoginServerIncompatible() async {
//        let baseUrlKey = "baseServerUrl"
//        
//        let defaults = UserDefaults.standard
//        defaults.set("https://magetest", forKey: baseUrlKey)
//        defaults.set(true, forKey: "deviceRegistered")
//        
//        let navigationController = UINavigationController()
//        window.rootViewController = navigationController
//        
//        let delegate = AuthenticationTestDelegate()
//        
//        let url = MageServer.baseURL()
//        
//        let apiResponseArrived = XCTestExpectation(description: "response of /api complete")
//        
//        stub(condition: isMethodGET() &&
//             isHost("magetest") &&
//             isPath("/api")
//        ) { (request) -> HTTPStubsResponse in
//            apiResponseArrived.fulfill()
//            return HTTPStubsResponse(fileAtPath: OHPathForFile("apiSuccess.json", AuthenticationTests.self)!, statusCode: 200, headers: ["Content-Type": "application/json"])
//        }
//        
//        let server: MageServer = await withCheckedContinuation { continuation in
//            MageServer.server(url: url) { (server: MageServer) in
//                continuation.resume(returning: server)
//            } failure: { error in
//                XCTFail()
//            }
//        }
//        XCTAssertEqual(url?.absoluteString, "https://magetest")
//        
//        let apiSigninResponseArrived = XCTestExpectation(description: "response of /auth/local/signin complete")
//
//        stub(condition: isMethodPOST() &&
//             isHost("magetest") &&
//             isPath("/auth/local/signin")
//        ) { (request) -> HTTPStubsResponse in
//            apiSigninResponseArrived.fulfill()
//            return HTTPStubsResponse(fileAtPath: OHPathForFile("signinSuccess.json", AuthenticationTests.self)!, statusCode: 200, headers: ["Content-Type": "application/json"])
//        }
//        
//        let apiTokenStub = XCTestExpectation(description: "response of /auth/token complete")
//
//        stub(condition: isMethodPOST() &&
//             isHost("magetest") &&
//             isPath("/auth/token")
//        ) { (request) -> HTTPStubsResponse in
//            apiTokenStub.fulfill()
//            return HTTPStubsResponse(
//                jsonObject: [
//                    "expirationDate":"2020-02-20T01:25:44.796Z",
//                    "api":[
//                        "name":"mage-server",
//                        "description":"Geospatial situation awareness application.",
//                        "version":[
//                            "major":5,
//                            "minor":0,
//                            "micro":0
//                        ],
//                        "authenticationStrategies":[
//                            "local":[
//                                "passwordMinLength":14
//                            ]
//                        ],
//                        "provision":[
//                            "strategy":"uid"
//                        ]
//                    ]
//                ],
//                statusCode: 200,
//                headers: ["Content-Type": "application/json"]
//            )
//        }
//        
//        let coordinator = AuthenticationCoordinator(navigationController: navigationController, andDelegate: delegate, andScheme: MAGEScheme.scheme(), context: context)!
//        coordinator.start(server)
//        
//        await awaitBlockTrue(block: {
//            if let _ = navigationController.topViewController as? LoginViewController {
//                return true
//            }
//            return false
//        }, timeout: 2)
//        
//        let parameters: [String: Any] = [
//            "username": "test",
//            "password": "test",
//            "uid": "uuid",
//            "strategy": [
//                "identifier": "local"
//            ],
//            "appVersion": "6.0.0"
//        ]
//        
//        let deviceRegistered = XCTestExpectation(description: "device registered")
//
//        let loginDelegate = coordinator as! LoginDelegate
//        loginDelegate.login(withParameters: parameters, withAuthenticationStrategy: "local") { authenticationStatus, errorString in
//            // login complete
//            XCTAssertTrue(authenticationStatus == AuthenticationStatus.AUTHENTICATION_ERROR)
//            let token = StoredPassword.retrieveStoredToken()
////            let mageSessionToken = MageSessionManager.shared().getToken()
//            XCTAssertEqual(token, "TOKEN")
////            XCTAssertEqual(token, mageSessionToken)
//        }
//        
//        await awaitBlockTrue(block: {
//            self.viewTester().usingLabel("Login Failed").view != nil
//        }, timeout: 2)
//       
//        await fulfillment(of: [apiSigninResponseArrived, apiTokenStub], timeout: 2)
//    }
//    
//    // TODO: Flaky Test
//    @MainActor
//    func testLoginWithOtherErrorForToken() async {
//        let baseUrlKey = "baseServerUrl"
//        
//        let defaults = UserDefaults.standard
//        defaults.set("https://magetest", forKey: baseUrlKey)
//        defaults.set(true, forKey: "deviceRegistered")
//        
//        let navigationController = UINavigationController()
//        window.rootViewController = navigationController
//        
//        let delegate = AuthenticationTestDelegate()
//        
//        let url = MageServer.baseURL()
//        
//        let apiResponseArrived = XCTestExpectation(description: "response of /api complete")
//        
//        stub(condition: isMethodGET() &&
//             isHost("magetest") &&
//             isPath("/api")
//        ) { (request) -> HTTPStubsResponse in
//            apiResponseArrived.fulfill()
//            return HTTPStubsResponse(fileAtPath: OHPathForFile("apiSuccess.json", AuthenticationTests.self)!, statusCode: 200, headers: ["Content-Type": "application/json"])
//        }
//        
//        let server: MageServer = await withCheckedContinuation { continuation in
//            MageServer.server(url: url) { (server: MageServer) in
//                continuation.resume(returning: server)
//            } failure: { error in
//                XCTFail()
//            }
//        }
//        XCTAssertEqual(url?.absoluteString, "https://magetest")
//        
//        let apiSigninResponseArrived = XCTestExpectation(description: "response of /auth/local/signin complete")
//
//        stub(condition: isMethodPOST() &&
//             isHost("magetest") &&
//             isPath("/auth/local/signin")
//        ) { (request) -> HTTPStubsResponse in
//            apiSigninResponseArrived.fulfill()
//            return HTTPStubsResponse(fileAtPath: OHPathForFile("signinSuccess.json", AuthenticationTests.self)!, statusCode: 200, headers: ["Content-Type": "application/json"])
//        }
//        
//        let apiTokenStub = XCTestExpectation(description: "response of /auth/token complete")
//
//        stub(condition: isMethodPOST() &&
//             isHost("magetest") &&
//             isPath("/auth/token")
//        ) { (request) -> HTTPStubsResponse in
//            apiTokenStub.fulfill()
//            let badServerResponse = NSError(domain: NSURLErrorDomain, code: URLError.badServerResponse.rawValue)
//            return HTTPStubsResponse(error:badServerResponse)
//        }
//        
//        let coordinator = AuthenticationCoordinator(navigationController: navigationController, andDelegate: delegate, andScheme: MAGEScheme.scheme(), context: context)!
//        coordinator.start(server)
//        
//        await awaitBlockTrue(block: {
//            if let _ = navigationController.topViewController as? LoginViewController {
//                return true
//            }
//            return false
//        }, timeout: 2)
//        
//        let parameters: [String: Any] = [
//            "username": "test",
//            "password": "test",
//            "uid": "uuid",
//            "strategy": [
//                "identifier": "local"
//            ],
//            "appVersion": "6.0.0"
//        ]
//        
//        let deviceRegistered = XCTestExpectation(description: "device registered")
//
//        let loginDelegate = coordinator as! LoginDelegate
//        loginDelegate.login(withParameters: parameters, withAuthenticationStrategy: "local") { authenticationStatus, errorString in
//            // login complete
//            XCTAssertTrue(authenticationStatus == AuthenticationStatus.AUTHENTICATION_ERROR)
//            let token = StoredPassword.retrieveStoredToken()
////            let mageSessionToken = MageSessionManager.shared().getToken()
//            XCTAssertEqual(token, "TOKEN")
////            XCTAssertEqual(token, mageSessionToken)
//        }
//        
//        await awaitBlockTrue(block: {
//            self.viewTester().usingLabel("Login Failed").view != nil
//        }, timeout: 2)
//       
//        await fulfillment(of: [apiSigninResponseArrived, apiTokenStub], timeout: 2)
//    }
//    
//    // TODO: Flaky Test
//    @MainActor
//    func testLoginFailWithRegisteredDevice() async {
//        let baseUrlKey = "baseServerUrl"
//        
//        let defaults = UserDefaults.standard
//        defaults.set("https://magetest", forKey: baseUrlKey)
//        defaults.set(true, forKey: "deviceRegistered")
//        
//        let navigationController = UINavigationController()
//        window.rootViewController = navigationController
//        
//        let delegate = AuthenticationTestDelegate()
//        
//        let url = MageServer.baseURL()
//        
//        let apiResponseArrived = XCTestExpectation(description: "response of /api complete")
//        
//        stub(condition: isMethodGET() &&
//             isHost("magetest") &&
//             isPath("/api")
//        ) { (request) -> HTTPStubsResponse in
//            apiResponseArrived.fulfill()
//            return HTTPStubsResponse(fileAtPath: OHPathForFile("apiSuccess.json", AuthenticationTests.self)!, statusCode: 200, headers: ["Content-Type": "application/json"])
//        }
//        
//        let server: MageServer = await withCheckedContinuation { continuation in
//            MageServer.server(url: url) { (server: MageServer) in
//                continuation.resume(returning: server)
//            } failure: { error in
//                XCTFail()
//            }
//        }
//        XCTAssertEqual(url?.absoluteString, "https://magetest")
//        
//        let coordinator = AuthenticationCoordinator(navigationController: navigationController, andDelegate: delegate, andScheme: MAGEScheme.scheme(), context: context)!
//        coordinator.start(server)
//        
//        await awaitBlockTrue(block: {
//            if let _ = navigationController.topViewController as? LoginViewController {
//                return true
//            }
//            return false
//        }, timeout: 2)
//        
//        let parameters: [String: Any] = [
//            "username": "test",
//            "password": "test",
//            "uid": "uuid",
//            "strategy": [
//                "identifier": "local"
//            ],
//            "appVersion": "6.0.0"
//        ]
//        
//        let apiSigninResponseArrived = XCTestExpectation(description: "response of /auth/local/signin complete")
//
//        stub(condition: isMethodPOST() &&
//             isHost("magetest") &&
//             isPath("/auth/local/signin")
//        ) { (request) -> HTTPStubsResponse in
//            apiSigninResponseArrived.fulfill()
//            return HTTPStubsResponse(data: "Test".data(using: .utf8)!, statusCode: 401, headers: nil)
//        }
//        
//
//        let loginDelegate = coordinator as! LoginDelegate
//        loginDelegate.login(withParameters: parameters, withAuthenticationStrategy: "local") { authenticationStatus, errorString in
//            // login complete
//            XCTAssertTrue(authenticationStatus == AuthenticationStatus.AUTHENTICATION_ERROR)
//            let token = StoredPassword.retrieveStoredToken()
//            XCTAssertEqual(token, "TOKEN")
//        }
//        
//        await fulfillment(of: [apiSigninResponseArrived], timeout: 2)
//        
//        await awaitBlockTrue(block: {
//            self.viewTester().usingLabel("Login Failed").view != nil
//        }, timeout: 2)
//    }
//    
//    // TODO: Flaky Test
//    @MainActor
//    func testLoginWithInvalidToken() async {
//        let baseUrlKey = "baseServerUrl"
//        
//        let defaults = UserDefaults.standard
//        defaults.set("https://magetest", forKey: baseUrlKey)
//        defaults.set(true, forKey: "deviceRegistered")
//        
//        let navigationController = UINavigationController()
//        window.rootViewController = navigationController
//        
//        let delegate = AuthenticationTestDelegate()
//        
//        let url = MageServer.baseURL()
//        
//        let apiResponseArrived = XCTestExpectation(description: "response of /api complete")
//        
//        stub(condition: isMethodGET() &&
//             isHost("magetest") &&
//             isPath("/api")
//        ) { (request) -> HTTPStubsResponse in
//            apiResponseArrived.fulfill()
//            return HTTPStubsResponse(fileAtPath: OHPathForFile("apiSuccess.json", AuthenticationTests.self)!, statusCode: 200, headers: ["Content-Type": "application/json"])
//        }
//        
//        let server: MageServer = await withCheckedContinuation { continuation in
//            MageServer.server(url: url) { (server: MageServer) in
//                continuation.resume(returning: server)
//            } failure: { error in
//                XCTFail()
//            }
//        }
//        XCTAssertEqual(url?.absoluteString, "https://magetest")
//        
//        let apiSigninResponseArrived = XCTestExpectation(description: "response of /auth/local/signin complete")
//
//        stub(condition: isMethodPOST() &&
//             isHost("magetest") &&
//             isPath("/auth/local/signin")
//        ) { (request) -> HTTPStubsResponse in
//            apiSigninResponseArrived.fulfill()
//            return HTTPStubsResponse(fileAtPath: OHPathForFile("signinSuccess.json", AuthenticationTests.self)!, statusCode: 200, headers: ["Content-Type": "application/json"])
//        }
//        
//        let apiTokenStub = XCTestExpectation(description: "response of /auth/token complete")
//
//        stub(condition: isMethodPOST() &&
//             isHost("magetest") &&
//             isPath("/auth/token")
//        ) { (request) -> HTTPStubsResponse in
//            apiTokenStub.fulfill()
//            return HTTPStubsResponse(
//                jsonObject: [
//                    "expirationDate":"2020-02-20T01:25:44.796Z",
//                    "api":[
//                        "name":"mage-server",
//                        "description":"Geospatial situation awareness application.",
//                        "version":[
//                            "major":6,
//                            "minor":0,
//                            "micro":0
//                        ],
//                        "authenticationStrategies":[
//                            "local":[
//                                "passwordMinLength":14
//                            ]
//                        ],
//                        "provision":[
//                            "strategy":"uid"
//                        ]
//                    ]
//                ],
//                statusCode: 200,
//                headers: ["Content-Type": "application/json"]
//            )
//        }
//        
//        let coordinator = AuthenticationCoordinator(navigationController: navigationController, andDelegate: delegate, andScheme: MAGEScheme.scheme(), context: context)!
//        coordinator.start(server)
//        
//        await awaitBlockTrue(block: {
//            if let _ = navigationController.topViewController as? LoginViewController {
//                return true
//            }
//            return false
//        }, timeout: 2)
//        
//        let parameters: [String: Any] = [
//            "username": "test",
//            "password": "test",
//            "uid": "uuid",
//            "strategy": [
//                "identifier": "local"
//            ],
//            "appVersion": "6.0.0"
//        ]
//        
//        let loginDelegate = coordinator as! LoginDelegate
//        loginDelegate.login(withParameters: parameters, withAuthenticationStrategy: "local") { authenticationStatus, errorString in
//            // login complete
//            print("Authentication status \(authenticationStatus)")
//            // TODO: This really should return AUTHENTICATION_ERROR but right now it returns success
//            XCTAssertTrue(authenticationStatus == AuthenticationStatus.AUTHENTICATION_SUCCESS)
//            let token = StoredPassword.retrieveStoredToken()
////            let mageSessionToken = MageSessionManager.shared().getToken()
//            XCTAssertEqual(token, "TOKEN")
////            XCTAssertEqual(token, mageSessionToken)
//        }
//        
//        await fulfillment(of: [apiSigninResponseArrived, apiTokenStub], timeout: 2)
//        TestHelpers.printAllAccessibilityLabelsInWindows()
//        
//        await awaitBlockTrue(block: {
//            self.viewTester().usingLabel("Login Failed").view != nil &&
//            self.viewTester().usingLabel("Copy Error Message Detail").view != nil
//        }, timeout: 2)
//    }
//    
//    // TODO: Flaky Test
//    @MainActor
//    func testLoginWithInvalidTokenExpirationDate() async {
//        let baseUrlKey = "baseServerUrl"
//        
//        let defaults = UserDefaults.standard
//        defaults.set("https://magetest", forKey: baseUrlKey)
//        defaults.set(true, forKey: "deviceRegistered")
//        
//        let navigationController = UINavigationController()
//        window.rootViewController = navigationController
//        
//        let delegate = AuthenticationTestDelegate()
//        
//        let url = MageServer.baseURL()
//        
//        let apiResponseArrived = XCTestExpectation(description: "response of /api complete")
//        
//        stub(condition: isMethodGET() &&
//             isHost("magetest") &&
//             isPath("/api")
//        ) { (request) -> HTTPStubsResponse in
//            apiResponseArrived.fulfill()
//            return HTTPStubsResponse(fileAtPath: OHPathForFile("apiSuccess.json", AuthenticationTests.self)!, statusCode: 200, headers: ["Content-Type": "application/json"])
//        }
//        
//        let server: MageServer = await withCheckedContinuation { continuation in
//            MageServer.server(url: url) { (server: MageServer) in
//                continuation.resume(returning: server)
//            } failure: { error in
//                XCTFail()
//            }
//        }
//        XCTAssertEqual(url?.absoluteString, "https://magetest")
//        
//        let apiSigninResponseArrived = XCTestExpectation(description: "response of /auth/local/signin complete")
//
//        stub(condition: isMethodPOST() &&
//             isHost("magetest") &&
//             isPath("/auth/local/signin")
//        ) { (request) -> HTTPStubsResponse in
//            apiSigninResponseArrived.fulfill()
//            return HTTPStubsResponse(fileAtPath: OHPathForFile("signinSuccess.json", AuthenticationTests.self)!, statusCode: 200, headers: ["Content-Type": "application/json"])
//        }
//        
//        let apiTokenStub = XCTestExpectation(description: "response of /auth/token complete")
//
//        stub(condition: isMethodPOST() &&
//             isHost("magetest") &&
//             isPath("/auth/token")
//        ) { (request) -> HTTPStubsResponse in
//            apiTokenStub.fulfill()
//            return HTTPStubsResponse(
//                jsonObject: [
//                    "token":"TOKEN",
//                    "api":[
//                        "name":"mage-server",
//                        "description":"Geospatial situation awareness application.",
//                        "version":[
//                            "major":6,
//                            "minor":0,
//                            "micro":0
//                        ],
//                        "authenticationStrategies":[
//                            "local":[
//                                "passwordMinLength":14
//                            ]
//                        ],
//                        "provision":[
//                            "strategy":"uid"
//                        ]
//                    ]
//                ],
//                statusCode: 200,
//                headers: ["Content-Type": "application/json"]
//            )
//        }
//        
//        let coordinator = AuthenticationCoordinator(navigationController: navigationController, andDelegate: delegate, andScheme: MAGEScheme.scheme(), context: context)!
//        coordinator.start(server)
//        
//        await awaitBlockTrue(block: {
//            if let _ = navigationController.topViewController as? LoginViewController {
//                return true
//            }
//            return false
//        }, timeout: 2)
//        
//        let parameters: [String: Any] = [
//            "username": "test",
//            "password": "test",
//            "uid": "uuid",
//            "strategy": [
//                "identifier": "local"
//            ],
//            "appVersion": "6.0.0"
//        ]
//        
//        let loginDelegate = coordinator as! LoginDelegate
//        loginDelegate.login(withParameters: parameters, withAuthenticationStrategy: "local") { authenticationStatus, errorString in
//            // login complete
//            print("Authentication status \(authenticationStatus)")
//            // TODO: This really should return AUTHENTICATION_ERROR but right now it returns success
//            XCTAssertTrue(authenticationStatus == AuthenticationStatus.AUTHENTICATION_SUCCESS)
//            let token = StoredPassword.retrieveStoredToken()
////            let mageSessionToken = MageSessionManager.shared().getToken()
//            XCTAssertEqual(token, "TOKEN")
////            XCTAssertEqual(token, mageSessionToken)
//        }
//        
//        await fulfillment(of: [apiSigninResponseArrived, apiTokenStub], timeout: 2)
//        TestHelpers.printAllAccessibilityLabelsInWindows()
//        
//        await awaitBlockTrue(block: {
//            self.viewTester().usingLabel("Login Failed").view != nil &&
//            self.viewTester().usingLabel("Copy Error Message Detail").view != nil
//        }, timeout: 2)
//    }
//    
//    // TODO: Flaky Test
//    @MainActor
//    func testLoginWithInvalidUsername() async {
//        let baseUrlKey = "baseServerUrl"
//        
//        let defaults = UserDefaults.standard
//        defaults.set("https://magetest", forKey: baseUrlKey)
//        defaults.set(true, forKey: "deviceRegistered")
//        
//        let navigationController = UINavigationController()
//        window.rootViewController = navigationController
//        
//        let delegate = AuthenticationTestDelegate()
//        
//        let url = MageServer.baseURL()
//        
//        let apiResponseArrived = XCTestExpectation(description: "response of /api complete")
//        
//        stub(condition: isMethodGET() &&
//             isHost("magetest") &&
//             isPath("/api")
//        ) { (request) -> HTTPStubsResponse in
//            apiResponseArrived.fulfill()
//            return HTTPStubsResponse(fileAtPath: OHPathForFile("apiSuccess.json", AuthenticationTests.self)!, statusCode: 200, headers: ["Content-Type": "application/json"])
//        }
//        
//        let server: MageServer = await withCheckedContinuation { continuation in
//            MageServer.server(url: url) { (server: MageServer) in
//                continuation.resume(returning: server)
//            } failure: { error in
//                XCTFail()
//            }
//        }
//        XCTAssertEqual(url?.absoluteString, "https://magetest")
//        
//        let apiSigninResponseArrived = XCTestExpectation(description: "response of /auth/local/signin complete")
//
//        stub(condition: isMethodPOST() &&
//             isHost("magetest") &&
//             isPath("/auth/local/signin")
//        ) { (request) -> HTTPStubsResponse in
//            apiSigninResponseArrived.fulfill()
//            return HTTPStubsResponse(fileAtPath: OHPathForFile("signinSuccess.json", AuthenticationTests.self)!, statusCode: 200, headers: ["Content-Type": "application/json"])
//        }
//        
//        let apiTokenStub = XCTestExpectation(description: "response of /auth/token complete")
//
//        stub(condition: isMethodPOST() &&
//             isHost("magetest") &&
//             isPath("/auth/token")
//        ) { (request) -> HTTPStubsResponse in
//            apiTokenStub.fulfill()
//            return HTTPStubsResponse(
//                jsonObject: [
//                    "token":"TOKEN",
//                    "expirationDate":"2020-02-20T01:25:44.796Z",
//                    "api":[
//                        "name":"mage-server",
//                        "description":"Geospatial situation awareness application.",
//                        "version":[
//                            "major":6,
//                            "minor":0,
//                            "micro":0
//                        ],
//                        "authenticationStrategies":[
//                            "local":[
//                                "passwordMinLength":14
//                            ]
//                        ],
//                        "provision":[
//                            "strategy":"uid"
//                        ]
//                    ]
//                ],
//                statusCode: 200,
//                headers: ["Content-Type": "application/json"]
//            )
//        }
//        
//        let coordinator = AuthenticationCoordinator(navigationController: navigationController, andDelegate: delegate, andScheme: MAGEScheme.scheme(), context: context)!
//        coordinator.start(server)
//        
//        await awaitBlockTrue(block: {
//            if let _ = navigationController.topViewController as? LoginViewController {
//                return true
//            }
//            return false
//        }, timeout: 2)
//        
//        let parameters: [String: Any] = [
////            "username": "test",
//            "password": "test",
//            "uid": "uuid",
//            "strategy": [
//                "identifier": "local"
//            ],
//            "appVersion": "6.0.0"
//        ]
//        
//        let loginDelegate = coordinator as! LoginDelegate
//        loginDelegate.login(withParameters: parameters, withAuthenticationStrategy: "local") { authenticationStatus, errorString in
//            // login complete
//            print("Authentication status \(authenticationStatus)")
//            // TODO: This really should return AUTHENTICATION_ERROR but right now it returns success
//            XCTAssertTrue(authenticationStatus == AuthenticationStatus.AUTHENTICATION_SUCCESS)
//            let token = StoredPassword.retrieveStoredToken()
////            let mageSessionToken = MageSessionManager.shared().getToken()
//            XCTAssertEqual(token, "TOKEN")
////            XCTAssertEqual(token, mageSessionToken)
//        }
//        
//        await fulfillment(of: [apiSigninResponseArrived, apiTokenStub], timeout: 2)
//        TestHelpers.printAllAccessibilityLabelsInWindows()
//        
//        await awaitBlockTrue(block: {
//            self.viewTester().usingLabel("Login Failed").view != nil &&
//            self.viewTester().usingLabel("Copy Error Message Detail").view != nil
//        }, timeout: 2)
//    }
//    
//    // TODO: Flaky Test
//    @MainActor
//    func testLoginWithInvalidPassword() async {
//        let baseUrlKey = "baseServerUrl"
//        
//        let defaults = UserDefaults.standard
//        defaults.set("https://magetest", forKey: baseUrlKey)
//        defaults.set(true, forKey: "deviceRegistered")
//        
//        let navigationController = UINavigationController()
//        window.rootViewController = navigationController
//        
//        let delegate = AuthenticationTestDelegate()
//        
//        let url = MageServer.baseURL()
//        
//        let apiResponseArrived = XCTestExpectation(description: "response of /api complete")
//        
//        stub(condition: isMethodGET() &&
//             isHost("magetest") &&
//             isPath("/api")
//        ) { (request) -> HTTPStubsResponse in
//            apiResponseArrived.fulfill()
//            return HTTPStubsResponse(fileAtPath: OHPathForFile("apiSuccess.json", AuthenticationTests.self)!, statusCode: 200, headers: ["Content-Type": "application/json"])
//        }
//        
//        let server: MageServer = await withCheckedContinuation { continuation in
//            MageServer.server(url: url) { (server: MageServer) in
//                continuation.resume(returning: server)
//            } failure: { error in
//                XCTFail()
//            }
//        }
//        XCTAssertEqual(url?.absoluteString, "https://magetest")
//        
//        let apiSigninResponseArrived = XCTestExpectation(description: "response of /auth/local/signin complete")
//
//        stub(condition: isMethodPOST() &&
//             isHost("magetest") &&
//             isPath("/auth/local/signin")
//        ) { (request) -> HTTPStubsResponse in
//            apiSigninResponseArrived.fulfill()
//            return HTTPStubsResponse(fileAtPath: OHPathForFile("signinSuccess.json", AuthenticationTests.self)!, statusCode: 200, headers: ["Content-Type": "application/json"])
//        }
//        
//        let apiTokenStub = XCTestExpectation(description: "response of /auth/token complete")
//
//        stub(condition: isMethodPOST() &&
//             isHost("magetest") &&
//             isPath("/auth/token")
//        ) { (request) -> HTTPStubsResponse in
//            apiTokenStub.fulfill()
//            return HTTPStubsResponse(
//                jsonObject: [
//                    "token":"TOKEN",
//                    "expirationDate":"2020-02-20T01:25:44.796Z",
//                    "api":[
//                        "name":"mage-server",
//                        "description":"Geospatial situation awareness application.",
//                        "version":[
//                            "major":6,
//                            "minor":0,
//                            "micro":0
//                        ],
//                        "authenticationStrategies":[
//                            "local":[
//                                "passwordMinLength":14
//                            ]
//                        ],
//                        "provision":[
//                            "strategy":"uid"
//                        ],
//                        "contactinfo": [
//                            "email": "test@test.com",
//                            "phone": "555-555-5555"
//                        ]
//                    ]
//                ],
//                statusCode: 200,
//                headers: ["Content-Type": "application/json"]
//            )
//        }
//        
//        let coordinator = AuthenticationCoordinator(navigationController: navigationController, andDelegate: delegate, andScheme: MAGEScheme.scheme(), context: context)!
//        coordinator.start(server)
//        
//        await awaitBlockTrue(block: {
//            if let _ = navigationController.topViewController as? LoginViewController {
//                return true
//            }
//            return false
//        }, timeout: 2)
//        
//        let parameters: [String: Any] = [
//            "username": "test",
////            "password": "test",
//            "uid": "uuid",
//            "strategy": [
//                "identifier": "local"
//            ],
//            "appVersion": "6.0.0"
//        ]
//        
//        let loginDelegate = coordinator as! LoginDelegate
//        loginDelegate.login(withParameters: parameters, withAuthenticationStrategy: "local") { authenticationStatus, errorString in
//            // login complete
//            print("Authentication status \(authenticationStatus)")
//            // TODO: This really should return AUTHENTICATION_ERROR but right now it returns success
//            XCTAssertTrue(authenticationStatus == AuthenticationStatus.AUTHENTICATION_SUCCESS)
//            let token = StoredPassword.retrieveStoredToken()
////            let mageSessionToken = MageSessionManager.shared().getToken()
//            XCTAssertEqual(token, "TOKEN")
////            XCTAssertEqual(token, mageSessionToken)
//        }
//        
//        await fulfillment(of: [apiSigninResponseArrived, apiTokenStub], timeout: 2)
//        TestHelpers.printAllAccessibilityLabelsInWindows()
//        
//        await awaitBlockTrue(block: {
//            self.viewTester().usingLabel("Login Failed").view != nil &&
//            self.viewTester().usingLabel("Copy Error Message Detail").view != nil
//        }, timeout: 2)
//        TestHelpers.printAllAccessibilityLabelsInWindows()
//    }
//}


//
//- (void) skipped_testLoginWithRegisteredDevice {
//    NSString *baseUrlKey = @"baseServerUrl";
//
//    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
//    [defaults setObject:@"https://mage.geointservices.io" forKey:baseUrlKey];
//    [defaults setBool:YES forKey:@"deviceRegistered"];
//
//    UINavigationController *navigationController = [[UINavigationController alloc]init];
//
//    XCTestExpectation* apiResponseArrived = [self expectationWithDescription:@"response of /api complete"];
//
//    AuthenticationTestDelegate *delegate = [[AuthenticationTestDelegate alloc] init];
//    id delegatePartialMock = OCMPartialMock(delegate);
//    OCMExpect([delegatePartialMock authenticationSuccessful]);
//
//    AuthenticationCoordinator *coordinator = [[AuthenticationCoordinator alloc] initWithNavigationController:navigationController andDelegate:delegate andScheme:[MAGEScheme scheme]];
//
//    id navControllerPartialMock = OCMPartialMock(navigationController);
//
//    NSURL *url = [MageServer baseURL];
//    XCTAssertTrue([[url absoluteString] isEqualToString:@"https://mage.geointservices.io"]);
//
//    OCMExpect([navControllerPartialMock pushViewController:[OCMArg isKindOfClass:[LoginViewController class]] animated:NO])._andDo(^(NSInvocation *invocation) {
//        [apiResponseArrived fulfill];
//    });
//
//    [HTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
//        return [request.URL.host isEqualToString:@"mage.geointservices.io"] && [request.URL.path isEqualToString:@"/api"];
//    } withStubResponse:^HTTPStubsResponse*(NSURLRequest *request) {
//        NSLog(@"api request recieved and handled");
//        NSString* fixture = OHPathForFile(@"apiSuccess.json", self.class);
//        return [HTTPStubsResponse responseWithFileAtPath:fixture
//                                                statusCode:200 headers:@{@"Content-Type":@"application/json"}];
//    }];
//
////    [coordinator start];
//
//    [self waitForExpectationsWithTimeout:5 handler:^(NSError * _Nullable error) {
//        // response came back from the server and we went to the login screen
//        id<LoginDelegate> loginDelegate = (id<LoginDelegate>)coordinator;
//        id<DisclaimerDelegate> disclaimerDelegate = (id<DisclaimerDelegate>)coordinator;
//
//        NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:
//                                    @"test", @"username",
//                                    @"test", @"password",
//                                    @"uuid", @"uid",
//                                    [NSDictionary dictionaryWithObjectsAndKeys:
//                                     @"local", @"identifier", nil],
//                                    @"strategy",
//                                    @"5.0.0", @"appVersion",
//                                    nil];
//
//        [HTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
//            return [request.URL.host isEqualToString:@"mage.geointservices.io"] && [request.URL.path isEqualToString:@"/auth/local/signin"];
//        } withStubResponse:^HTTPStubsResponse*(NSURLRequest *request) {
//            NSString* fixture = OHPathForFile(@"loginSuccess.json", self.class);
//            return [HTTPStubsResponse responseWithFileAtPath:fixture
//                                                    statusCode:200 headers:@{@"Content-Type":@"application/json"}];
//        }];
//
//        XCTestExpectation* loginResponseArrived = [self expectationWithDescription:@"response of /auth/local/signin complete"];
//
//        OCMExpect([navControllerPartialMock pushViewController:[OCMArg isKindOfClass:[DisclaimerViewController class]] animated:NO])._andDo(^(NSInvocation *invocation) {
//            [loginResponseArrived fulfill];
//            [disclaimerDelegate disclaimerAgree];
//            OCMVerifyAll(delegatePartialMock);
//        });
//
////        [loginDelegate loginWithParameters:parameters withAuthenticationType:SERVER complete:^(AuthenticationStatus authenticationStatus, NSString *errorString) {
////            // login complete
////            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
////            XCTAssertTrue(authenticationStatus == AUTHENTICATION_SUCCESS);
////        }];
//
//        [self waitForExpectationsWithTimeout:5 handler:^(NSError * _Nullable error) {
//
//            OCMVerifyAll(navControllerPartialMock);
//        }];
//
//    }];
//}
//
//- (void) skipped_testLoginWithRegisteredDeviceChangingUserWithOfflineObservations {
//    User *u = [User MR_createEntity];
//    u.username = @"old";
//
//    NSString *baseUrlKey = @"baseServerUrl";
//
//    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
//    [defaults setObject:@"https://mage.geointservices.io" forKey:baseUrlKey];
//    [defaults setBool:YES forKey:@"deviceRegistered"];
//
//    id offlineManagerMock = OCMClassMock([MageOfflineObservationManager class]);
//    OCMStub(ClassMethod([offlineManagerMock offlineObservationCount]))._andReturn([NSNumber numberWithInt:1]);
//
//    id userMock = [OCMockObject mockForClass:[User class]];
//    [[[userMock stub] andReturn:u] fetchCurrentUserWithContext:[OCMArg any]];
//
//    UINavigationController *navigationController = [[UINavigationController alloc]init];
//
//    XCTestExpectation* apiResponseArrived = [self expectationWithDescription:@"response of /api complete"];
//
//    AuthenticationTestDelegate *delegate = [[AuthenticationTestDelegate alloc] init];
//    id delegatePartialMock = OCMPartialMock(delegate);
//    OCMExpect([delegatePartialMock authenticationSuccessful]);
//
//    AuthenticationCoordinator *coordinator = [[AuthenticationCoordinator alloc] initWithNavigationController:navigationController andDelegate:delegate andScheme:[MAGEScheme scheme]];
//
//    id navControllerPartialMock = OCMPartialMock(navigationController);
//
//    NSURL *url = [MageServer baseURL];
//    XCTAssertTrue([[url absoluteString] isEqualToString:@"https://mage.geointservices.io"]);
//
//    OCMExpect([navControllerPartialMock pushViewController:[OCMArg isKindOfClass:[LoginViewController class]] animated:NO])._andDo(^(NSInvocation *invocation) {
//        [apiResponseArrived fulfill];
//    });
//
//    [HTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
//        return [request.URL.host isEqualToString:@"mage.geointservices.io"] && [request.URL.path isEqualToString:@"/api"];
//    } withStubResponse:^HTTPStubsResponse*(NSURLRequest *request) {
//        NSString* fixture = OHPathForFile(@"apiSuccess.json", self.class);
//        return [HTTPStubsResponse responseWithFileAtPath:fixture
//                                                statusCode:200 headers:@{@"Content-Type":@"application/json"}];
//    }];
//
////    [coordinator start];
//
//    [self waitForExpectationsWithTimeout:5 handler:^(NSError * _Nullable error) {
//        // response came back from the server and we went to the login screen
//        id<LoginDelegate> loginDelegate = (id<LoginDelegate>)coordinator;
//
//        NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:
//                                    @"test", @"username",
//                                    @"test", @"password",
//                                    @"uuid", @"uid",
//                                    [NSDictionary dictionaryWithObjectsAndKeys:
//                                     @"local", @"identifier", nil],
//                                    @"strategy",
//                                    @"5.0.0", @"appVersion",
//                                    nil];
//
//        [HTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
//            return [request.URL.host isEqualToString:@"mage.geointservices.io"] && [request.URL.path isEqualToString:@"/auth/local/signin"];
//        } withStubResponse:^HTTPStubsResponse*(NSURLRequest *request) {
//            NSString* fixture = OHPathForFile(@"signinSuccess.json", self.class);
//            return [HTTPStubsResponse responseWithFileAtPath:fixture
//                                                    statusCode:200 headers:@{@"Content-Type":@"application/json"}];
//        }];
//
//        XCTestExpectation* loginResponseArrived = [self expectationWithDescription:@"response of /auth/local/signin complete"];
//
//        OCMExpect([navControllerPartialMock presentViewController:[OCMArg isKindOfClass:[UIAlertController class]] animated:YES completion:[OCMArg any]])._andDo(^(NSInvocation *invocation) {
//            __unsafe_unretained UIAlertController *alert;
//            [invocation getArgument:&alert atIndex:2];
//            XCTAssertTrue([alert.title isEqualToString:@"Loss of Unsaved Data"]);
//            [loginResponseArrived fulfill];
//        });
//
//        OCMReject([navControllerPartialMock pushViewController:[OCMArg any] animated:[OCMArg any]]);
//
////        [loginDelegate loginWithParameters:parameters withAuthenticationType:SERVER complete:^(AuthenticationStatus authenticationStatus, NSString *errorString) {
////            // login complete
////            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
////            XCTAssertTrue(authenticationStatus == AUTHENTICATION_SUCCESS);
////        }];
//
//        [self waitForExpectationsWithTimeout:5 handler:^(NSError * _Nullable error) {
//
//            OCMVerifyAll(navControllerPartialMock);
//        }];
//
//    }];
//}
//
//- (void) skipped_testLoginWithRegisteredDeviceChangingUserWithoutOfflineObservations {
//    User *u = [User MR_createEntity];
//    u.username = @"old";
//
//    NSString *baseUrlKey = @"baseServerUrl";
//
//    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
//    [defaults setObject:@"https://mage.geointservices.io" forKey:baseUrlKey];
//    [defaults setBool:YES forKey:@"deviceRegistered"];
//
//    UINavigationController *navigationController = [[UINavigationController alloc]init];
//
//    XCTestExpectation* apiResponseArrived = [self expectationWithDescription:@"response of /api complete"];
//
//    AuthenticationTestDelegate *delegate = [[AuthenticationTestDelegate alloc] init];
//    id delegatePartialMock = OCMPartialMock(delegate);
//    OCMExpect([delegatePartialMock authenticationSuccessful]);
//
//    AuthenticationCoordinator *coordinator = [[AuthenticationCoordinator alloc] initWithNavigationController:navigationController andDelegate:delegate andScheme:[MAGEScheme scheme]];
//
//    id navControllerPartialMock = OCMPartialMock(navigationController);
//
//    NSURL *url = [MageServer baseURL];
//    XCTAssertTrue([[url absoluteString] isEqualToString:@"https://mage.geointservices.io"]);
//
//    OCMExpect([navControllerPartialMock pushViewController:[OCMArg isKindOfClass:[LoginViewController class]] animated:NO])._andDo(^(NSInvocation *invocation) {
//        [apiResponseArrived fulfill];
//    });
//
//    [HTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
//        return [request.URL.host isEqualToString:@"mage.geointservices.io"] && [request.URL.path isEqualToString:@"/api"];
//    } withStubResponse:^HTTPStubsResponse*(NSURLRequest *request) {
//        NSString* fixture = OHPathForFile(@"apiSuccess.json", self.class);
//        return [HTTPStubsResponse responseWithFileAtPath:fixture
//                                                statusCode:200 headers:@{@"Content-Type":@"application/json"}];
//    }];
//
////    [coordinator start];
//
//    [self waitForExpectationsWithTimeout:5 handler:^(NSError * _Nullable error) {
//        // response came back from the server and we went to the login screen
//        id<LoginDelegate> loginDelegate = (id<LoginDelegate>)coordinator;
//        id<DisclaimerDelegate> disclaimerDelegate = (id<DisclaimerDelegate>)coordinator;
//
//        NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:
//                                    @"test", @"username",
//                                    @"test", @"password",
//                                    @"uuid", @"uid",
//                                    [NSDictionary dictionaryWithObjectsAndKeys:
//                                     @"local", @"identifier", nil],
//                                    @"strategy",
//                                    nil];
//
//        [HTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
//            return [request.URL.host isEqualToString:@"mage.geointservices.io"] && [request.URL.path isEqualToString:@"/auth/local/signin"];
//        } withStubResponse:^HTTPStubsResponse*(NSURLRequest *request) {
//            NSString* fixture = OHPathForFile(@"signinSuccess.json", self.class);
//            return [HTTPStubsResponse responseWithFileAtPath:fixture
//                                                    statusCode:200 headers:@{@"Content-Type":@"application/json"}];
//        }];
//
//        XCTestExpectation* loginResponseArrived = [self expectationWithDescription:@"response of /auth/local/signin complete"];
//
//        OCMExpect([navControllerPartialMock pushViewController:[OCMArg isKindOfClass:[DisclaimerViewController class]] animated:NO])._andDo(^(NSInvocation *invocation) {
//            [loginResponseArrived fulfill];
//            [disclaimerDelegate disclaimerAgree];
//            OCMVerifyAll(delegatePartialMock);
//        });
//
//        OCMReject([navControllerPartialMock pushViewController:[OCMArg any] animated:[OCMArg any]]);
//
////        [loginDelegate loginWithParameters:parameters withAuthenticationType:SERVER complete:^(AuthenticationStatus authenticationStatus, NSString *errorString) {
////            // login complete
////            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
////            XCTAssertTrue(authenticationStatus == AUTHENTICATION_SUCCESS);
////        }];
//
//        [self waitForExpectationsWithTimeout:5 handler:^(NSError * _Nullable error) {
//
//            OCMVerifyAll(navControllerPartialMock);
//        }];
//
//    }];
//}
//
//- (void) skipped_testLoginFailWithRegisteredDevice {
//    NSString *baseUrlKey = @"baseServerUrl";
//
//    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
//    [defaults setObject:@"https://mage.geointservices.io" forKey:baseUrlKey];
//    [defaults setBool:YES forKey:@"deviceRegistered"];
//
//    UINavigationController *navigationController = [[UINavigationController alloc]init];
//
//    XCTestExpectation* apiResponseArrived = [self expectationWithDescription:@"response of /api complete"];
//
//    AuthenticationTestDelegate *delegate = [[AuthenticationTestDelegate alloc] init];
//    id delegatePartialMock = OCMPartialMock(delegate);
//    OCMExpect([delegatePartialMock authenticationSuccessful]);
//
//    AuthenticationCoordinator *coordinator = [[AuthenticationCoordinator alloc] initWithNavigationController:navigationController andDelegate:delegate andScheme:[MAGEScheme scheme]];
//
//    id navControllerPartialMock = OCMPartialMock(navigationController);
//
//    NSURL *url = [MageServer baseURL];
//    XCTAssertTrue([[url absoluteString] isEqualToString:@"https://mage.geointservices.io"]);
//
//    OCMExpect([navControllerPartialMock pushViewController:[OCMArg isKindOfClass:[LoginViewController class]] animated:NO])._andDo(^(NSInvocation *invocation) {
//        [apiResponseArrived fulfill];
//    });
//
//    [HTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
//        return [request.URL.host isEqualToString:@"mage.geointservices.io"] && [request.URL.path isEqualToString:@"/api"];
//    } withStubResponse:^HTTPStubsResponse*(NSURLRequest *request) {
//        NSString* fixture = OHPathForFile(@"apiSuccess.json", self.class);
//        return [HTTPStubsResponse responseWithFileAtPath:fixture
//                                                statusCode:200 headers:@{@"Content-Type":@"application/json"}];
//    }];
//
////    [coordinator start];
//
//    [self waitForExpectationsWithTimeout:5 handler:^(NSError * _Nullable error) {
//        id<LoginDelegate> loginDelegate = (id<LoginDelegate>)coordinator;
//
//        NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:
//                                    @"test", @"username",
//                                    @"test", @"password",
//                                    @"uuid", @"uid",
//                                    [NSDictionary dictionaryWithObjectsAndKeys:
//                                     @"local", @"identifier", nil],
//                                    @"strategy",
//                                    nil];
//
//        [HTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
//            return [request.URL.host isEqualToString:@"mage.geointservices.io"] && [request.URL.path isEqualToString:@"/auth/local/signin"];
//        } withStubResponse:^HTTPStubsResponse*(NSURLRequest *request) {
//            HTTPStubsResponse *response = [[HTTPStubsResponse alloc] init];
//            response.statusCode = 401;
//
//            return response;
//        }];
//
//        [HTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
//            return [request.URL.host isEqualToString:@"mage.geointservices.io"] && [request.URL.path isEqualToString:@"/api/devices"];
//        } withStubResponse:^HTTPStubsResponse*(NSURLRequest *request) {
//            NSString* fixture = OHPathForFile(@"apiFail.json", self.class);
//            return [HTTPStubsResponse responseWithFileAtPath:fixture
//                                                    statusCode:401 headers:@{@"Content-Type":@"application/json"}];
//        }];
//
//        XCTestExpectation* loginResponseArrived = [self expectationWithDescription:@"response of /auth/local/signin complete"];
//
//        OCMReject([navControllerPartialMock pushViewController:[OCMArg any] animated:[OCMArg any]]);
//
////        [loginDelegate loginWithParameters:parameters withAuthenticationType:SERVER complete:^(AuthenticationStatus authenticationStatus, NSString *errorString) {
////            // login complete
////            XCTAssertTrue(authenticationStatus == AUTHENTICATION_ERROR);
////            [loginResponseArrived fulfill];
////        }];
//
//        [self waitForExpectationsWithTimeout:5 handler:^(NSError * _Nullable error) {
//
//            OCMVerifyAll(navControllerPartialMock);
//        }];
//
//    }];
//}
//
//- (void) skipped_testWorkOffline {
//    NSString *baseUrlKey = @"baseServerUrl";
//
//    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
//    [defaults setObject:@"https://mage.geointservices.io" forKey:baseUrlKey];
//    [defaults setBool:YES forKey:@"deviceRegistered"];
//    [defaults setObject:[NSDictionary dictionaryWithObjectsAndKeys:@"https://mage.geointservices.io", @"serverUrl", @"test", @"username", nil] forKey:@"loginParameters"];
//    [defaults setObject:[NSNumber numberWithDouble:2880] forKey:@"tokenExpirationLength"];
//    id storedPasswordMock = [OCMockObject mockForClass:[StoredPassword class]];
//    [[[storedPasswordMock stub] andReturn:@"goodpassword"] retrieveStoredPassword];
//
//    UINavigationController *navigationController = [[UINavigationController alloc]init];
//
//    XCTestExpectation* apiResponseArrived = [self expectationWithDescription:@"response of /api complete"];
//
//    AuthenticationTestDelegate *delegate = [[AuthenticationTestDelegate alloc] init];
//
//    __block AuthenticationCoordinator *coordinator = [[AuthenticationCoordinator alloc] initWithNavigationController:navigationController andDelegate:delegate andScheme:[MAGEScheme scheme]];
//
//    id navControllerPartialMock = OCMPartialMock(navigationController);
//
//    NSURL *url = [MageServer baseURL];
//    XCTAssertTrue([[url absoluteString] isEqualToString:@"https://mage.geointservices.io"]);
//
//    OCMExpect([navControllerPartialMock pushViewController:[OCMArg isKindOfClass:[LoginViewController class]] animated:NO])._andDo(^(NSInvocation *invocation) {
//        [apiResponseArrived fulfill];
//    });
//
//    [HTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
//        return [request.URL.host isEqualToString:@"mage.geointservices.io"] && [request.URL.path isEqualToString:@"/api"];
//    } withStubResponse:^HTTPStubsResponse*(NSURLRequest *request) {
//        NSString* fixture = OHPathForFile(@"apiSuccess.json", self.class);
//        return [HTTPStubsResponse responseWithFileAtPath:fixture
//                                                statusCode:200 headers:@{@"Content-Type":@"application/json"}];
//    }];
//
////    [coordinator start];
//
//    [self waitForExpectationsWithTimeout:5 handler:^(NSError * _Nullable error) {
//        // response came back from the server and we went to the login screen
//        id<LoginDelegate> loginDelegate = (id<LoginDelegate>)coordinator;
//
//        id<DisclaimerDelegate> disclaimerDelegate = (id<DisclaimerDelegate>)coordinator;
//
//        NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:
//                                    @"test", @"username",
//                                    @"goodpassword", @"password",
//                                    @"uuid", @"uid",
//                                    [NSDictionary dictionaryWithObjectsAndKeys:
//                                     @"local", @"identifier", nil],
//                                    @"strategy",
//                                    nil];
//
//        [HTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
//            return [request.URL.host isEqualToString:@"mage.geointservices.io"] && [request.URL.path isEqualToString:@"/auth/local/signin"];
//        } withStubResponse:^HTTPStubsResponse*(NSURLRequest *request) {
//            NSError* notConnectedError = [NSError errorWithDomain:NSURLErrorDomain code:kCFURLErrorNotConnectedToInternet userInfo:nil];
//            return [HTTPStubsResponse responseWithError:notConnectedError];
//        }];
//
//        XCTestExpectation* loginResponseArrived = [self expectationWithDescription:@"response of /auth/local/signin complete"];
//        id coordinatorMock = OCMPartialMock(coordinator);
//        OCMExpect([coordinatorMock unableToAuthenticate:[OCMArg any] complete:[OCMArg any]]).andDo(^(NSInvocation *invocation) {
//        }).andForwardToRealObject();
//
////        OCMExpect([navControllerPartialMock presentViewController:[OCMArg isKindOfClass:[UIAlertController class]] animated:YES completion:[OCMArg any]])._andDo(^(NSInvocation *invocation) {
////            __unsafe_unretained UIAlertController *alert;
////            [invocation getArgument:&alert atIndex:2];
////            XCTAssertTrue([alert.title isEqualToString:@"Disconnected Login"]);
////            [coordinator workOffline: parameters complete:^(AuthenticationStatus authenticationStatus, NSString *errorString) {
////                NSLog(@"Auth Success");
////                NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
////                XCTAssertTrue([[Authentication authenticationTypeToString:LOCAL] isEqualToString:[defaults valueForKey:@"loginType"]]);
////                XCTAssertTrue(authenticationStatus == AUTHENTICATION_SUCCESS);
////                [loginResponseArrived fulfill];
////            }];
////        });
//
//        OCMExpect([navControllerPartialMock pushViewController:[OCMArg isKindOfClass:[DisclaimerViewController class]] animated:NO])._andDo(^(NSInvocation *invocation) {
//            [disclaimerDelegate disclaimerAgree];
//        });
//
////        [loginDelegate loginWithParameters:parameters withAuthenticationType:SERVER complete:^(AuthenticationStatus authenticationStatus, NSString *errorString) {
////            NSLog(@"Unable to authenticate");
////            XCTFail(@"Should not be in here");
////        }];
//
//        [self waitForExpectationsWithTimeout:5 handler:^(NSError * _Nullable error) {
//            OCMVerifyAll(navControllerPartialMock);
//            OCMVerifyAll(coordinatorMock);
//            [storedPasswordMock stopMocking];
//        }];
//    }];
//}
//
//- (void) skipped_testWorkOfflineBadPassword {
//    NSString *baseUrlKey = @"baseServerUrl";
//
//    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
//    [defaults setObject:@"https://mage.geointservices.io" forKey:baseUrlKey];
//    [defaults setBool:YES forKey:@"deviceRegistered"];
//    [defaults setObject:[NSDictionary dictionaryWithObjectsAndKeys:@"https://mage.geointservices.io", @"serverUrl", @"test", @"username", nil] forKey:@"loginParameters"];
//
//    id storedPasswordMock = [OCMockObject mockForClass:[StoredPassword class]];
//    [[[storedPasswordMock stub] andReturn:@"goodpassword"] retrieveStoredPassword];
//
//    UINavigationController *navigationController = [[UINavigationController alloc]init];
//
//    XCTestExpectation* apiResponseArrived = [self expectationWithDescription:@"response of /api complete"];
//
//    AuthenticationTestDelegate *delegate = [[AuthenticationTestDelegate alloc] init];
//
//    __block AuthenticationCoordinator *coordinator = [[AuthenticationCoordinator alloc] initWithNavigationController:navigationController andDelegate:delegate andScheme:[MAGEScheme scheme]];
//
//    id navControllerPartialMock = OCMPartialMock(navigationController);
//
//    NSURL *url = [MageServer baseURL];
//    XCTAssertTrue([[url absoluteString] isEqualToString:@"https://mage.geointservices.io"]);
//
//    OCMExpect([navControllerPartialMock pushViewController:[OCMArg isKindOfClass:[LoginViewController class]] animated:NO])._andDo(^(NSInvocation *invocation) {
//        [apiResponseArrived fulfill];
//    });
//
//    [HTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
//        return [request.URL.host isEqualToString:@"mage.geointservices.io"] && [request.URL.path isEqualToString:@"/api"];
//    } withStubResponse:^HTTPStubsResponse*(NSURLRequest *request) {
//        NSString* fixture = OHPathForFile(@"apiSuccess.json", self.class);
//        return [HTTPStubsResponse responseWithFileAtPath:fixture
//                                                statusCode:200 headers:@{@"Content-Type":@"application/json"}];
//    }];
//
////    [coordinator start];
//
//    [self waitForExpectationsWithTimeout:5 handler:^(NSError * _Nullable error) {
//        // response came back from the server and we went to the login screen
//        id<LoginDelegate> loginDelegate = (id<LoginDelegate>)coordinator;
//
//        NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:
//                                    @"test", @"username",
//                                    @"badpassword", @"password",
//                                    @"uuid", @"uid",
//                                    [NSDictionary dictionaryWithObjectsAndKeys:
//                                     @"local", @"identifier", nil],
//                                    @"strategy",
//                                    nil];
//
//        [HTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
//            return [request.URL.host isEqualToString:@"mage.geointservices.io"] && [request.URL.path isEqualToString:@"/auth/local/signin"];
//        } withStubResponse:^HTTPStubsResponse*(NSURLRequest *request) {
//            NSError* notConnectedError = [NSError errorWithDomain:NSURLErrorDomain code:kCFURLErrorNotConnectedToInternet userInfo:nil];
//            return [HTTPStubsResponse responseWithError:notConnectedError];
//        }];
//
//        XCTestExpectation* loginResponseArrived = [self expectationWithDescription:@"response of /auth/local/signin complete"];
//        id coordinatorMock = OCMPartialMock(coordinator);
//        OCMExpect([coordinatorMock unableToAuthenticate:[OCMArg any] complete:[OCMArg any]]).andDo(^(NSInvocation *invocation) {
//            [loginResponseArrived fulfill];
//        }).andForwardToRealObject();
//
//        OCMExpect([navControllerPartialMock presentViewController:[OCMArg isKindOfClass:[UIAlertController class]] animated:YES completion:[OCMArg any]])._andDo(^(NSInvocation *invocation) {
//            __unsafe_unretained UIAlertController *alert;
//            [invocation getArgument:&alert atIndex:2];
//            XCTAssertTrue([alert.title isEqualToString:@"Disconnected Login"]);
//            [coordinator workOffline: parameters complete:^(AuthenticationStatus authenticationStatus, NSString *errorString) {
//                NSLog(@"Auth error");
//                XCTAssertTrue(authenticationStatus == AUTHENTICATION_ERROR);
//            }];
//        });
//
//        OCMStub([navControllerPartialMock pushViewController:[OCMArg isKindOfClass:[DisclaimerViewController class]] animated:NO])._andDo(^(NSInvocation *invocation) {
//            XCTFail(@"Should not have pushed the disclaimer");
//        });
//
////        [loginDelegate loginWithParameters:parameters withAuthenticationType:SERVER complete:^(AuthenticationStatus authenticationStatus, NSString *errorString) {
////            NSLog(@"Unable to authenticate");
////            XCTFail(@"Should not be in here");
////        }];
//
//        [self waitForExpectationsWithTimeout:5 handler:^(NSError * _Nullable error) {
//            OCMVerifyAll(navControllerPartialMock);
//            OCMVerifyAll(coordinatorMock);
//            [storedPasswordMock stopMocking];
//        }];
//
//    }];
//
//}
//
//- (void) skipped_testUnableToWorkOfflineDueToNoSavedPassword {
//    NSString *baseUrlKey = @"baseServerUrl";
//
//    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
//    [defaults setObject:@"https://mage.geointservices.io" forKey:baseUrlKey];
//    [defaults setObject:[NSDictionary dictionaryWithObjectsAndKeys:@"https://mage.geointservices.io", @"serverUrl", @"test", @"username", nil] forKey:@"loginParameters"];
//
//    id storedPasswordMock = [OCMockObject mockForClass:[StoredPassword class]];
//    [[[storedPasswordMock stub] andReturn:nil] retrieveStoredPassword];
//
//    UINavigationController *navigationController = [[UINavigationController alloc]init];
//
//    XCTestExpectation* apiResponseArrived = [self expectationWithDescription:@"response of /api complete"];
//
//    AuthenticationTestDelegate *delegate = [[AuthenticationTestDelegate alloc] init];
//
//    __block AuthenticationCoordinator *coordinator = [[AuthenticationCoordinator alloc] initWithNavigationController:navigationController andDelegate:delegate andScheme:[MAGEScheme scheme]];
//
//    id navControllerPartialMock = OCMPartialMock(navigationController);
//
//    NSURL *url = [MageServer baseURL];
//    XCTAssertTrue([[url absoluteString] isEqualToString:@"https://mage.geointservices.io"]);
//
//    OCMExpect([navControllerPartialMock pushViewController:[OCMArg isKindOfClass:[LoginViewController class]] animated:NO])._andDo(^(NSInvocation *invocation) {
//        [apiResponseArrived fulfill];
//    });
//
//    [HTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
//        return [request.URL.host isEqualToString:@"mage.geointservices.io"] && [request.URL.path isEqualToString:@"/api"];
//    } withStubResponse:^HTTPStubsResponse*(NSURLRequest *request) {
//        NSString* fixture = OHPathForFile(@"apiSuccess.json", self.class);
//        return [HTTPStubsResponse responseWithFileAtPath:fixture
//                                                statusCode:200 headers:@{@"Content-Type":@"application/json"}];
//    }];
//
////    [coordinator start];
//
//    [self waitForExpectationsWithTimeout:5 handler:^(NSError * _Nullable error) {
//        // response came back from the server and we went to the login screen
//        id<LoginDelegate> loginDelegate = (id<LoginDelegate>)coordinator;
//
//        NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:
//                                    @"test", @"username",
//                                    @"goodpassword", @"password",
//                                    @"uuid", @"uid",
//                                    [NSDictionary dictionaryWithObjectsAndKeys:
//                                     @"local", @"identifier", nil],
//                                    @"strategy",
//                                    nil];
//
//        [HTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
//            return [request.URL.host isEqualToString:@"mage.geointservices.io"] && [request.URL.path isEqualToString:@"/auth/local/signin"];
//        } withStubResponse:^HTTPStubsResponse*(NSURLRequest *request) {
//            NSError* notConnectedError = [NSError errorWithDomain:NSURLErrorDomain code:kCFURLErrorNotConnectedToInternet userInfo:nil];
//            return [HTTPStubsResponse responseWithError:notConnectedError];
//        }];
//
//        XCTestExpectation* loginResponseArrived = [self expectationWithDescription:@"response of /auth/local/signin complete"];
//        id coordinatorMock = OCMPartialMock(coordinator);
//        OCMExpect([coordinatorMock unableToAuthenticate:[OCMArg any] complete:[OCMArg any]]).andDo(^(NSInvocation *invocation) {
//            [loginResponseArrived fulfill];
//        }).andForwardToRealObject();
//
//        OCMExpect([navControllerPartialMock presentViewController:[OCMArg isKindOfClass:[UIAlertController class]] animated:YES completion:[OCMArg any]])._andDo(^(NSInvocation *invocation) {
//            __unsafe_unretained UIAlertController *alert;
//            [invocation getArgument:&alert atIndex:2];
//            XCTAssertTrue([alert.title isEqualToString:@"Unable to Login"]);
//            [coordinator returnToLogin: ^(AuthenticationStatus authenticationStatus, NSString *errorString) {
//                NSLog(@"Auth error");
//                XCTAssertTrue([@"We are unable to connect to the server. Please try logging in again when your connection to the internet has been restored." isEqualToString:errorString]);
//                XCTAssertTrue(authenticationStatus == UNABLE_TO_AUTHENTICATE);
//            }];
//        });
//
////        [loginDelegate loginWithParameters:parameters withAuthenticationType:SERVER complete:^(AuthenticationStatus authenticationStatus, NSString *errorString) {
////            NSLog(@"Unable to authenticate");
////            XCTFail(@"Should not be in here");
////        }];
//
//        [self waitForExpectationsWithTimeout:5 handler:^(NSError * _Nullable error) {
//            OCMVerifyAll(navControllerPartialMock);
//            OCMVerifyAll(coordinatorMock);
//            [storedPasswordMock stopMocking];
//        }];
//    }];
//}
//
//- (void)skipped_testSetURLSuccess {
//    UINavigationController *navigationController = [[UINavigationController alloc]init];
//    AuthenticationTestDelegate *delegate = [[AuthenticationTestDelegate alloc] init];
//
//    AuthenticationCoordinator *coordinator = [[AuthenticationCoordinator alloc] initWithNavigationController:navigationController andDelegate:delegate andScheme:[MAGEScheme scheme]];
//
//    id navControllerPartialMock = OCMPartialMock(navigationController);
//    XCTestExpectation* responseArrived = [self expectationWithDescription:@"response of async request has arrived"];
//    OCMExpect([navControllerPartialMock pushViewController:[OCMArg isKindOfClass:[LoginViewController class]] animated:NO])._andDo(^(NSInvocation *invocation) {
//        [responseArrived fulfill];
//    });
//
//    [HTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
//        return [request.URL.host isEqualToString:@"mage.geointservices.io"];
//    } withStubResponse:^HTTPStubsResponse*(NSURLRequest *request) {
//        NSString* fixture = OHPathForFile(@"apiSuccess.json", self.class);
//        return [HTTPStubsResponse responseWithFileAtPath:fixture
//                                                statusCode:200 headers:@{@"Content-Type":@"application/json"}];
//    }];
//
//    id<ServerURLDelegate> serverUrlDelegate = (id<ServerURLDelegate>)coordinator;
//    [serverUrlDelegate setServerURL:[NSURL URLWithString:@"https://mage.geointservices.io"]];
//    [self waitForExpectationsWithTimeout:5 handler:^(NSError * _Nullable error) {
//        OCMVerifyAll(navControllerPartialMock);
//    }];
//}
//
//- (void)skipped_testSetURLCancel {
//    UINavigationController *navigationController = [[UINavigationController alloc]init];
//    AuthenticationTestDelegate *delegate = [[AuthenticationTestDelegate alloc] init];
//
//    AuthenticationCoordinator *coordinator = [[AuthenticationCoordinator alloc] initWithNavigationController:navigationController andDelegate:delegate andScheme:[MAGEScheme scheme]];
//
//    id navControllerPartialMock = OCMPartialMock(navigationController);
//    XCTestExpectation* responseArrived = [self expectationWithDescription:@"response of async request has arrived"];
//    OCMExpect([navControllerPartialMock pushViewController:[OCMArg isKindOfClass:[ServerURLController class]] animated:NO])._andDo(^(NSInvocation *invocation) {
//        NSLog(@"server url controller pushed");
//    });
//    OCMExpect([navControllerPartialMock popViewControllerAnimated:NO])._andDo(^(NSInvocation *invocation) {
//        [responseArrived fulfill];
//    });
//
//    [HTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
//        return [request.URL.host isEqualToString:@"mage.geointservices.io"];
//    } withStubResponse:^HTTPStubsResponse*(NSURLRequest *request) {
//        XCTFail(@"No network requests should be made when the cancel action is taken after setting the server url");
//        return nil;
//    }];
//
//    id<ServerURLDelegate> serverUrlDelegate = (id<ServerURLDelegate>)coordinator;
//    [coordinator changeServerURL];
//    [serverUrlDelegate cancelSetServerURL];
//    [self waitForExpectationsWithTimeout:5 handler:^(NSError * _Nullable error) {
//        OCMVerifyAll(navControllerPartialMock);
//    }];
//}
//
//- (void)skipped_testSetURLFailVersion {
//    UINavigationController *navigationController = [[UINavigationController alloc]init];
//
//    __block id serverUrlControllerMock;
//    XCTestExpectation* responseArrived = [self expectationWithDescription:@"response of async request has arrived"];
//    AuthenticationTestDelegate *delegate = [[AuthenticationTestDelegate alloc] init];
//
//    AuthenticationCoordinator *coordinator = [[AuthenticationCoordinator alloc] initWithNavigationController:navigationController andDelegate:delegate andScheme:[MAGEScheme scheme]];
//
//    id navControllerPartialMock = OCMPartialMock(navigationController);
//
//    OCMExpect([navControllerPartialMock pushViewController:[OCMArg isKindOfClass:[ServerURLController class]] animated:NO]);
//
//    NSURL *url = [MageServer baseURL];
//    XCTAssertTrue([[url absoluteString] isEqualToString:@""]);
//
////    [coordinator start];
//
//    [HTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
//        return [request.URL.host isEqualToString:@"mage.geointservices.io"];
//    } withStubResponse:^HTTPStubsResponse*(NSURLRequest *request) {
//        serverUrlControllerMock = OCMPartialMock(coordinator.urlController);
//        OCMExpect([serverUrlControllerMock showError:[OCMArg any]])._andDo(^(NSInvocation *invocation) {
//            [responseArrived fulfill];
//        });
//        NSString* fixture = OHPathForFile(@"apiFail.json", self.class);
//        return [HTTPStubsResponse responseWithFileAtPath:fixture
//                                                statusCode:200 headers:@{@"Content-Type":@"application/json"}];
//    }];
//
//    id<ServerURLDelegate> serverUrlDelegate = (id<ServerURLDelegate>)coordinator;
//    [serverUrlDelegate setServerURL:[NSURL URLWithString:@"https://mage.geointservices.io"]];
//
//    [self waitForExpectationsWithTimeout:5 handler:^(NSError * _Nullable error) {
//        OCMVerifyAll(navControllerPartialMock);
//        OCMVerifyAll(serverUrlControllerMock);
//    }];
//}
//
//- (void) skipped_testStartWithVersionFail {
//    NSString *baseUrlKey = @"baseServerUrl";
//
//    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
//    [defaults setObject:@"https://mage.geointservices.io" forKey:baseUrlKey];
//
//    UINavigationController *navigationController = [[UINavigationController alloc]init];
//
//    __block id serverUrlControllerMock;
//    XCTestExpectation* responseArrived = [self expectationWithDescription:@"response of async request has arrived"];
//    AuthenticationTestDelegate *delegate = [[AuthenticationTestDelegate alloc] init];
//
//    AuthenticationCoordinator *coordinator = [[AuthenticationCoordinator alloc] initWithNavigationController:navigationController andDelegate:delegate andScheme:[MAGEScheme scheme]];
//
//    id navControllerPartialMock = OCMPartialMock(navigationController);
//
//    NSURL *url = [MageServer baseURL];
//    XCTAssertTrue([[url absoluteString] isEqualToString:@"https://mage.geointservices.io"]);
//
//    OCMExpect([navControllerPartialMock pushViewController:[OCMArg isKindOfClass:[ServerURLController class]] animated:NO])._andDo(^(NSInvocation *invocation) {
//        serverUrlControllerMock = OCMPartialMock(coordinator.urlController);
//        NSString *error = (NSString *)[serverUrlControllerMock error];
//
//        XCTAssertTrue([@"This version of the app is not compatible with version 4.0.0 of the server." isEqualToString:error]);
//        [responseArrived fulfill];
//    });
//
//    [HTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
//        return [request.URL.host isEqualToString:@"mage.geointservices.io"];
//    } withStubResponse:^HTTPStubsResponse*(NSURLRequest *request) {
//        NSString* fixture = OHPathForFile(@"apiFail.json", self.class);
//        return [HTTPStubsResponse responseWithFileAtPath:fixture
//                                                statusCode:200 headers:@{@"Content-Type":@"application/json"}];
//    }];
//
////    [coordinator start];
//
//    [self waitForExpectationsWithTimeout:5 handler:^(NSError * _Nullable error) {
//        OCMVerifyAll(navControllerPartialMock);
//    }];
//}

//@end
