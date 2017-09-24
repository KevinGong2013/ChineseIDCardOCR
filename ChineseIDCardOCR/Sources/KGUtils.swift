//
//  KGUtils.swift
//  ChineseIDCardOCR
//
//  Created by GongXiang on 9/22/17.
//  Copyright © 2017 Kevin.Gong. All rights reserved.
//

import Foundation
import CoreImage
import VideoToolbox

#if os(iOS)

public extension UIImage {
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
#endif

#if os(macOS)
import AppKit
    
public extension NSImage {
    /**
     Creates a new NSImage from a CVPixelBuffer, using Core Image.
     */

    public convenience init?(pixelBuffer: CVPixelBuffer, context: CIContext) {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let rect = CGRect(x: 0, y: 0, width: CVPixelBufferGetWidth(pixelBuffer),
                          height: CVPixelBufferGetHeight(pixelBuffer))
        if let cgImage = context.createCGImage(ciImage, from: rect) {
            self.init(cgImage: cgImage, size: rect.size)
        } else {
            return nil
        }
    }
}
#endif

public extension CGImage {
 
    public var data: Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "png" as CFString, 1, nil) else { return nil }
        let option = [kCGImagePropertyHasAlpha: false]
        CGImageDestinationAddImage(destination, self, option as CFDictionary)
        CGImageDestinationFinalize(destination)
        return data as Data
    }
    
    func pixelBuffer(_ colorspace: CGColorSpace = CGColorSpaceCreateDeviceGray()) -> CVPixelBuffer? {
        var pb: CVPixelBuffer? = nil
        
        CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_OneComponent8, nil, &pb)
        guard let pixelBuffer = pb else { return nil }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue:0))
        
        let bitmapContext = CGContext(data: CVPixelBufferGetBaseAddress(pixelBuffer), width: width, height: height, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer), space: colorspace, bitmapInfo: 0)!
        
        bitmapContext.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        return pixelBuffer
    }
}
