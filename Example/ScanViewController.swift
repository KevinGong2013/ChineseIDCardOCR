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
    }

    func handleRectangleRequest(request: VNRequest, error: Error?) {
//        guard let observations = request.results as? [VNRectangleObservation] else { return }

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

    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        var requestOptions = [VNImageOption: Any]()

        if let camData = CMGetAttachment(sampleBuffer, kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, nil) {
            requestOptions = [.cameraIntrinsics:camData]
        }

        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: CGImagePropertyOrientation.up, options: requestOptions)

        do {
            try imageRequestHandler.perform([rectangleRequest])
        } catch {
            fatalError(error.localizedDescription)
        }
    }
}
