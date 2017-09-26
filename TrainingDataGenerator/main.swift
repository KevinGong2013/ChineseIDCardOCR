//
//  main.swift
//  TrainingDataGenerator
//
//  Created by GongXiang on 9/23/17.
//  Copyright © 2017 Kevin.Gong. All rights reserved.
//

import Foundation
import CoreImage
import AppKit

let projectDir = "/Users/Kevin/develop/Swift/ChineseIDCardOCR/TrainingDataGenerator"
let numberImgesPath = projectDir + "/Scripts/generatedNumberImages"
let signleImagePath = projectDir + "/Scripts/signleImages"
let testSignleImagePath = projectDir + "/Scripts/testSignleImages"

let imageDirectory = URL(fileURLWithPath: numberImgesPath, isDirectory: true)
func name(_ idx: Int) -> URL {
    return imageDirectory.appendingPathComponent("\(idx).png")
}

let testSignleImageDirectory = URL(fileURLWithPath: testSignleImagePath, isDirectory: true)
let signleImageDirectory = URL(fileURLWithPath: signleImagePath, isDirectory: true)
func signleImageURL(label: Int, idx: Int, isTest: Bool) -> URL {
    return (isTest ? testSignleImageDirectory : signleImageDirectory).appendingPathComponent("\(label == 10 ? "X" : String(label))/\(idx).png")
}

let fm = FileManager.default

do {
    try fm.removeItem(atPath: signleImagePath)
    try fm.removeItem(atPath: testSignleImagePath)
} catch {
    print(error)
}

(0...10).forEach {
    let _ = try? fm.createDirectory(atPath: signleImagePath + "/\($0 == 10 ? "X" : String($0))", withIntermediateDirectories: true, attributes: nil)
    let _ = try? fm.createDirectory(atPath: testSignleImagePath + "/\($0 == 10 ? "X" : String($0))", withIntermediateDirectories: true, attributes: nil)
}

guard let paths = fm.subpaths(atPath: numberImgesPath), paths.count == 110 else {
    print("请先执行`generateNumberImages.py`, 生成身份证号码图片.")
    exit(EX_OK)
}

let count = paths.count

let gpuContext = CIContext(options: [kCIContextUseSoftwareRenderer: false])
let colorSpace = CGColorSpaceCreateDeviceRGB()

paths.enumerated().forEach { idx, path in

    if let image = CIImage(contentsOf: name(idx)) {
        let preprocessedImage = KGPreProcessing.do(image)
        let numbers = KGPreProcessing.segment(preprocessedImage).map { x in x.0 }

        if numbers.count != 11 {
            print("bad image idx: \(idx)")
        } else {
            // signleImage/0/0.png ..... signleImage/0/100000.png
            numbers.enumerated().forEach { offset, ciImage in
                let url = signleImageURL(label: offset, idx: idx, isTest: idx > 90) // 一共110 前90 训练，后20 测试
                do {
                    try gpuContext.writePNGRepresentation(of: ciImage, to: url, format: kCIFormatRGBA8, colorSpace: colorSpace, options: [:])
                } catch {
                    print("[error] \(error.localizedDescription)")
                }
            }
            print("idx: \(idx) ~done")
        }
    } else {
        print("can't load CIImage form \(name(idx))")
    }
}

print("done")
print("执行`training.py`训练神经网络吧～")
