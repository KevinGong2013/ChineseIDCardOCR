//
//  IDCardOCR.swift
//  ChineseIDCardOCR
//
//  Created by GongXiang on 8/12/16.
//  Copyright © 2016 Kevin.Gong. All rights reserved.
//

import UIKit
import GPUImage

internal var recognizableCharacters = "X0123456789"

///The FFNN network used for OCR
internal var globalNetwork: FFNN = {
    if let url = NSBundle(forClass: IDCardOCR.self).URLForResource("OCR-Network", withExtension: nil) {
        if let f = FFNN.fromFile(url) {
            return f
        }
    }
    return FFNN(inputs: 321, hidden: 100, outputs: recognizableCharacters.characters.count, learningRate: 0.7, momentum: 0.4, weights: nil, activationFunction: .Sigmoid, errorFunction: .CrossEntropy(average: false))
}()

class IDCardOCR {

    typealias CompletionHandler = (String) -> ()

    private var network = globalNetwork

    private lazy var context: CIContext = {
        return CIContext(options: nil)
    }()

    ///Radius in x axis for merging blobs
    var xMergeRadius = CGFloat(1)
    ///Radius in y axis for merging blobs
    var yMergeRadius = CGFloat(3)

    ///Confidence must be bigger than the threshold
    var confidenceThreshold:Float = 0.1

    init(){}

    init(image: UIImage, _ handler: CompletionHandler) {
        recognize(image, completionHandler: handler)
    }

    func recognize(image: UIImage, completionHandler: CompletionHandler) {
        
        func indexToCharacter(index: Int) -> Character {
            return Array(recognizableCharacters.characters)[index]
        }

        dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0)) {

            let ciImage = CIImage(image: image)!

            let detector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: nil)

            let features = detector.featuresInImage(ciImage)

            // 检测不到身份证上的头像
            guard let faceFeature = features.first as? CIFaceFeature else {
                completionHandler("")
                return
            }

            // 头像不完整
            guard faceFeature.hasLeftEyePosition && faceFeature.hasRightEyePosition && faceFeature.hasMouthPosition else {
                completionHandler("")
                return
            }

            // 头像不正确
            guard !faceFeature.leftEyeClosed && !faceFeature.rightEyeClosed else {
                completionHandler("")
                return
            }

            let size = image.size
            let bounds = faceFeature.bounds

            // 这里的比例系数实根据身份证的比例，计算身份证号码所在位置
            let w = bounds.width * 3.1
            let x = bounds.width * 1.5
            let y = bounds.origin.y + bounds.height
            let h = size.height - y

            let result = image.crop(CGRect(x: x, y: y, width: w, height: h)) // 只有身份证号码

            let processedImage = self.preprocessImage(result) // 去除背景和一些干扰元素

            let blobs = self.extractBlobs(processedImage)
            var recognizedString = ""

            for blob in blobs {

                do {

                    let blobData = self.convertImageToFloatArray(blob.0)
                    let networkResults = try self.network.update(inputs: blobData)

                    guard networkResults.maxElement() > self.confidenceThreshold else { break }

                    for (idx, _) in networkResults.enumerate().sort({ $0.0.element > $0.1.element}) {

                        let character = indexToCharacter(idx)

                        if character == Character("X") && recognizedString.lengthOfBytesUsingEncoding(NSUTF8StringEncoding) != 17 {
                            continue
                        }
                        recognizedString.append(character)
                        break
                    }
                    
                } catch {
                    debugPrint("[Error] ffnn network update error")
                }
            }
            
            completionHandler(recognizedString)
        }
    }

    deinit {
        debugPrint("IDCardOCR deinit")
    }

    func preprocessImage(image: UIImage) -> UIImage {

        func getDodgeBlendImage(inputImage: UIImage) -> UIImage {

            let image  = GPUImagePicture(image: inputImage)
            let image2 = GPUImagePicture(image: inputImage)

            //First image
            let grayFilter = GPUImageGrayscaleFilter()
            let invertFilter = GPUImageColorInvertFilter()
            let blurFilter = GPUImageBoxBlurFilter()
            let opacityFilter = GPUImageOpacityFilter()

            blurFilter.blurRadiusInPixels = 9
            opacityFilter.opacity = 0.93

            image.addTarget(grayFilter)
            grayFilter.addTarget(invertFilter)
            invertFilter.addTarget(blurFilter)
            blurFilter.addTarget(opacityFilter)

            opacityFilter.useNextFrameForImageCapture()

            //Second image

            let grayFilter2 = GPUImageGrayscaleFilter()

            image2.addTarget(grayFilter2)

            grayFilter2.useNextFrameForImageCapture()

            //Blend

            let dodgeBlendFilter = GPUImageColorDodgeBlendFilter()

            grayFilter2.addTarget(dodgeBlendFilter)
            image2.processImage()

            opacityFilter.addTarget(dodgeBlendFilter)

            dodgeBlendFilter.useNextFrameForImageCapture()
            image.processImage()

            var processedImage = dodgeBlendFilter.imageFromCurrentFramebufferWithOrientation(UIImageOrientation.Up)

            while processedImage?.size == CGSize.zero || processedImage == nil {
                dodgeBlendFilter.useNextFrameForImageCapture()
                image.processImage()
                processedImage = dodgeBlendFilter.imageFromCurrentFramebufferWithOrientation(.Up)
            }

            return processedImage!
        }

        let dodgeBlendImage = getDodgeBlendImage(image)
        let picture = GPUImagePicture(image: dodgeBlendImage)

        let medianFilter = GPUImageMedianFilter()
        let openingFilter = GPUImageOpeningFilter()
        let biliteralFilter = GPUImageBilateralFilter()
        let firstBrightnessFilter = GPUImageBrightnessFilter()
        let contrastFilter = GPUImageContrastFilter()
        let secondBrightnessFilter = GPUImageBrightnessFilter()
        let thresholdFilter = GPUImageLuminanceThresholdFilter()

        biliteralFilter.texelSpacingMultiplier = 0.8
        biliteralFilter.distanceNormalizationFactor = 1.6
        firstBrightnessFilter.brightness = -0.28
        contrastFilter.contrast = 2.35
        secondBrightnessFilter.brightness = -0.08
        biliteralFilter.texelSpacingMultiplier = 0.8
        biliteralFilter.distanceNormalizationFactor = 1.6
        thresholdFilter.threshold = 0.7

        picture.addTarget(medianFilter)
        medianFilter.addTarget(openingFilter)
        openingFilter.addTarget(biliteralFilter)
        biliteralFilter.addTarget(firstBrightnessFilter)
        firstBrightnessFilter.addTarget(contrastFilter)
        contrastFilter.addTarget(secondBrightnessFilter)
        secondBrightnessFilter.addTarget(thresholdFilter)

        thresholdFilter.useNextFrameForImageCapture()
        picture.processImage()

        var processedImage = thresholdFilter.imageFromCurrentFramebufferWithOrientation(UIImageOrientation.Up)

        while processedImage == nil || processedImage?.size == CGSize.zero {
            thresholdFilter.useNextFrameForImageCapture()
            picture.processImage()
            processedImage = thresholdFilter.imageFromCurrentFramebufferWithOrientation(.Up)
        }
        
        return processedImage!
    }

    /**

     Extracts the characters using [Connected-component labeling](https://en.wikipedia.org/wiki/Connected-component_labeling).

     - Parameter image: The image which will be used for the connected-component labeling. If you pass in nil, the `SwiftOCR().image` will be used.
     - Returns:         An array containing the extracted and cropped Blobs and their bounding box.

     */
    internal func extractBlobs(image: UIImage) -> [(UIImage, CGRect)] {
        //data <- bitmapData
        let cgImage = image.CGImage
        let pixelData = CGDataProviderCopyData(CGImageGetDataProvider(cgImage))
        let bitmapData = CFDataGetBytePtr(pixelData)
        let numberOfComponents = CGImageGetBitsPerPixel(cgImage) / CGImageGetBitsPerComponent(cgImage)
        let bytesPerRow = CGImageGetBytesPerRow(cgImage)
        let imageHeight = CGImageGetHeight(cgImage)
        let imageWidth = bytesPerRow / numberOfComponents

        var data = [[UInt16]](count: Int(imageHeight), repeatedValue: [UInt16](count: Int(imageWidth), repeatedValue: 0))

        let yBitmapDataIndexStride = Array(0.stride(to: imageHeight*bytesPerRow, by: bytesPerRow)).enumerate()
        let xBitmapDataIndexStride = Array(0.stride(to: imageWidth*numberOfComponents, by: numberOfComponents)).enumerate()

        for (y, yBitmapDataIndex) in yBitmapDataIndexStride {
            for (x, xBitmapDataIndex) in xBitmapDataIndexStride {
                let bitmapDataIndex = yBitmapDataIndex + xBitmapDataIndex
                data[y][x] = bitmapData[bitmapDataIndex] < 127 ? 0 : 255
            }
        }

        //MARK: First Pass
        var currentLabel: UInt16 = 0 {
            didSet {
                if currentLabel == 255 { currentLabel = 256 }
            }
        }

        var labelsUnion = UnionFind<UInt16>()

        // maybe use switch
        for y in 0..<Int(imageHeight) {
            for x in 0..<Int(imageWidth) {

                if data[y][x] == 0 { //Is Black
                    if x == 0 { //Left no pixel
                        if y == 0 { //Top no pixel
                            currentLabel += 1
                            labelsUnion.addSetWith(currentLabel)
                            data[y][x] = currentLabel
                        } else if y > 0 { //Top pixel
                            if data[y - 1][x] != 255 { //Top Label
                                data[y][x] = data[y - 1][x]
                            } else { //Top no Label
                                currentLabel += 1
                                labelsUnion.addSetWith(currentLabel)
                                data[y][x] = currentLabel
                            }
                        }
                    } else { //Left pixel
                        if y == 0 { //Top no pixel
                            if data[y][x - 1] != 255 { //Left Label
                                data[y][x] = data[y][x - 1]
                            } else { //Left no Label
                                currentLabel += 1
                                labelsUnion.addSetWith(currentLabel)
                                data[y][x] = currentLabel
                            }
                        } else if y > 0 { //Top pixel
                            if data[y][x - 1] != 255 { //Left Label
                                if data[y - 1][x] != 255 { //Top Label

                                    if data[y - 1][x] != data[y][x - 1] {
                                        labelsUnion.unionSetsContaining(data[y - 1][x], and: data[y][x - 1])
                                    }

                                    data[y][x] = data[y - 1][x]
                                } else { //Top no Label
                                    data[y][x] = data[y][x - 1]
                                }
                            } else { //Left no Label
                                if data[y - 1][x] != 255 { //Top Label
                                    data[y][x] = data[y - 1][x]
                                } else { //Top no Label
                                    currentLabel += 1
                                    labelsUnion.addSetWith(currentLabel)
                                    data[y][x] = currentLabel
                                }
                            }
                        }
                    }
                }

            }
        }


        //MARK: Second Pass
        let parentArray = Array(Set(labelsUnion.parent))

        var labelUnionSetOfXArray = Dictionary<UInt16, Int>()

        for label in 0...currentLabel {
            if label != 255 {
                labelUnionSetOfXArray[label] = parentArray.indexOf(labelsUnion.setOf(label) ?? 255)
            }
        }

        for y in 0..<Int(imageHeight) {
            for x in 0..<Int(imageWidth) {

                let luminosity = data[y][x]

                if luminosity != 255 {
                    data[y][x] = UInt16(labelUnionSetOfXArray[luminosity] ?? 255)
                }

            }
        }

        //MARK: MinX, MaxX, MinY, MaxY

        var minMaxXYLabelDict = Dictionary<UInt16, (minX: Int, maxX: Int, minY: Int, maxY: Int)>()

        for label in 0..<parentArray.count {
            minMaxXYLabelDict[UInt16(label)] = (minX: Int(imageWidth), maxX: 0, minY: Int(imageHeight), maxY: 0)
        }

        for y in 0..<Int(imageHeight) {
            for x in 0..<Int(imageWidth) {

                let luminosity = data[y][x]

                if luminosity != 255 {

                    var value = minMaxXYLabelDict[luminosity]!

                    value.minX = min(value.minX, x)
                    value.maxX = max(value.maxX, x)
                    value.minY = min(value.minY, y)
                    value.maxY = max(value.maxY, y)

                    minMaxXYLabelDict[luminosity] = value
                }
            }
        }

        //MARK: Merge labels

        var mergeLabelRects = [CGRect]()

        for label in minMaxXYLabelDict.keys {
            let value = minMaxXYLabelDict[label]!

            let minX = value.minX
            let maxX = value.maxX
            let minY = value.minY
            let maxY = value.maxY

            //Filter blobs

            let minMaxCorrect = (minX < maxX && minY < maxY)

            let notToTall    = Double(maxY - minY) < Double(imageHeight) * 0.75
            let notToWide    = Double(maxX - minX) < Double(imageWidth ) * 0.25
            let notToShort   = Double(maxY - minY) > Double(imageHeight) * 0.08
            let notToThin    = Double(maxX - minX) > Double(imageWidth ) * 0.01

            let notToSmall   = (maxX - minX)*(maxY - minY) > 100
            let positionIsOK = minY != 0 && minX != 0 && maxY != Int(imageHeight - 1) && maxX != Int(imageWidth - 1)
            let aspectRatio  = Double(maxX - minX) / Double(maxY - minY)

            if minMaxCorrect && notToTall && notToWide && notToShort && notToThin && notToSmall && positionIsOK &&
                aspectRatio < 1 {
                let labelRect = CGRectMake(CGFloat(CGFloat(minX) - xMergeRadius), CGFloat(CGFloat(minY) - yMergeRadius), CGFloat(CGFloat(maxX - minX) + 2*xMergeRadius + 1), CGFloat(CGFloat(maxY - minY) + 2*yMergeRadius + 1))
                mergeLabelRects.append(labelRect)
            } else if minMaxCorrect && notToTall && notToShort && notToThin && notToSmall && positionIsOK && aspectRatio <= 2.5 && aspectRatio >= 1 {

                // MARK: Connected components: Find thinnest part of connected components

                guard minX + 2 < maxX - 2 else {
                    continue
                }

                let transposedData = Array(data[minY...maxY].map({return $0[(minX + 2)...(maxX - 2)]})).transpose() // [y][x] -> [x][y]
                let reducedMaxIndexArray = transposedData.map({return $0.reduce(0, combine: {return UInt32($0.0) + UInt32($0.1)})}) //Covert to UInt32 to prevent overflow
                let maxIndex = reducedMaxIndexArray.enumerate().maxElement({return $0.1 < $1.1})?.0 ?? 0


                let cutXPosition   = minX + 2 + maxIndex

                let firstLabelRect = CGRectMake(CGFloat(CGFloat(minX) - xMergeRadius), CGFloat(CGFloat(minY) - yMergeRadius), CGFloat(CGFloat(maxIndex) + 2 * xMergeRadius), CGFloat(CGFloat(maxY - minY) + 2 * yMergeRadius))

                let secondLabelRect = CGRectMake(CGFloat(CGFloat(cutXPosition) - xMergeRadius), CGFloat(CGFloat(minY) - yMergeRadius), CGFloat(CGFloat(Int(maxX - minX) - maxIndex) + 2 * xMergeRadius), CGFloat(CGFloat(maxY - minY) + 2 * yMergeRadius))

                if firstLabelRect.width >= 5 + (2 * xMergeRadius) && secondLabelRect.width >= 5 + (2 * xMergeRadius) {
                    mergeLabelRects.append(firstLabelRect)
                    mergeLabelRects.append(secondLabelRect)
                } else {
                    let labelRect = CGRectMake(CGFloat(CGFloat(minX) - xMergeRadius), CGFloat(CGFloat(minY) - yMergeRadius), CGFloat(CGFloat(maxX - minX) + 2*xMergeRadius + 1), CGFloat(CGFloat(maxY - minY) + 2*yMergeRadius + 1))
                    mergeLabelRects.append(labelRect)
                }
            }
        }

        //Merge rects

        var filteredMergeLabelRects = [CGRect]()

        for rect in mergeLabelRects {

            var intersectCount = 0

            for (filteredRectIndex, filteredRect) in filteredMergeLabelRects.enumerate() {
                if rect.intersects(filteredRect) {
                    intersectCount += 1
                    filteredMergeLabelRects[filteredRectIndex] = filteredRect.union(rect)
                }
            }

            if intersectCount == 0 {
                filteredMergeLabelRects.append(rect)
            }
        }

        mergeLabelRects = filteredMergeLabelRects

        //Filter rects: - Not to small
        let insetMergeLabelRects = mergeLabelRects.map({return $0.insetBy(dx: CGFloat(xMergeRadius), dy: CGFloat(yMergeRadius))})
        filteredMergeLabelRects.removeAll()

        for rect in insetMergeLabelRects {
            let widthOK  = rect.size.width  >= 7
            let heightOK = rect.size.height >= 14

            if widthOK && heightOK {
                filteredMergeLabelRects.append(rect)
            }
        }

        mergeLabelRects = filteredMergeLabelRects

        var outputImages = [(UIImage, CGRect)]()

        //MARK: Crop image to blob
        for rect in mergeLabelRects {

            if let croppedCGImage = CGImageCreateWithImageInRect(cgImage, rect) {

                let croppedImage = UIImage(CGImage: croppedCGImage)

                outputImages.append((croppedImage, rect))
            }
        }

        outputImages.sortInPlace { return $0.0.1.origin.x < $0.1.1.origin.x }

        return outputImages
    }

    /**

     Takes an array of images and then resized them to **16x20px**. This is the standard size for the input for the neural network.

     - Parameter blobImages: The array of images that should get resized.
     - Returns:              An array containing the resized images.

     */
    internal func resizeBlobs(blobImages: [UIImage]) -> [UIImage] {

        var resizedBlobs = [UIImage]()

        for blobImage in blobImages {
            let cropSize = CGSizeMake(16, 20)

            //Downscale
            let cgImage   = blobImage.CGImage

            let width = cropSize.width
            let height = cropSize.height
            let bitsPerComponent = 8
            let bytesPerRow = 0
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let bitmapInfo = CGImageAlphaInfo.NoneSkipLast.rawValue

            let context = CGBitmapContextCreate(nil, Int(width), Int(height), bitsPerComponent, bytesPerRow, colorSpace, bitmapInfo)

            CGContextSetInterpolationQuality(context, CGInterpolationQuality.None)

            CGContextDrawImage(context, CGRectMake(0, 0, cropSize.width, cropSize.height), cgImage)

            let resizedCGImage = CGImageCreateWithImageInRect(CGBitmapContextCreateImage(context), CGRectMake(0, 0, cropSize.width, cropSize.height))!

            let resizedOCRImage = UIImage(CGImage: resizedCGImage)

            resizedBlobs.append(resizedOCRImage)
        }

        return resizedBlobs
    }

    /**

     Takes an image and converts it to an array of floats. The array gets generated by taking the pixel-data of the red channel and then converting it into floats. This array can be used as input for the neural network.

     - Parameter image:  The image which should get converted to the float array.
     - Parameter resize: If you set this to true, the image firsts gets resized. The default value is `true`.
     - Returns:          The array containing the pixel-data of the red channel.

     */
    internal func convertImageToFloatArray(image: UIImage, resize: Bool = true) -> [Float] {
        
        let resizedBlob: UIImage = {
            if resize {
                return resizeBlobs([image]).first!
            } else {
                return image
            }
        }()
        
        let pixelData  = CGDataProviderCopyData(CGImageGetDataProvider(resizedBlob.CGImage))
        let bitmapData: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
        let cgImage    = resizedBlob.CGImage
        
        let numberOfComponents = CGImageGetBitsPerPixel(cgImage) / CGImageGetBitsPerComponent(cgImage)
        
        var imageData = [Float]()
        
        let height = Int(resizedBlob.size.height)
        let width  = Int(resizedBlob.size.width)
        
        for yPixelInfo in 0.stride(to: height*width*numberOfComponents, by: width*numberOfComponents) {
            for xPixelInfo in 0.stride(to: width*numberOfComponents, by: numberOfComponents) {
                let pixelInfo: Int = yPixelInfo + xPixelInfo
                imageData.append(bitmapData[pixelInfo] < 127 ? 0 : 1)
            }
        }
        
        let aspectRatio = Float(image.size.width / image.size.height)
        
        imageData.append(aspectRatio)
        
        return imageData
    }
}
