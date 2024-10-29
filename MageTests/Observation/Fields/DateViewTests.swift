//
//  EditDateFieldViewTests.swift
//  MAGE
//
//  Created by Daniel Barela on 5/12/20.
//  Copyright © 2020 National Geospatial Intelligence Agency. All rights reserved.
//

import Foundation
import Quick
import Nimble
//import Nimble_Snapshots

@testable import MAGE

extension DateView {
    func getDatePicker() -> UIDatePicker {
        return datePicker;
    }
}

class DateViewTests: XCTestCase {
        
    var dateFieldView: DateView!
    var field: [String: Any]!
    
    var view: UIView!
    var controller: UIViewController!
    var window: UIWindow!;
    
    let formatter = DateFormatter();

    @MainActor
    override func setUp() {
        
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ";
        formatter.locale = Locale(identifier: "en_US_POSIX");
        
        controller = UIViewController();
        view = UIView(forAutoLayout: ());
        view.autoSetDimension(.width, toSize: 375);
        view.backgroundColor = .white;
        
        controller.view.addSubview(view);
        
        window = TestHelpers.getKeyWindowVisible();
        window.rootViewController = controller;
        
        NSDate.setDisplayGMT(false);
        
        field = [
            "title": "Date Field",
            "id": 8,
            "name": "field8"
        ];
        for subview in view.subviews {
            subview.removeFromSuperview();
        }
    }
    
    @MainActor
    override func tearDown() {
        for subview in view.subviews {
            subview.removeFromSuperview();
        }
    }
    
    @MainActor
    func testNoInitialValue() {
        dateFieldView = DateView(field: field);
        dateFieldView.applyTheme(withScheme: MAGEScheme.scheme());
        view.addSubview(dateFieldView)
        dateFieldView.autoPinEdgesToSuperviewEdges();
    }
    
    @MainActor
    func testInitialValueSet() {
        dateFieldView = DateView(field: field, value: "2013-06-22T08:18:20.000Z");
        dateFieldView.applyTheme(withScheme: MAGEScheme.scheme());
        view.addSubview(dateFieldView)
        dateFieldView.autoPinEdgesToSuperviewEdges();
        tester().waitForView(withAccessibilityLabel: field["name"] as? String);
        expect(self.dateFieldView.textField.text).to(equal("2013-06-22 02:18 MDT"));
    }
    
    @MainActor
    func testSetValueLater() {
        dateFieldView = DateView(field: field);
        dateFieldView.applyTheme(withScheme: MAGEScheme.scheme());
        
        view.addSubview(dateFieldView)
        dateFieldView.autoPinEdgesToSuperviewEdges();
        
        dateFieldView.setValue( "2013-06-22T08:18:20.000Z")
        expect(self.dateFieldView.textField.text).to(equal("2013-06-22 02:18 MDT"));
    }
    
    @MainActor
    func testSetValueLaterAsAny() {
        dateFieldView = DateView(field: field);
        dateFieldView.applyTheme(withScheme: MAGEScheme.scheme());
        
        view.addSubview(dateFieldView)
        dateFieldView.autoPinEdgesToSuperviewEdges();
        
        dateFieldView.setValue("2013-06-22T08:18:20.000Z" as Any?)
        expect(self.dateFieldView.textField.text).to(equal("2013-06-22 02:18 MDT"));
    }
    
    @MainActor
    func testSetvalueWithTouchInputs() {
        let delegate = MockFieldDelegate()
        
        dateFieldView = DateView(field: field, delegate: delegate, value: "2020-11-01T08:18:00.000Z");
        dateFieldView.applyTheme(withScheme: MAGEScheme.scheme());
        
        view.addSubview(dateFieldView)
        dateFieldView.autoPinEdgesToSuperviewEdges();
        
        tester().waitForView(withAccessibilityLabel: field["name"] as? String);
        tester().tapView(withAccessibilityLabel: field["name"] as? String);
        tester().waitForView(withAccessibilityLabel: (field["name"] as? String ?? "") + " Date Picker");
        tester().selectDatePickerValue(["Nov 2", "7", "00", "AM"], with: .forwardFromCurrentValue);
        tester().tapView(withAccessibilityLabel: "Done");
        
        let formatter = DateFormatter();
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ";
        formatter.locale = Locale(identifier: "en_US_POSIX");
        
        let date = formatter.date(from: "2020-11-02T14:00:00.000Z")!;
        
        expect(delegate.fieldChangedCalled) == true;
        expect(delegate.newValue as? String) == formatter.string(from: date);
        expect(self.dateFieldView.textField.text).to(equal((date as NSDate).formattedDisplay()));
    }
    
    @MainActor
    func testSetValueWithTouchInputsInGMT() {
        NSDate.setDisplayGMT(true);
        let delegate = MockFieldDelegate()
        
        dateFieldView = DateView(field: field, delegate: delegate, value: "2020-11-01T08:18:00.000Z");
        dateFieldView.applyTheme(withScheme: MAGEScheme.scheme());
        
        view.addSubview(dateFieldView)
        dateFieldView.autoPinEdgesToSuperviewEdges();
        
        tester().waitForAnimationsToFinish();
        
        tester().waitForView(withAccessibilityLabel: field["name"] as? String);
        tester().tapView(withAccessibilityLabel: field["name"] as? String);
        tester().waitForView(withAccessibilityLabel: (field["name"] as? String ?? "") + " Date Picker");
        
        tester().selectDatePickerValue(["Nov 2", "7", "00", "AM"], with: .forwardFromCurrentValue);
        tester().tapView(withAccessibilityLabel: "Done");
        
        let formatter = DateFormatter();
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ";
        formatter.locale = Locale(identifier: "en_US_POSIX");
        print("what time zone \(NSTimeZone.system)")
        let date = formatter.date(from: "2020-11-02T07:00:00.000Z")!;
        // IMPORTANT: THIS IS TO CORRECT FOR A BUG IN KIF, YOU MUST COMPARE AGAINST THE DATE YOU SET
        // PLUS THE OFFSET FROM GMT OR IT WILL NOT WORK
        // IF THIS BUG IS CLOSED YOU CAN REMOVE THIS LINE: https://github.com/kif-framework/KIF/issues/1214
        //                print("how many seconds from gmt are we \(TimeZone.current.secondsFromGMT())")
        //                date.addTimeInterval(TimeInterval(-TimeZone.current.secondsFromGMT(for: date)));
        expect(delegate.fieldChangedCalled) == true;
        expect(delegate.newValue as? String) == formatter.string(from: date);
        expect(self.dateFieldView.textField.text).to(equal((date as NSDate).formattedDisplay()));
    }
    
    @MainActor
    func testSetValueWithTouchInputsThenCancel() {
        let delegate = MockFieldDelegate()
        
        let value = "2020-11-01T08:18:00.000Z";
        
        dateFieldView = DateView(field: field, delegate: delegate, value: value);
        dateFieldView.applyTheme(withScheme: MAGEScheme.scheme());
        
        view.addSubview(dateFieldView)
        dateFieldView.autoPinEdgesToSuperviewEdges();
        
        tester().waitForView(withAccessibilityLabel: field["name"] as? String);
        tester().tapView(withAccessibilityLabel: field["name"] as? String);
        tester().waitForView(withAccessibilityLabel: (field["name"] as? String ?? "") + " Date Picker");
        tester().selectDatePickerValue(["Nov 2", "7", "00", "AM"], with: .forwardFromCurrentValue);
        tester().tapView(withAccessibilityLabel: "Cancel");
        
        let formatter = DateFormatter();
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ";
        formatter.locale = Locale(identifier: "en_US_POSIX");
        
        let date = formatter.date(from: value)!;
        
        expect(delegate.fieldChangedCalled) == false;
        expect(self.dateFieldView.textField.text).to(equal((date as NSDate).formattedDisplay()));
    }
    
    // this test is finicky
    @MainActor
    func testSetClearTheTextFieldViaTouch() {
        let delegate = MockFieldDelegate()
        
        let value = "2020-11-01T08:18:00.000Z";
        
        dateFieldView = DateView(field: field, delegate: delegate, value: value);
        dateFieldView.applyTheme(withScheme: MAGEScheme.scheme());
        
        view.addSubview(dateFieldView)
        dateFieldView.autoPinEdgesToSuperviewEdges();
        
        
        tester().waitForView(withAccessibilityLabel: field["name"] as? String);
        tester().waitForTappableView(withAccessibilityLabel: field["name"] as? String);
        tester().tapView(withAccessibilityLabel: field["name"] as? String);
        tester().waitForView(withAccessibilityLabel: (field["name"] as? String ?? "") + " Date Picker");
        tester().clearTextFromFirstResponder();
        tester().tapView(withAccessibilityLabel: "Done");
        
        let formatter = DateFormatter();
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ";
        formatter.locale = Locale(identifier: "en_US_POSIX");
        
        expect(delegate.fieldChangedCalled) == true;
        expect(delegate.newValue).to(beNil());
        expect(self.dateFieldView.textField.text).to(equal(""));
    }
    
    @MainActor
    func testSetValidFalse() {
        dateFieldView = DateView(field: field);
        dateFieldView.applyTheme(withScheme: MAGEScheme.scheme());
        
        view.addSubview(dateFieldView)
        dateFieldView.autoPinEdgesToSuperviewEdges();
        
        dateFieldView.setValid(false);
    }
    
    @MainActor
    func testSetValidTrueAfterBeingInvalid() {
        dateFieldView = DateView(field: field);
        dateFieldView.applyTheme(withScheme: MAGEScheme.scheme());
        
        view.addSubview(dateFieldView)
        dateFieldView.autoPinEdgesToSuperviewEdges();
        
        dateFieldView.setValid(false);
        dateFieldView.setValid(true);
    }
    
    @MainActor
    func testRequiredFieldIsInvalidIfEmpty() {
        field[FieldKey.required.key] = true;
        dateFieldView = DateView(field: field);
        dateFieldView.applyTheme(withScheme: MAGEScheme.scheme());
        
        view.addSubview(dateFieldView)
        dateFieldView.autoPinEdgesToSuperviewEdges();
        
        expect(self.dateFieldView.isEmpty()) == true;
        expect(self.dateFieldView.isValid(enforceRequired: true)) == false;
    }
    
    @MainActor
    func testRequiredFieldIsValidIfNotEmpty() {
        field[FieldKey.required.key] = true;
        dateFieldView = DateView(field: field, value: "2013-06-22T08:18:20.000Z");
        dateFieldView.applyTheme(withScheme: MAGEScheme.scheme());
        
        view.addSubview(dateFieldView)
        dateFieldView.autoPinEdgesToSuperviewEdges();
        
        expect(self.dateFieldView.isEmpty()) == false;
        expect(self.dateFieldView.isValid(enforceRequired: true)) == true;
    }
    
    @MainActor
    func testRequiredFieldHasTitleWhichIndicatesRequired() {
        field[FieldKey.required.key] = true;
        dateFieldView = DateView(field: field);
        dateFieldView.applyTheme(withScheme: MAGEScheme.scheme());
        
        view.addSubview(dateFieldView)
        dateFieldView.autoPinEdgesToSuperviewEdges();
    }
    
    @MainActor
    func testDelegate() {
        let formatter = DateFormatter();
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ";
        formatter.locale = Locale(identifier: "en_US_POSIX");
        
        let delegate = MockFieldDelegate()
        dateFieldView = DateView(field: field, delegate: delegate, value: "2013-06-22T08:18:20.000Z");
        dateFieldView.applyTheme(withScheme: MAGEScheme.scheme());
        view.addSubview(dateFieldView)
        dateFieldView.autoPinEdgesToSuperviewEdges();
        let newDate = Date(timeIntervalSince1970: 10000000);
        dateFieldView.textFieldDidBeginEditing(dateFieldView.textField);
        dateFieldView.getDatePicker().date = newDate;
        dateFieldView.dateChanged();
        dateFieldView.textFieldDidEndEditing(dateFieldView.textField);
        expect(delegate.fieldChangedCalled) == true;
        expect(delegate.newValue as? String) == formatter.string(from: newDate);
    }
    
    @MainActor
    func testDoneButotnShouldSendNilAsNewValue() {
        let formatter = DateFormatter();
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ";
        formatter.locale = Locale(identifier: "en_US_POSIX");
        
        let delegate = MockFieldDelegate()
        dateFieldView = DateView(field: field, delegate: delegate, value: "2013-06-22T08:18:20.000Z");
        dateFieldView.applyTheme(withScheme: MAGEScheme.scheme());
        view.addSubview(dateFieldView)
        dateFieldView.autoPinEdgesToSuperviewEdges();
        dateFieldView.textField.text = "";
        _ = dateFieldView.textFieldShouldClear(dateFieldView.textField);
        expect(delegate.fieldChangedCalled) == true;
        expect(self.dateFieldView.textField.text) == "";
        expect(self.dateFieldView.getValue()).to(beNil());
    }
}
