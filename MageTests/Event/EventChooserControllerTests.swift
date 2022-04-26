//
//  EventChooserControllerTests.swift
//  MAGETests
//
//  Created by Daniel Barela on 4/13/22.
//  Copyright © 2022 National Geospatial Intelligence Agency. All rights reserved.
//

import Foundation
import Quick
import Nimble

@testable import MAGE

class MockEventSelectionDelegate: NSObject, EventSelectionDelegate {
    var didSelectCalled = false
    var eventSelected: Event?
    var actionButtonTappedCalled = false
    func didSelect(_ event: Event!) {
        didSelectCalled = true
        eventSelected = event
    }
    
    func actionButtonTapped() {
        actionButtonTappedCalled = true
    }
}

class EventChooserControllerTests : KIFSpec {
    override func spec() {
        
        describe("EventChooserControllerTests") {
            
            var window: UIWindow?;
            var view: EventChooserController?;
            var navigationController: UINavigationController?;
            
            beforeEach {
                TestHelpers.clearAndSetUpStack();
                
                navigationController = UINavigationController();
                
                window = TestHelpers.getKeyWindowVisible();
                window!.rootViewController = navigationController;
            }
            
            afterEach {
                navigationController?.viewControllers = [];
                window?.rootViewController?.dismiss(animated: false, completion: nil);
                window?.rootViewController = nil;
                navigationController = nil;
                view = nil;
                TestHelpers.clearAndSetUpStack();
            }
            
            it("Should load the event chooser with no events") {
                MageCoreDataFixtures.addUser(userId: "userabc")
                UserDefaults.standard.currentUserId = "userabc"
                
                let eventDataSource = EventTableDataSource(scheme: MAGEScheme.scheme())
                let delegate = MockEventSelectionDelegate()
                view = EventChooserController(dataSource: eventDataSource, andDelegate: delegate, andScheme: MAGEScheme.scheme())
                eventDataSource?.startFetchController()
                view?.initializeView()
                navigationController?.pushViewController(view!, animated: false)
                tester().waitForView(withAccessibilityLabel: "Refreshing Events")
                view?.eventsFetchedFromServer()
                tester().waitForAbsenceOfView(withAccessibilityLabel: "Refreshing Events")
                tester().waitForView(withAccessibilityLabel: "RETURN TO LOGIN")
                tester().tapView(withAccessibilityLabel: "RETURN TO LOGIN")
                expect(delegate.actionButtonTappedCalled).to(beTrue())
            }
            
            it("Should load the event chooser with no events and then get them from the server") {
                MageCoreDataFixtures.addUser(userId: "userabc", recentEventIds: [1])
                UserDefaults.standard.currentUserId = "userabc"
                
                let eventDataSource = EventTableDataSource(scheme: MAGEScheme.scheme())
                let delegate = MockEventSelectionDelegate()
                view = EventChooserController(dataSource: eventDataSource, andDelegate: delegate, andScheme: MAGEScheme.scheme())
                eventDataSource?.startFetchController()
                view?.initializeView()
                navigationController?.pushViewController(view!, animated: false)
                tester().waitForView(withAccessibilityLabel: "Refreshing Events")
                
                MageCoreDataFixtures.addEvent(remoteId: 1, name: "Event", formsJsonFile: "oneForm")
                MageCoreDataFixtures.addEvent(remoteId: 2, name: "Event2", formsJsonFile: "oneForm")
                MageCoreDataFixtures.addEvent(remoteId: 3, name: "Nope", formsJsonFile: "oneForm")
                MageCoreDataFixtures.addUserToEvent(eventId: 1, userId: "userabc")
                MageCoreDataFixtures.addUserToEvent(eventId: 2, userId: "userabc")
                MageCoreDataFixtures.addUserToEvent(eventId: 3, userId: "userabc")
                
                view?.eventsFetchedFromServer()
                tester().waitForAbsenceOfView(withAccessibilityLabel: "Refreshing Events")
                expect(delegate.actionButtonTappedCalled).to(beFalse())
            }
            
            it("Should load the event chooser with no events and then get one from the server") {
                MageCoreDataFixtures.addUser(userId: "userabc", recentEventIds: [1])
                UserDefaults.standard.currentUserId = "userabc"
                
                let eventDataSource = EventTableDataSource(scheme: MAGEScheme.scheme())
                let delegate = MockEventSelectionDelegate()
                view = EventChooserController(dataSource: eventDataSource, andDelegate: delegate, andScheme: MAGEScheme.scheme())
                eventDataSource?.startFetchController()
                view?.initializeView()
                navigationController?.pushViewController(view!, animated: false)
                tester().waitForView(withAccessibilityLabel: "Refreshing Events")
                
                MageCoreDataFixtures.addEvent(remoteId: 1, name: "Event", formsJsonFile: "oneForm")
                MageCoreDataFixtures.addUserToEvent(eventId: 1, userId: "userabc")
                
                view?.eventsFetchedFromServer()
                tester().waitForAbsenceOfView(withAccessibilityLabel: "Refreshing Events")
                expect(delegate.didSelectCalled).toEventually(beTrue())
                expect(delegate.eventSelected?.remoteId).to(equal(1))
            }
            
            it("Should load the event chooser with no events and then get one not recent from the server") {
                MageCoreDataFixtures.addUser(userId: "userabc", recentEventIds: [])
                UserDefaults.standard.currentUserId = "userabc"
                
                let eventDataSource = EventTableDataSource(scheme: MAGEScheme.scheme())
                let delegate = MockEventSelectionDelegate()
                view = EventChooserController(dataSource: eventDataSource, andDelegate: delegate, andScheme: MAGEScheme.scheme())
                eventDataSource?.startFetchController()
                view?.initializeView()
                navigationController?.pushViewController(view!, animated: false)
                tester().waitForView(withAccessibilityLabel: "Refreshing Events")
                
                MageCoreDataFixtures.addEvent(remoteId: 1, name: "Event", formsJsonFile: "oneForm")
                MageCoreDataFixtures.addUserToEvent(eventId: 1, userId: "userabc")
                
                view?.eventsFetchedFromServer()
                tester().waitForAbsenceOfView(withAccessibilityLabel: "Refreshing Events")
                expect(delegate.didSelectCalled).toEventually(beTrue())
                expect(delegate.eventSelected?.remoteId).to(equal(1))
            }
            
            it("Should load the event chooser with events then get an extra one") {
                MageCoreDataFixtures.addUser(userId: "userabc", recentEventIds: [])
                UserDefaults.standard.currentUserId = "userabc"
                MageCoreDataFixtures.addEvent(remoteId: 1, name: "Event", formsJsonFile: "oneForm")
                MageCoreDataFixtures.addUserToEvent(eventId: 1, userId: "userabc")
                MageCoreDataFixtures.addEvent(remoteId: 2, name: "Event", formsJsonFile: "oneForm")
                MageCoreDataFixtures.addUserToEvent(eventId: 2, userId: "userabc")
                
                let eventDataSource = EventTableDataSource(scheme: MAGEScheme.scheme())
                let delegate = MockEventSelectionDelegate()
                view = EventChooserController(dataSource: eventDataSource, andDelegate: delegate, andScheme: MAGEScheme.scheme())
                eventDataSource?.startFetchController()
                view?.initializeView()
                navigationController?.pushViewController(view!, animated: false)
                tester().waitForView(withAccessibilityLabel: "Refreshing Events")
                view?.eventsFetchedFromServer()
                tester().waitForAbsenceOfView(withAccessibilityLabel: "Refreshing Events")
                
                MageCoreDataFixtures.addEvent(remoteId: 3, name: "Event", formsJsonFile: "oneForm")
                MageCoreDataFixtures.addUserToEvent(eventId: 3, userId: "userabc")
                
                view?.eventsFetchedFromServer()
                tester().waitForView(withAccessibilityLabel: "Refresh Events")
            }
            
            it("should load the event chooser with one event not recent") {
                MageCoreDataFixtures.addEvent(remoteId: 1, name: "Event", formsJsonFile: "oneForm")
                MageCoreDataFixtures.addUser(userId: "userabc", recentEventIds: [])
                MageCoreDataFixtures.addUserToEvent(eventId: 1, userId: "userabc")
                UserDefaults.standard.currentUserId = "userabc"
                
                let eventDataSource = EventTableDataSource(scheme: MAGEScheme.scheme())
                let delegate = MockEventSelectionDelegate()
                view = EventChooserController(dataSource: eventDataSource, andDelegate: delegate, andScheme: MAGEScheme.scheme())
                eventDataSource?.startFetchController()
                view?.initializeView()
                navigationController?.pushViewController(view!, animated: false)
                tester().waitForView(withAccessibilityLabel: "Refreshing Events")
                view?.eventsFetchedFromServer()
                tester().waitForAbsenceOfView(withAccessibilityLabel: "Refreshing Events")
                tester().waitForView(withAccessibilityLabel: "Other Events (1)")
                // when there is one event it will be automatically selected
                expect(delegate.didSelectCalled).toEventually(beTrue())
                expect(delegate.eventSelected?.remoteId).to(equal(1))
            }
            
            it("should load the event chooser with one event recent") {
                MageCoreDataFixtures.addEvent(remoteId: 1, name: "Event", formsJsonFile: "oneForm")
                MageCoreDataFixtures.addUser(userId: "userabc", recentEventIds: [1])
                MageCoreDataFixtures.addUserToEvent(eventId: 1, userId: "userabc")
                UserDefaults.standard.currentUserId = "userabc"
                
                let eventDataSource = EventTableDataSource(scheme: MAGEScheme.scheme())
                let delegate = MockEventSelectionDelegate()
                view = EventChooserController(dataSource: eventDataSource, andDelegate: delegate, andScheme: MAGEScheme.scheme())
                eventDataSource?.startFetchController()
                view?.initializeView()
                navigationController?.pushViewController(view!, animated: false)
                tester().waitForView(withAccessibilityLabel: "Refreshing Events")
                view?.eventsFetchedFromServer()
                tester().waitForAbsenceOfView(withAccessibilityLabel: "Refreshing Events")
                tester().waitForView(withAccessibilityLabel: "My Recent Events (1)")
                // when there is one event it will be automatically selected
                expect(delegate.didSelectCalled).toEventually(beTrue())
                expect(delegate.eventSelected?.remoteId).to(equal(1))
            }
            
            it("should load the event chooser with one event not recent but not pick it because showEventChooserOnce was set") {
                MageCoreDataFixtures.addEvent(remoteId: 1, name: "Event", formsJsonFile: "oneForm")
                MageCoreDataFixtures.addUser(userId: "userabc", recentEventIds: [])
                MageCoreDataFixtures.addUserToEvent(eventId: 1, userId: "userabc")
                UserDefaults.standard.currentUserId = "userabc"
                UserDefaults.standard.showEventChooserOnce = true
                
                let eventDataSource = EventTableDataSource(scheme: MAGEScheme.scheme())
                let delegate = MockEventSelectionDelegate()
                view = EventChooserController(dataSource: eventDataSource, andDelegate: delegate, andScheme: MAGEScheme.scheme())
                eventDataSource?.startFetchController()
                view?.initializeView()
                navigationController?.pushViewController(view!, animated: false)
                tester().waitForView(withAccessibilityLabel: "Refreshing Events")
                view?.eventsFetchedFromServer()
                tester().waitForAbsenceOfView(withAccessibilityLabel: "Refreshing Events")
                tester().waitForView(withAccessibilityLabel: "Other Events (1)")
                expect(delegate.didSelectCalled).to(beFalse())
                expect(UserDefaults.standard.showEventChooserOnce).to(beFalse())
            }
            
            it("should load the event chooser with one event recent but not pick it because showEventChooserOnce was set") {
                MageCoreDataFixtures.addEvent(remoteId: 1, name: "Event", formsJsonFile: "oneForm")
                MageCoreDataFixtures.addUser(userId: "userabc", recentEventIds: [1])
                MageCoreDataFixtures.addUserToEvent(eventId: 1, userId: "userabc")
                UserDefaults.standard.currentUserId = "userabc"
                UserDefaults.standard.showEventChooserOnce = true
                
                let eventDataSource = EventTableDataSource(scheme: MAGEScheme.scheme())
                let delegate = MockEventSelectionDelegate()
                view = EventChooserController(dataSource: eventDataSource, andDelegate: delegate, andScheme: MAGEScheme.scheme())

                navigationController?.pushViewController(view!, animated: false)
                eventDataSource?.startFetchController()
                view?.initializeView()
                tester().waitForView(withAccessibilityLabel: "Refreshing Events")
                view?.eventsFetchedFromServer()
                tester().waitForAbsenceOfView(withAccessibilityLabel: "Refreshing Events")
                tester().waitForView(withAccessibilityLabel: "My Recent Events (1)")
                expect(delegate.didSelectCalled).to(beFalse())
                expect(UserDefaults.standard.showEventChooserOnce).to(beFalse())
                tester().waitForView(withAccessibilityLabel: "You are a part of one event.  The observations you create and your reported location will be part of this event.")
            }
            
            it("should load the event chooser with one recent and one other event") {
                MageCoreDataFixtures.addEvent(remoteId: 1, name: "Event", formsJsonFile: "oneForm")
                MageCoreDataFixtures.addEvent(remoteId: 2, name: "Event2", formsJsonFile: "oneForm")
                MageCoreDataFixtures.addUser(userId: "userabc", recentEventIds: [1])
                MageCoreDataFixtures.addUserToEvent(eventId: 1, userId: "userabc")
                MageCoreDataFixtures.addUserToEvent(eventId: 2, userId: "userabc")
                UserDefaults.standard.currentUserId = "userabc"

                let eventDataSource = EventTableDataSource(scheme: MAGEScheme.scheme())
                let delegate = MockEventSelectionDelegate()
                view = EventChooserController(dataSource: eventDataSource, andDelegate: delegate, andScheme: MAGEScheme.scheme())
                eventDataSource?.startFetchController()
                view?.initializeView()
                navigationController?.pushViewController(view!, animated: false)
                tester().waitForView(withAccessibilityLabel: "Refreshing Events")
                view?.eventsFetchedFromServer()
                tester().waitForAbsenceOfView(withAccessibilityLabel: "Refreshing Events")
                // wait for fade out
                tester().wait(forTimeInterval: 0.8)
                tester().waitForView(withAccessibilityLabel: "My Recent Events (1)")

                tester().tapRow(at: IndexPath(row: 0, section: 1), inTableViewWithAccessibilityIdentifier: "Event Table")
                expect(delegate.didSelectCalled).toEventually(beTrue())
                expect(delegate.eventSelected?.remoteId).to(equal(1))
            }
            
            it("should load the event chooser with one recent and one other event") {
                MageCoreDataFixtures.addEvent(remoteId: 1, name: "Event", formsJsonFile: "oneForm")
                MageCoreDataFixtures.addEvent(remoteId: 2, name: "Event2", formsJsonFile: "oneForm")
                MageCoreDataFixtures.addUser(userId: "userabc", recentEventIds: [1])
                MageCoreDataFixtures.addUserToEvent(eventId: 1, userId: "userabc")
                MageCoreDataFixtures.addUserToEvent(eventId: 2, userId: "userabc")
                UserDefaults.standard.currentUserId = "userabc"
                Server.setCurrentEventId(1);
                
                let observationJson: [AnyHashable : Any] = MageCoreDataFixtures.loadObservationsJson();
                MageCoreDataFixtures.addObservationToCurrentEvent(observationJson: observationJson)
                
                let observations = Observation.mr_findAll();
                expect(observations?.count).to(equal(1));
                let observation: Observation = observations![0] as! Observation;
                observation.dirty = true;
                observation.error = [
                    ObservationPushService.ObservationErrorStatusCode: 503,
                    ObservationPushService.ObservationErrorMessage: "Something Bad"
                ]
                NSManagedObjectContext.mr_default().mr_saveToPersistentStoreAndWait();
                
                expect(Observation.mr_findAll()?.count).toEventually(equal(1))
                
                let eventDataSource = EventTableDataSource(scheme: MAGEScheme.scheme())
                let delegate = MockEventSelectionDelegate()
                view = EventChooserController(dataSource: eventDataSource, andDelegate: delegate, andScheme: MAGEScheme.scheme())
                eventDataSource?.startFetchController()
                view?.initializeView()
                navigationController?.pushViewController(view!, animated: false)
                tester().waitForView(withAccessibilityLabel: "Refreshing Events")
                view?.eventsFetchedFromServer()
                tester().waitForAbsenceOfView(withAccessibilityLabel: "Refreshing Events")
                // wait for fade out
                tester().wait(forTimeInterval: 0.8)
                tester().waitForView(withAccessibilityLabel: "My Recent Events (1)")
                tester().waitForView(withAccessibilityLabel: "1 Unsent Observations")
                tester().tapRow(at: IndexPath(row: 0, section: 2), inTableViewWithAccessibilityIdentifier: "Event Table")
                expect(delegate.didSelectCalled).toEventually(beTrue())
                expect(delegate.eventSelected?.remoteId).to(equal(2))
            }
            
            it("should not allow tapping an event the user is not in because it was removed after the view loaded") {
                MageCoreDataFixtures.addEvent(remoteId: 1, name: "Event", formsJsonFile: "oneForm")
                MageCoreDataFixtures.addEvent(remoteId: 2, name: "Event2", formsJsonFile: "oneForm")
                MageCoreDataFixtures.addEvent(remoteId: 3, name: "Nope", formsJsonFile: "oneForm")
                MageCoreDataFixtures.addUser(userId: "userabc", recentEventIds: [1])
                MageCoreDataFixtures.addUserToEvent(eventId: 1, userId: "userabc")
                MageCoreDataFixtures.addUserToEvent(eventId: 2, userId: "userabc")
                MageCoreDataFixtures.addUserToEvent(eventId: 3, userId: "userabc")
                UserDefaults.standard.currentUserId = "userabc"
                
                let eventDataSource = EventTableDataSource(scheme: MAGEScheme.scheme())
                let delegate = MockEventSelectionDelegate()
                view = EventChooserController(dataSource: eventDataSource, andDelegate: delegate, andScheme: MAGEScheme.scheme())
                eventDataSource?.startFetchController()
                view?.initializeView()
                navigationController?.pushViewController(view!, animated: false)
                tester().waitForView(withAccessibilityLabel: "Refreshing Events")
                view?.eventsFetchedFromServer()
                tester().waitForAbsenceOfView(withAccessibilityLabel: "Refreshing Events")
                // wait for fade out
                tester().wait(forTimeInterval: 0.8)
                tester().waitForView(withAccessibilityLabel: "Other Events (2)")
                
                Event.mr_deleteAll(matching: NSPredicate(format: "remoteId = %d", 2), in: NSManagedObjectContext.mr_default())
                
                tester().tapRow(at: IndexPath(row: 0, section: 2), inTableViewWithAccessibilityIdentifier: "Event Table")
                tester().waitForView(withAccessibilityLabel: "Unauthorized")
                tester().tapView(withAccessibilityLabel: "Refresh Events")
                tester().waitForView(withAccessibilityLabel: "Other Events (1)")
            }
            
            it("should display all events the user is in and allow searching") {
                MageCoreDataFixtures.addEvent(remoteId: 1, name: "Event", formsJsonFile: "oneForm")
                MageCoreDataFixtures.addEvent(remoteId: 2, name: "Event2", formsJsonFile: "oneForm")
                MageCoreDataFixtures.addEvent(remoteId: 3, name: "Nope", formsJsonFile: "oneForm")
                MageCoreDataFixtures.addUser(userId: "userabc", recentEventIds: [1])
                MageCoreDataFixtures.addUserToEvent(eventId: 1, userId: "userabc")
                MageCoreDataFixtures.addUserToEvent(eventId: 2, userId: "userabc")
                MageCoreDataFixtures.addUserToEvent(eventId: 3, userId: "userabc")
                UserDefaults.standard.currentUserId = "userabc"
                
                let eventDataSource = EventTableDataSource(scheme: MAGEScheme.scheme())
                let delegate = MockEventSelectionDelegate()
                view = EventChooserController(dataSource: eventDataSource, andDelegate: delegate, andScheme: MAGEScheme.scheme())
                eventDataSource?.startFetchController()
                view?.initializeView()
                navigationController?.pushViewController(view!, animated: false)
                tester().waitForView(withAccessibilityLabel: "Refreshing Events")
                view?.eventsFetchedFromServer()
                tester().waitForAbsenceOfView(withAccessibilityLabel: "Refreshing Events")
                // wait for fade out
                tester().wait(forTimeInterval: 0.8)
                tester().waitForView(withAccessibilityLabel: "Other Events (2)")
                
                tester().waitForView(withAccessibilityLabel: "Please choose an event.  The observations you create and your reported location will be part of the selected event.")
                TestHelpers.printAllAccessibilityLabelsInWindows()
                tester().enterText("Even", intoViewWithAccessibilityLabel: "Search")
                tester().waitForView(withAccessibilityLabel: "Filtered (2)")
                tester().tapRow(at: IndexPath(row: 0, section: 0), inTableViewWithAccessibilityIdentifier: "Event Table")
                expect(delegate.didSelectCalled).toEventually(beTrue())
                expect(delegate.eventSelected?.remoteId).to(equal(1))
            }
        }
    }
}
