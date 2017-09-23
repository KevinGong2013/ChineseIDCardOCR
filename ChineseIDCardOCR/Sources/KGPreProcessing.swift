//
//  KGProcessor.swift
//  ChineseIDCardOCR
//
//  Created by GongXiang on 9/23/17.
//  Copyright © 2017 Kevin.Gong. All rights reserved.
//

import Foundation
import Vision
import CoreImage

extension CGFloat {

    /// Returns a random floating point number between 0.0 and 1.0, inclusive.
    static var random: CGFloat {
        return CGFloat(arc4random())
    }

    /// Random CGFloat between 0 and n-1.
    ///
    /// - Parameter n:  Interval max
    /// - Returns:      Returns a random CGFloat point number between 0 and n max
    static func random(min: CGFloat, max: CGFloat) -> CGFloat {
        return CGFloat.random * (max - min) + min
    }
}

extension CGRect {
    func scaled(to size: CGSize) -> CGRect {
        return CGRect(
            x: self.origin.x * size.width,
            y: self.origin.y * size.height,
            width: self.size.width * size.width,
            height: self.size.height * size.height
        )
    }
}

extension CGPoint {
    func scaled(to size: CGSize) -> CGPoint {
        return CGPoint(x: self.x * size.width, y: self.y * size.height)
    }
}

public struct KGPreProcessing {

    /// 对身份证图片进行预处理
    ///
    /// - parameter image: 身份证原始图片
    ///
    /// - returns: 返回分割后的身份证号小图片

    public static func `do`(_ image: CIImage, faceBounds: CGRect, border: VNRectangleObservation? = nil, debugBlock: ((CIImage) -> ())? = nil, forTraining: Bool = false) -> [CIImage] {
        let imageSize = image.extent.size
        var inputImage = image

        if let detectedRectangle = border {
            let boundingBox = detectedRectangle.boundingBox.scaled(to: imageSize)

            // 1. 对图片进行矫正剪切
            if inputImage.extent.contains(boundingBox) && boundingBox.contains(faceBounds) {
                // Rectify the detected image and reduce it to inverted grayscale for applying model.
                let topLeft = detectedRectangle.topLeft.scaled(to: imageSize)
                let topRight = detectedRectangle.topRight.scaled(to: imageSize)
                let bottomLeft = detectedRectangle.bottomLeft.scaled(to: imageSize)
                let bottomRight = detectedRectangle.bottomRight.scaled(to: imageSize)
                inputImage = inputImage.cropped(to: boundingBox)
                    .applyingFilter("CIPerspectiveCorrection", parameters: [
                        "inputTopLeft": CIVector(cgPoint: topLeft),
                        "inputTopRight": CIVector(cgPoint: topRight),
                        "inputBottomLeft": CIVector(cgPoint: bottomLeft),
                        "inputBottomRight": CIVector(cgPoint: bottomRight)
                        ])
            }
        }

        //      2. 灰度图
        inputImage = inputImage.applyingFilter("CIColorControls", parameters: [
            kCIInputBrightnessKey: 0,
            kCIInputSaturationKey: 0,
            kCIInputContrastKey: 1.1])
            .applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: 0.7])
            .applyingGaussianBlur(sigma: 1)
            .applyingFilter("CIColorInvert")
        debugBlock?(inputImage)
        //
        //        // 3. 去燥 二值化 invert

        inputImage = SmoothThresholdFilter(inputImage,
                                           inputEdgeO: 0.35 + (forTraining ? CGFloat.random(min: -0.1, max: 0.1) : 0),
                                           inputEdge1: 0.85 + (forTraining ? CGFloat.random(min: -0.1, max: 0.1) : 0)).outputImage!
        debugBlock?(inputImage)

        if !forTraining { // training的图不需要进行切割

            // 4. 截图 将身份证数字区域截出来
            // 这里的比例系数实根据身份证的比例，计算身份证号码所在位置
            let w = faceBounds.width * 3.1 //image.size.width //
            let x = faceBounds.width * 1.6 //CGFloat = 0 //
            let y: CGFloat = 0//faceBounds.origin.y + faceBounds.height //image.size.height * 0.75 // faceBounds.origin.y + faceBounds.height
            let h = imageSize.height * 0.2

            // cropped 以后 extend 会位移，所以需要transform
            inputImage = inputImage.cropped(to: CGRect(x: x, y: y, width: w, height: h))
                .transformed(by: CGAffineTransform(translationX: -x, y: 0))
        }

        // 5. 对数字区域做字符切割
        debugBlock?(inputImage)
        return KGPreProcessing.segment(inputImage, debugBlock: debugBlock)
    }

    public static func segment(_ numbersImage: CIImage, debugBlock: ((CIImage) -> ())? = nil) -> [CIImage] {

        var images = [CIImage]()
        let group = DispatchGroup()

        let detectTextRequest = VNDetectTextRectanglesRequest { (vr, err) in

            defer { group.leave() }

            guard let textObservations = vr.results as? [VNTextObservation] else {
                debugPrint("[warning] no text dected!")
                return
            }

            for textObservation in textObservations {
                guard let cs = textObservation.characterBoxes else { continue }

                for c in cs {
                    let imageWidth = CGFloat(numbersImage.extent.width)
                    let imageHeight = CGFloat(numbersImage.extent.height)
                    // 向周围多取2个点
                    let x = c.boundingBox.origin.x * imageWidth - 2
                    let y = c.boundingBox.origin.y * imageHeight - 2
                    let width = c.boundingBox.size.width * imageWidth + 4
                    let height = c.boundingBox.size.height * imageHeight + 4

                    // 将文字切割出来
                    let image = numbersImage.cropped(to: CGRect(x: x, y: y, width: width, height: height))
                        .transformed(by: CGAffineTransform(translationX: -x, y: -y))

                    images.append(image)
                }
            }
        }

        detectTextRequest.reportCharacterBoxes = true

        let handler = VNImageRequestHandler(ciImage: numbersImage) // FIXME: 这里需要处理oritention

        do {
            group.enter()
            try handler.perform([detectTextRequest])
        } catch {
            debugPrint("[error] \(error.localizedDescription)")
        }

        group.wait()
        return images
    }
}
