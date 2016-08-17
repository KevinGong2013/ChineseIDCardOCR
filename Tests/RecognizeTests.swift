//
//  ChineseIDCardOCRTests.swift
//  ChineseIDCardOCRTests
//
//  Created by GongXiang on 8/17/16.
//  Copyright © 2016 Kevin.Gong. All rights reserved.
//

import XCTest
@testable import ChineseIDCardOCR

class RecognizeTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    /// Ensure FFNN train file load success
    func testRecognize() {

        let bundle = NSBundle(forClass: RecognizeTests.self)
        let idnumber = "130121197903270035"
        let image = UIImage(named: idnumber, inBundle: bundle, compatibleWithTraitCollection: nil)!

        let ocr = IDCardOCR()

        let semaphore = dispatch_semaphore_create(0)

        var recoginzedResult = ""
        ocr.recognize(image) {
            recoginzedResult = $0
            dispatch_semaphore_signal(semaphore)
        }

        let time = dispatch_time(DISPATCH_TIME_NOW, Int64(10 * NSEC_PER_SEC))

        let f = dispatch_semaphore_wait(semaphore, time)

        XCTAssert(f == 0, "Recoginzed time out !!")
        if f == 0 {
            XCTAssert(recoginzedResult == idnumber, "Recoginzed failed !!")
        }
    }
}
