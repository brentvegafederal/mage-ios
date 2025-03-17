//
//  MockMageServer.swift
//  MAGETests
//
//  Created by Daniel Barela on 7/10/20.
//  Copyright © 2020 National Geospatial Intelligence Agency. All rights reserved.
//

import Foundation
import OHHTTPStubs

class MockMageServerDelegate {
    var urls: [URL?] = [];

    func urlCalled(_ url: URL?, method: String?) {
        urls.append(url);
    }
}

class MockMageServer: NSObject {
    
    public static func initializeHttpStubs() {
        HTTPStubs.stubRequests(passingTest: { (request) -> Bool in
            return request.url == URL(string: "https://magetest/icon.png");
        }) { (request) -> HTTPStubsResponse in
            let stubPath = OHPathForFile("icon27.png", MockMageServer.self)
            return HTTPStubsResponse(fileAtPath: stubPath!, statusCode: 200, headers: ["Content-Type": "image/png"]);
        };
    }
    
    @discardableResult public static func stubJSONSuccessRequest(url: String, filePath: String, jsonBody: [AnyHashable: Any]? = nil, delegate: MockMageServerDelegate? = nil) -> HTTPStubsDescriptor {
        var stubTest = isAbsoluteURLString(url);
        if let safeBody = jsonBody {
            stubTest = stubTest && hasJsonBody(safeBody);
        }
        let stubbed = stub(condition: stubTest) { (request) -> HTTPStubsResponse in
            if (delegate != nil) {
                delegate?.urlCalled(request.url, method: request.httpMethod);
            }
            let stubPath = OHPathForFile(filePath, MockMageServer.self);
            return HTTPStubsResponse(fileAtPath: stubPath!, statusCode: 200, headers: ["Content-Type": "application/json"]);
        }
        return stubbed;
    }
}

extension MockMageServer {
    static func stubAPIResponses() {
        print("🛠 Stubbing API responses...")
        
        stub(condition: isMethodGET() && isHost("magetest") && isPath("/api")) { _ in
            print("📡 Stubbed /api request")
            return fixture(filePath: "apiSuccess.json", status: 200)
        }
        
        stub(condition: isMethodPOST() && isHost("magetest") && isPath("/auth/local/signin")) { _ in
            print("📡 Stubbed /auth/local/signin request")
            return fixture(filePath: "signinSuccess.json", status: 200)
        }

        stub(condition: isMethodPOST() && isHost("magetest") && isPath("/auth/token")) { _ in
            print("📡 Stubbed /auth/token request")
            return fixture(filePath: "authorizeLocalSuccess.json", status: 200)
        }
    }

    private static func fixture(filePath: String, status: Int32) -> HTTPStubsResponse {
        let stubPath = OHPathForFile(filePath, MockMageServer.self)!
        return HTTPStubsResponse(fileAtPath: stubPath, statusCode: status, headers: ["Content-Type": "application/json"])
    }
}

extension MockMageServer {
    static func stubRegisterDeviceResponses() {
        print("🛠 Stubbing API responses for Register Device...")

        // 🔹 Call the existing general stubbing function
        stubAPIResponses()

        // 🔹 Override the /auth/token response to simulate device registration
        stub(condition: isMethodPOST() && isHost("magetest") && isPath("/auth/token")) { _ in
            print("📡 Stubbed /auth/token request (403 - Registration Required)")
            let response = HTTPStubsResponse()
            response.statusCode = 403
            return response
        }
    }
}

