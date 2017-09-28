//
//  KGProcessor.swift
//  ChineseIDCardOCR
//
//  Created by GongXiang on 9/23/17.
//  Copyright © 2017 Kevin.Gong. All rights reserved.
//

import CoreImage
import Vision

#if os(macOS)
import AppKit
#endif

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

extension CGPoint {
    func scaled(to size: CGSize) -> CGPoint {
        return CGPoint(x: self.x * size.width, y: self.y * size.height)
    }
}

public struct KGPreProcessing {

    // 根据自己特定业务下的图片，可以调整相应的预处理参数
    
    public struct Configuration {

        public var colorMonochromeFilterInputColor: CIColor // CIColorMonochrome kCIInputColorKey 参数
        public var colorControls: (CGFloat, CGFloat, CGFloat) // CIColorControls Saturation, Brightness, Contrast
        public var exposureAdjustEV: CGFloat // CIExposureAdjust IInputEVKey

        public var gaussianBlurSigma: Double

        public var smoothThresholdFilter: (CGFloat, CGFloat) // inputEdgeO, inputEdge1

        public var unsharpMask: (CGFloat, CGFloat) // Radius, Intensity

        public init() {
            colorMonochromeFilterInputColor = CIColor(red: 0.75, green: 0.75, blue: 0.75)
            colorControls = (0.4, 0.2, 1.1)
            exposureAdjustEV = 0.7
            gaussianBlurSigma = 0.4
            smoothThresholdFilter = (0.35, 0.85)
            unsharpMask = (2.5, 0.5)
        }
    }

    /// 对待处理图片进行识别前预处理
    ///
    /// - parameter image: 待处理图片
    ///
    /// - returns: 返回处理后后的图片

    public static func `do`(_ numbersAreaImage: CIImage, configuration conf: Configuration = Configuration(), debugBlock: ((CIImage) -> ())? = nil) -> CIImage {

        var inputImage = numbersAreaImage

        // 0x00. 灰度图
        inputImage = inputImage.applyingFilter("CIColorMonochrome", parameters: [kCIInputColorKey: conf.colorMonochromeFilterInputColor])
        debugBlock?(inputImage)

        // 0x01. 提升亮度, 亮度 可以损失一部分背景纹理 饱和度不能太高
        inputImage = inputImage.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: conf.colorControls.0,
            kCIInputBrightnessKey: conf.colorControls.1,
            kCIInputContrastKey: conf.colorControls.2])
        debugBlock?(inputImage)

        // 0x02 曝光调节
        inputImage = inputImage.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: conf.exposureAdjustEV])
        debugBlock?(inputImage)

        // 0x03 高斯模糊
        inputImage = inputImage.applyingGaussianBlur(sigma: conf.gaussianBlurSigma)
        debugBlock?(inputImage)

        // 0x04. 去燥
        inputImage = SmoothThresholdFilter(inputImage,
                                           inputEdgeO: conf.smoothThresholdFilter.0,
                                           inputEdge1: conf.smoothThresholdFilter.1).outputImage ?? inputImage
        debugBlock?(inputImage)

        // 0x06 增强文字轮廓
        inputImage = inputImage.applyingFilter("CIUnsharpMask",
                                               parameters: [kCIInputRadiusKey: conf.unsharpMask.0, kCIInputIntensityKey: conf.unsharpMask.1])
        debugBlock?(inputImage)

        return inputImage
    }

    /// 检测并截取图片上的身份证号码所在区域, 请保证身份证头像两眼连线与水平线角度不超过45度。
    ///
    /// - parameter image: 身份证原始图片
    ///
    /// - returns: 返回截取后的身份证号码区域

    public static func detectChineseIDCardNumbersAra(_ cardImage: CIImage, debugBlock: ((CIImage) -> ())? = nil) -> CIImage? {

        var inputImage = cardImage
        debugBlock?(inputImage)

        let imageSize = inputImage.extent.size
        var croppedSize = imageSize // 用于根据身份证比例定位号码所在区域

        // step 1: 检测身份证的矩形框
        let detectRectangleSemaphore = DispatchSemaphore(value: 0)
        let rectangleRequest = VNDetectRectanglesRequest { (request, err) in
            defer { detectRectangleSemaphore.signal() }
            // FIXME: 查找最大的一个矩形
            if let recttangleObservation = (request.results?.first as? VNRectangleObservation) {
                let boundingBox = recttangleObservation.boundingBox.scaled(to: imageSize)
                if inputImage.extent.contains(boundingBox) {
                    // Rectify the detected image and reduce it to inverted grayscale for applying model.
                    let topLeft = recttangleObservation.topLeft.scaled(to: imageSize)
                    let topRight = recttangleObservation.topRight.scaled(to: imageSize)
                    let bottomLeft = recttangleObservation.bottomLeft.scaled(to: imageSize)
                    let bottomRight = recttangleObservation.bottomRight.scaled(to: imageSize)
                    inputImage = inputImage.cropped(to: boundingBox)
                        .applyingFilter("CIPerspectiveCorrection", parameters: [
                            "inputTopLeft": CIVector(cgPoint: topLeft),
                            "inputTopRight": CIVector(cgPoint: topRight),
                            "inputBottomLeft": CIVector(cgPoint: bottomLeft),
                            "inputBottomRight": CIVector(cgPoint: bottomRight)
                            ])
                    croppedSize = boundingBox.size
                    debugBlock?(inputImage)
                }
            }
        }

        // 检测身份证的矩形框
        let handler = VNImageRequestHandler(ciImage: inputImage)

        DispatchQueue.global(qos: .userInteractive).async {
            do {
                try handler.perform([rectangleRequest])
            } catch {
                fatalError(error.localizedDescription)
            }
        }

        detectRectangleSemaphore.wait()

        // step 2: 快速的进行一个人脸定位
        let detector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: nil)!
        let features = detector.features(in: inputImage)

        guard let faceFeature = features.first as? CIFaceFeature, faceFeature.hasLeftEyePosition &&
            faceFeature.hasRightEyePosition &&
            faceFeature.hasMouthPosition &&
            !faceFeature.leftEyeClosed &&
            !faceFeature.rightEyeClosed &&
            !faceFeature.hasFaceAngle else {
                debugPrint(features)
                return nil
        }

        if let f = debugBlock { // 将脸部的矩形画出来
            guard let cgImage = CIContext().createCGImage(inputImage, from: inputImage.extent) else { fatalError() }
            #if os(iOS)
                let size = CGSize(width: cgImage.width, height: cgImage.height)
                UIGraphicsBeginImageContext(size)
                let context = UIGraphicsGetCurrentContext()
                context?.setStrokeColor(UIColor.red.cgColor)
                context?.translateBy(x: 0, y: CGFloat(size.height))
                context?.scaleBy(x: 1, y: -1)
                context?.draw(cgImage, in: CGRect(origin: .zero, size: size))
                UIColor.red.setFill()
                context?.stroke(faceFeature.bounds, width: 0.5)
                let drawnImage = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                f(CIImage(image: drawnImage!)!)
            #else
                let image = NSImage(cgImage: cgImage, size: inputImage.extent.size)
                image.lockFocus()
                let bezierPath = NSBezierPath()
                let rect = NSRect(origin: faceFeature.bounds.origin, size: faceFeature.bounds.size)
                bezierPath.appendRect(rect)
                bezierPath.stroke()
                image.unlockFocus()
                f(CIImage(image: image)!)
            #endif

        }

        // step 3 截图 将身份证数字区域截出来
        // 这里的比例系数实根据身份证的比例，计算身份证号码所在位置
        let fb = faceFeature.bounds
        let y = croppedSize.height - (fb.origin.y + fb.size.height + fb.size.height + fb.size.height / 2)
        let rect = CGRect(x: fb.origin.x - 1.8 * fb.size.width,
                          y: y > 0 ? y : 0 ,
                          width: 3.5 * fb.size.width,
                          height: fb.height)
        inputImage = inputImage.cropped(to: rect)
            .transformed(by: CGAffineTransform(translationX: -rect.origin.x, y: -rect.origin.y))

        debugBlock?(inputImage)

        return inputImage
    }
    
    /// 识别图片上的文字区域，分割 去噪 二值化
    ///
    /// - parameter image: 待识别分割的图片
    ///
    /// - returns: 切割文字后的所有文字小图片
    ///
    public static func segment(_ numbersImage: CIImage, debugBlock: ((CIImage) -> ())? = nil) -> [(CIImage, CGRect)] {

        var images = [(CIImage, CGRect)]()
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

                    let rect = CGRect(x: x, y: y, width: width, height: height)
                    // 将文字切割出来 缩放到28X28 去噪 二值化
                    var image = numbersImage.cropped(to: rect)
                        .transformed(by: CGAffineTransform(translationX: -x, y: -y))
                        .applyingFilter("CILanczosScaleTransform",
                                        parameters: [kCIInputScaleKey: 28 / height,
                                                     kCIInputAspectRatioKey: 28 / (width * 28 / height)])

                    image = SmoothThresholdFilter(image, inputEdgeO: 0.15, inputEdge1: 0.9).outputImage ?? image
                    image = AdaptiveThresholdFilter(image).outputImage ?? image
                    images.append((image, rect))
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
