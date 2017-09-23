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

extension NSImage {
    var pngData: Data? {
        guard let tiffRepresentation = tiffRepresentation, let bitmapImage = NSBitmapImageRep(data: tiffRepresentation) else { return nil }
        return bitmapImage.representation(using: .png, properties: [:])
    }
    func pngWrite(to url: URL, options: Data.WritingOptions = .atomic) -> Bool {
        do {
            try pngData?.write(to: url, options: options)
            return true
        } catch {
            print(error.localizedDescription)
            return false
        }
    }
}

let projectDir = "/Users/Kevin/develop/Swift/4.0/ChineseIDCardOCR/TrainingDataGenerator"
let numberImgesPath = projectDir + "/Scripts/generatedNumberImages"
let signleImagePath = projectDir + "/Scripts/signleImages"

let imageDirectory = URL(fileURLWithPath: numberImgesPath, isDirectory: true)
func name(_ idx: Int) -> URL {
    return imageDirectory.appendingPathComponent("\(idx).png")
}

let signleImageDirectory = URL(fileURLWithPath: signleImagePath, isDirectory: true)
func signleImageURL(_ idx: Int, offset: Int) -> URL {
    return signleImageDirectory.appendingPathComponent("\(offset)/\(idx).png")
}

let fm = FileManager.default

let _ = try? fm.removeItem(atPath: signleImagePath)
let _ = try? fm.createDirectory(atPath: signleImagePath, withIntermediateDirectories: true, attributes: nil)
(0...10).forEach {
    let _ = try? fm.createDirectory(atPath: signleImagePath + "/\($0)", withIntermediateDirectories: true, attributes: nil)
}

guard let paths = fm.subpaths(atPath: numberImgesPath), paths.count > 0 else {
    print("请先执行`generateNumberImages.py`, 生成身份证号码图片")
    exit(EX_OK)
}

let count = paths.count
let semaphore = DispatchSemaphore(value: count)

paths.enumerated().forEach { idx, path in
    DispatchQueue.global(qos: .userInteractive).async {
        if let image = CIImage(contentsOf: name(idx)) {
            let numbers = KGPreProcessing.do(image, faceBounds: CGRect.zero, forTraining: true)
            if numbers.count != 10 {
                print("bad image idx: \(idx)")
            } else {
                // signleImage/0/0.png ..... signleImage/0/100000.png
                numbers.enumerated().forEach { offset, ciImage in
                    if let cgImage = CIContext().createCGImage(ciImage, from: ciImage.extent) {
                        let nsImage = NSImage(cgImage: cgImage, size: ciImage.extent.size)
                        if nsImage.pngWrite(to: signleImageURL(idx, offset: offset)) {
                            print("bad image idx: \(idx), offset: \(offset)")
                        }
                    } else {
                        print("bad image idx: \(idx), offset: \(offset)")
                    }
                }
                let value = semaphore.signal()
                print("finised \(value)/\(count)")
            }
        }
    }
}

print("done")
print("执行`training.py`训练神经网络吧～")



