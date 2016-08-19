//
//  ChineseIDCardOCRTests.swift
//  ChineseIDCardOCRTests
//
//  Created by GongXiang on 8/17/16.
//  Copyright © 2016 Kevin.Gong. All rights reserved.
//

import XCTest
import CoreImage

@testable import ChineseIDCardOCR

class RecognizeTests: XCTestCase {

    var image: UIImage?
    var testImage: UIImage?

    let idnumber = "130121197903270035"
    let bundle = NSBundle(forClass: RecognizeTests.self)

    override func setUp() {
        super.setUp()

        let bundle = NSBundle(forClass: RecognizeTests.self)
        image = UIImage(named: idnumber, inBundle: bundle, compatibleWithTraitCollection: nil)
        testImage = UIImage(named: "test", inBundle: bundle, compatibleWithTraitCollection: nil)

    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    /// Ensure FFNN train file load success
    func testRecognize() {

        guard let `image` = image else { return }

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

    func testImagePixelData() {

        guard let `testImage` = testImage else { return }

        let cgImage = testImage.CGImage

        guard let pixelData = CGDataProviderCopyData(CGImageGetDataProvider(cgImage)) else { return }
        let bitmapData = CFDataGetBytePtr(pixelData)

        let bitsPerPixel = CGImageGetBitsPerPixel(cgImage)
        let bitsPerComponent = CGImageGetBitsPerComponent(cgImage)

        let numberOfComponentsPerPixel = bitsPerPixel / bitsPerComponent // 1 个 components ＝ 1 bytes

        let bytesPerRow = CGImageGetBytesPerRow(cgImage) // 每一行的 字节数 ＝ 像素数（也就是图片的宽度） ＊ 每个像素的大小

        let width = bytesPerRow / numberOfComponentsPerPixel
        let height = CGImageGetHeight(cgImage)

        // 构造一个由像素组成的二维数组
        typealias BitmapRowValue = [UInt8]

        // 构造类似的二维空数组，每一个0 都是 UInt8

        /**
         [0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0]
         [0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0]
         [0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0]
         [0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0]
         [0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0]
         [0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0]
         **/

        let newRow = { return BitmapRowValue(count: width, repeatedValue: 0) }

        var imageValue = [BitmapRowValue](count: height, repeatedValue: newRow())

        // 构造以行为单位循环图片数组的range
        let yBitmapDataStrideEnumerate = 0.stride(to: bytesPerRow * height, by: bytesPerRow).enumerate() // 步长为1行
        let xBitmapDataStrideEnumerate = 0.stride(to: bytesPerRow, by: numberOfComponentsPerPixel).enumerate() // 步长为1个Components

        for (y, yBitmapData) in yBitmapDataStrideEnumerate {
            for (x, xBitmapData) in xBitmapDataStrideEnumerate {

                let c = bitmapData[yBitmapData + xBitmapData] // 利用下标获取当前指针的memory值
                //  这里需要填充ImageValue属性
                imageValue[y][x] = c < 127 ? 0 : 255
            }
        }

        for row in imageValue {
            for p in row {
                if p == 0 {
                    print("000", terminator: "")
                } else {
                    print("255", terminator: "")
                }
            }
            print("")
        }

        debugPrint(bitmapData)

        debugPrint(bitsPerPixel)
        debugPrint(bitsPerComponent)
        debugPrint(numberOfComponentsPerPixel)

        debugPrint(bytesPerRow)

        debugPrint(width)
        debugPrint(height)
    }
}
