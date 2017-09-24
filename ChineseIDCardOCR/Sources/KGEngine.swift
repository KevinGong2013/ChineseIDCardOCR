//
//  Engine.swift
//  ChineseIDCardOCR
//
//  Created by GongXiang on 9/22/17.
//  Copyright © 2017 Kevin.Gong. All rights reserved.
//

import Vision

public struct IDCard {
    let number: String
}

/// MARK: -

/// User Engine to create a CNN network.
public class KGEngine {

    lazy var model = KGNetCNN() // for signle prediction
//    Creating a CIContext is an expensive operation, so a cached context should always be used for repeated resizing
    lazy var gpuContext = CIContext(options: [kCIContextUseSoftwareRenderer: false])
    
    public var debugBlock: ((CIImage) -> ())?
    public static var `default`: KGEngine { return KGEngine() }

    public init(_ debugBlock: ((CIImage) -> ())? = nil) {
        self.debugBlock = debugBlock
    }

    /// 对单个的包含数字的图片进行分类。
    /// 对一些特殊的图片比如像车牌之类的，可以自己进行预处理，使用本方法进行分类
    ///
    /// - parameter images: 将要识别的单个数字图片数组。 为了提高准确率请确认图片为: 28X28的灰度图
    ///
    /// - returns: 分类结果.
    ///            数字对应的概率. 比如 (1, 0.87)
    public func prediction(_ image: CIImage) -> (String, Double)? {
        guard let cgImage = gpuContext.createCGImage(image, from: image.extent) else {
            fatalError(KGError.invalidImage.localizedDescription)
        }
        guard let pixelBuffer = cgImage.pixelBuffer() else { fatalError("can't get image's pixel buffer") }
        if let f = debugBlock {
            f(CIImage(cvPixelBuffer: pixelBuffer))
        }
        guard let result = try? model.prediction(image: pixelBuffer) else { fatalError("unexpected runtime error") }

        return result.output.sorted { (lh, rh) -> Bool in
            return lh.value > rh.value
        }.first
    }
}

/// MARK: -

public extension KGEngine {

    /// 对完整的身份证照片进行识别
    ///
    /// - parameter image: 身份证照片
    ///
    /// - returns: 身份证号码
    ///
    public func classify(IDCard kgImage: KGImage, completionHandler: @escaping (IDCard?, KGError?) -> ()) {

        guard let ciImage = CIImage(image: kgImage) else {
            completionHandler(nil, .invalidImage)
            return
        }
        debugBlock?(ciImage)
        
        guard let orientation = CGImagePropertyOrientation(rawValue: UInt32(kgImage.imageOrientation.rawValue)) else {
            fatalError("can't get image's orientation.")
        }
        let inputImage = ciImage.oriented(forExifOrientation: Int32(orientation.rawValue))

        let detector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: nil)!

        let features = detector.features(in: inputImage)

        // 检测不到身份证上的照片
        guard let faceFeature = features.first as? CIFaceFeature else {
            completionHandler(nil, .noFaceDetected)
            return
        }

        // 照片不完整
        guard faceFeature.hasLeftEyePosition &&
              faceFeature.hasRightEyePosition &&
              faceFeature.hasMouthPosition &&
              !faceFeature.leftEyeClosed &&
              !faceFeature.rightEyeClosed else {

                completionHandler(nil, .faceInfoIncorrect)
            return
        }

        // 检测身份证的矩形框 step 2
        let rectangleRequest = VNDetectRectanglesRequest { [weak self] (request, err) in
            guard let `self` = self else { return }

            DispatchQueue.global(qos: .userInteractive).async {
                let border = (request.results?.first as? VNRectangleObservation)
                let numberImageArea =  KGPreProcessing.do(inputImage, faceBounds: faceFeature.bounds, border: border, debugBlock: self.debugBlock)

                ///TODO: 身份证号码的字符数组，这里可以利用身份证号码添加一个基本验证
                let numberImages = KGPreProcessing.segment(numberImageArea, debugBlock: self.debugBlock)
                if let result = self.classify(IDCardNumbers: numberImages) {
                    completionHandler(IDCard(number: result.joined(separator: "")), nil)
                } else {
                    completionHandler(nil, .classifyFailed)
                }
            }
        }

        // 检测身份证的矩形框 step 1
        let handler = VNImageRequestHandler(ciImage: inputImage, orientation: orientation)

        DispatchQueue.global(qos: .userInteractive).async {
            do {
                try handler.perform([rectangleRequest])
            } catch {
                completionHandler(nil, .unexpected(error))
            }
        }
    }

    // TODO 根据不同类型（身份证，银行卡...）进行 校验 计算
    func classify(IDCardNumbers images: [CIImage]) -> [String]? {

        return images.flatMap(prediction).map { x in x.0 }
    }
}

