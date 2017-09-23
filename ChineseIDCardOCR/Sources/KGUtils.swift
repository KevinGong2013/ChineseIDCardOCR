//
//  KGUtils.swift
//  ChineseIDCardOCR
//
//  Created by GongXiang on 9/22/17.
//  Copyright © 2017 Kevin.Gong. All rights reserved.
//

import Foundation
import VideoToolbox

/// reference from: https://github.com/artemnovichkov/iOS-11-by-Examples/blob/master/iOS-11-by-Examples/CoreML/UIImage%2BCVPixelBuffer.swift
public extension UIImage {

    func resize(to newSize: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(CGSize(width: newSize.width, height: newSize.height), true, 1.0)
        self.draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()

        return resizedImage
    }

    func buffer() -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer? = nil

        let width = Int(self.size.width)
        let height = Int(self.size.height)

        CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_OneComponent8, nil, &pixelBuffer)
        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue:0))

        let colorspace = CGColorSpaceCreateDeviceGray()
        let bitmapContext = CGContext(data: CVPixelBufferGetBaseAddress(pixelBuffer!), width: width, height: height, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: colorspace, bitmapInfo: 0)!

        guard let cgImage = cgImage else { return nil }

        bitmapContext.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        return pixelBuffer
    }
}

public extension UIImage {
    /**
     Creates a new UIImage from a CVPixelBuffer.
     NOTE: This only works for RGB pixel buffers, not for grayscale.
     */
    public convenience init?(pixelBuffer: CVPixelBuffer) {
        var cgImage: CGImage?
        VTCreateCGImageFromCVPixelBuffer(pixelBuffer, nil, &cgImage)

        if let cgImage = cgImage {
            self.init(cgImage: cgImage)
        } else {
            return nil
        }
    }

    /**
     Creates a new UIImage from a CVPixelBuffer, using Core Image.
     */
    public convenience init?(pixelBuffer: CVPixelBuffer, context: CIContext) {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let rect = CGRect(x: 0, y: 0, width: CVPixelBufferGetWidth(pixelBuffer),
                          height: CVPixelBufferGetHeight(pixelBuffer))
        if let cgImage = context.createCGImage(ciImage, from: rect) {
            self.init(cgImage: cgImage)
        } else {
            return nil
        }
    }
}
