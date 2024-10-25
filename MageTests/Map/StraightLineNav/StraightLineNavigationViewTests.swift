//
//  StraightLineNavigationViewTests.swift
//  MAGE
//
//  Created by Daniel Barela on 4/13/21.
//  Copyright © 2021 National Geospatial Intelligence Agency. All rights reserved.
//

import Foundation

import Quick
import Nimble
//import Nimble_Snapshots
import OHHTTPStubs

import MagicalRecord

@testable import MAGE

class StraightLineNavigationViewTests: XCTestCase {
    
    var view: UIView!
    var controller: UIViewController!
    var window: UIWindow!;
    
    @MainActor
    override func setUp() {
        window = TestHelpers.getKeyWindowVisible()
        controller = UIViewController();
        view = controller.view;
        view.backgroundColor = .systemGray;
        
        window.rootViewController = controller;
    }
    
    @MainActor
    override func tearDown() {
        for view in view.subviews {
            view.removeFromSuperview()
        }
        controller.dismiss(animated: false, completion: nil);
        window.rootViewController = nil;
        controller = nil;
    }
    
    @MainActor
    func testShouldLoadTheView() {
        let destination = CLLocationCoordinate2D(latitude: 40.1, longitude: -105.3);
        let coordinate = CLLocationCoordinate2D(latitude: 40.008, longitude: -105.2677);
        let location = CLLocation(coordinate: coordinate, altitude: 1625.8, horizontalAccuracy: 5.2, verticalAccuracy: 1.3, course: 200, courseAccuracy: 12.0, speed: 254.0, speedAccuracy: 15.0, timestamp: Date());
        let mockedCLLocationManager = MockCLLocationManager();
        mockedCLLocationManager.mockedLocation = location;
        
        let markerStubPath: String! = OHPathForFile("test_marker.png", StraightLineNavigationViewTests.self);
        var straightLineNavigationView = StraightLineNavigationView(locationManager: mockedCLLocationManager, destinationMarker: UIImage(contentsOfFile: markerStubPath), destinationCoordinate: destination, delegate: nil, scheme: MAGEScheme.scheme());
        straightLineNavigationView.populate();
        
        view.addSubview(straightLineNavigationView)
        straightLineNavigationView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .top)
    }
}
