//
//  ScannerViewController.swift
//  ChineseIDCardOCR
//
//  Created by GongXiang on 8/12/16.
//  Copyright © 2016 Kevin.Gong. All rights reserved.
//

import UIKit
import AVFoundation
import GPUImage

struct IDCard {

    let number: String // 身份证号
    let image: UIImage // 身份证截图

//TODO
//添加其他字段的识别

}


class ScannerViewController: UIViewController {

    @IBOutlet weak var focusView: FocusView!
    @IBOutlet weak var maskView: UIView!
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var tipLabel: UILabel!
    @IBOutlet weak var waittingIndicator: UIActivityIndicatorView!

    // default 0.75
    @IBOutlet private weak var focusViewWidthLayoutConstraint: NSLayoutConstraint?

    let captureSession = AVCaptureSession()
    let device = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
    let output = AVCaptureStillImageOutput()

    let ocr = IDCardOCR()

    var observer: AnyObject?
    var repeatTimer: NSTimer?
    var recognizing = false

    var previewLayer: AVCaptureVideoPreviewLayer!

    var didRecognizedHandler: (IDCard -> ())?

    override func viewDidLoad() {
        super.viewDidLoad()

        adjustfocusViewWidth()

        var input: AVCaptureDeviceInput

        do {
            input = try AVCaptureDeviceInput(device: device)
        } catch {
            return
        }

        guard captureSession.canAddInput(input) else { return }
        captureSession.addInput(input)

        guard captureSession.canAddOutput(output) else { return }
        captureSession.addOutput(output)

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
        previewLayer.connection.videoOrientation = .LandscapeRight

        view.layer.insertSublayer(previewLayer, below: maskView.layer)

        focusView.layer.borderColor = UIColor.whiteColor().CGColor
        focusView.layer.borderWidth = 0.5
        focusView.layer.cornerRadius = 4
        focusView.hidden = true

        let image = UIImage(named: "icon_close")?.imageWithRenderingMode(.AlwaysTemplate)
        closeButton.tintColor = UIColor.whiteColor()
        closeButton.setImage(image, forState: .Normal)
        closeButton.hidden = true

        tipLabel.hidden = true

        addNotification()
    }

    deinit {
        removeNotification()
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)

        captureSession.startRunning()
    }

    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)

        captureSession.stopRunning()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.layer.bounds
        if let _ = maskView.layer.mask { refreshMask() }
    }

    @IBAction func touchClose(sender: UIButton) {

        captureSession.stopRunning()
        focusView.stopScaningAnimation()

        dismissViewControllerAnimated(true, completion: nil)
    }

    // MARK: focus view layoutConstraint
    private func adjustfocusViewWidth() {

        let screenWidth = UIApplication.sharedApplication().statusBarOrientation == .LandscapeRight ?
                          UIScreen.mainScreen().bounds.height : UIScreen.mainScreen().bounds.size.width

        var multiplier: CGFloat = 0.75

        switch screenWidth {
        case 320:
            multiplier = 0.75
        case 375:
            multiplier = 0.65
        default:
            multiplier = 0.5
        }

        if let c = focusViewWidthLayoutConstraint {
            view.removeConstraint(c)
            focusView.removeConstraint(c)
        }

        let layout = NSLayoutConstraint(item: focusView, attribute: .Width, relatedBy: .Equal, toItem: view, attribute: .Width, multiplier: multiplier, constant: 0.0)
        view.addConstraint(layout)
        focusViewWidthLayoutConstraint = layout

        focusView.setNeedsUpdateConstraints()
    }

    // MARK: Notification
    private func addNotification() {

        observer = NSNotificationCenter.defaultCenter().addObserverForName(AVCaptureSessionDidStartRunningNotification, object: nil, queue: nil) { [weak self] _ in
            guard let sSelf = self else { return }
            sSelf.refreshMask()

            // 开始准备获取图片
            sSelf.repeatTimer = NSTimer.schedule(repeatInterval: 1) { [weak sSelf] in
                sSelf?.captureImage($0)
            }

            //
            sSelf.focusView.hidden = false
            sSelf.focusView.startScaningAnimation()

            //
            sSelf.closeButton.hidden = false

            //
            sSelf.tipLabel.hidden = false

            //
            sSelf.waittingIndicator.stopAnimating()
        }
    }

    private func refreshMask() {

        let path = UIBezierPath(rect: view.bounds)
        let focus = UIBezierPath(roundedRect: focusView.frame, cornerRadius: 4)

        path.appendPath(focus.bezierPathByReversingPath())

        let maskLayer = CAShapeLayer()
        maskLayer.path = path.CGPath

        maskView.layer.mask = maskLayer
    }

    private func removeNotification() {

        guard let o = observer else { return }
        
        NSNotificationCenter.defaultCenter().removeObserver(o)
    }

    private func captureImage(timer: NSTimer) {

        // the camera's focus is stable.
        guard !device.adjustingFocus else { return }
        guard !recognizing else { return }

        recognizing = true

        // 获取图片
        let settings = AVCaptureManualExposureBracketedStillImageSettings.manualExposureSettingsWithExposureDuration(device.exposureDuration, ISO: device.ISO)
        let stillImageConnection = output.connectionWithMediaType(AVMediaTypeVideo)
            stillImageConnection.videoOrientation = .LandscapeRight

        output.captureStillImageBracketAsynchronouslyFromConnection(stillImageConnection, withSettingsArray: [settings], completionHandler: { (buffer, settings, error) in

            guard buffer != nil else {
                self.recognizing = false
                return
            }

            let imgData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(buffer)
            if let image = UIImage(data: imgData) {

                let interestRect = self.previewLayer.metadataOutputRectOfInterestForRect(self.focusView.frame)

                let rect = CGRect(x: interestRect.origin.x * image.size.width,
                    y: interestRect.origin.y * image.size.height,
                    width: interestRect.size.width * image.size.width,
                    height: interestRect.size.height * image.size.height)

                let croppedImage = image.crop(rect) // 身份证完成的图片

                self.ocr.recognize(croppedImage) {
                    if $0.lengthOfBytesUsingEncoding(NSUTF8StringEncoding) == 18 {
                        let number = $0
                        dispatch_async(dispatch_get_main_queue()) {
                            self.didRecognizedHandler?(IDCard(number: number, image: croppedImage))
                        }
                    }
                    self.recognizing = false
                }
            }
        })
    }

    // MARK: override supper
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return .LightContent
    }
    
    override func preferredInterfaceOrientationForPresentation() -> UIInterfaceOrientation {
        return .LandscapeRight
    }
    
    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        return .Landscape
    }
    
    override func shouldAutorotate() -> Bool {
        return false
    }
}
