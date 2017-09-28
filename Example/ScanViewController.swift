//
//  ScanViewController.swift
//  ChineseIDCardOCR
//
//  Created by GongXiang on 9/25/17.
//  Copyright © 2017 Kevin.Gong. All rights reserved.
//

import UIKit
import AVFoundation
import Vision
import QuartzCore
import CoreMedia

class PreviewView: UIView {
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }

    var session: AVCaptureSession? {
        get {
            return videoPreviewLayer.session
        }
        set {
            videoPreviewLayer.session = newValue
        }
    }

    // MARK: UIView

    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
}

class TagLayer: CALayer {

    public convenience init(frame: CGRect) {
        self.init()
        self.frame = frame
        self.backgroundColor = UIColor.red.withAlphaComponent(0.4).cgColor
    }
}

class ScanViewController: UIViewController {

    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var previewView: PreviewView!

    var imageView: AVCaptureVideoPreviewLayer!

    lazy var session = AVCaptureSession()

    lazy var rectangleRequest: VNDetectRectanglesRequest = {
            return VNDetectRectanglesRequest(completionHandler: handleRectangleRequest)
    }()

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startLiveVideo()
    }

    func startLiveVideo() {
        //1
        session.sessionPreset = AVCaptureSession.Preset.photo
        let captureDevice = AVCaptureDevice.default(for: .video)

        //2
        let deviceInput = try! AVCaptureDeviceInput(device: captureDevice!)
        let deviceOutput = AVCaptureVideoDataOutput()
        deviceOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        deviceOutput.setSampleBufferDelegate(self, queue: DispatchQueue.global(qos: DispatchQoS.QoSClass.default))
        session.addInput(deviceInput)
        session.addOutput(deviceOutput)

        session.startRunning()

        previewView.session = session
    }

    func handleRectangleRequest(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNRectangleObservation] else { return }

        DispatchQueue.main.async {
            CATransaction.begin()
            CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
            self.previewView.layer.sublayers?.filter { $0 is TagLayer }.forEach { $0.removeFromSuperlayer() }
            let size = self.previewView.frame.size
            observations.map {
                let rect = CGRect(x: $0.topLeft.x * size.width,
                                  y: (1 - $0.topLeft.y) * size.height,
                                  width: ($0.topRight.x - $0.bottomLeft.x) * size.width,
                                  height: ($0.topLeft.y - $0.bottomLeft.y) * size.height)
                return TagLayer(frame: rect)
                }.forEach(self.previewView.layer.addSublayer)
            CATransaction.commit()
        }
    }

    func handleDetectFaceRequest() {

    }

    @IBAction func touchBack(_ button: UIButton) {
        dismiss(animated: true, completion: nil)
    }

    override var shouldAutorotate: Bool {
        return false
    }
}

extension ScanViewController: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        var requestOptions = [VNImageOption: Any]()

        if let camData = CMGetAttachment(sampleBuffer, kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, nil) {
            requestOptions = [.cameraIntrinsics: camData]
        }

        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: CGImagePropertyOrientation.up, options: requestOptions)

        do {
            try imageRequestHandler.perform([rectangleRequest])
        } catch {
            fatalError(error.localizedDescription)
        }
    }
}
