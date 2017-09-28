//
//  ViewController.swift
//  Example
//
//  Created by GongXiang on 9/22/17.
//  Copyright © 2017 Kevin.Gong. All rights reserved.
//

import UIKit
import CoreImage
import Vision
import ChineseIDCardOCR

class ViewController: UIViewController {

    @IBOutlet weak var collectionView: UICollectionView!

    var images = [CIImage]()

    lazy var context = CIContext(options: [kCIContextUseSoftwareRenderer: false])
    lazy var engine = KGEngine.default

    override func viewDidLoad() {
        super.viewDidLoad()

        let e = collectionView.contentInset
        collectionView.contentInset = UIEdgeInsets(top: e.top, left: e.left,
                                                   bottom: e.bottom + 44, right: e.right)
        engine.debugBlock = { image in
            let size = UIScreen.main.bounds
            if image.extent.width > size.width {
                self.images.append(image.applyingFilter("CILanczosScaleTransform",
                                                       parameters: [kCIInputScaleKey: size.width / image.extent.width]))
            } else {
                self.images.append(image)
            }
        }

        if let image = CIImage(image: #imageLiteral(resourceName: "demo1")) {
            engine.recognize(IDCard: image) { (idcard, error) in
                guard let card = idcard else {
                    debugPrint(error?.localizedDescription ?? "unknow error")
                    return
                }
                debugPrint(card.number)
                DispatchQueue.main.async {
                    self.collectionView.reloadData()
                }
            }
        }
    }

    @IBAction func chooseImage(_ sender: UIBarButtonItem) {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .savedPhotosAlbum
        present(picker, animated: true)
    }

    @IBAction func reload(_ sender: UIBarButtonItem) {
        collectionView.reloadData()
    }
}

extension ViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return images.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath) as! PreviewImageCollectionViewCell

        let ciImgae = images[indexPath.item]
        DispatchQueue.global().async {
            if let cgImage = self.context.createCGImage(ciImgae, from: ciImgae.extent) {
                DispatchQueue.main.async {
                    if cell.previewImageView.image == nil {
                        cell.previewImageView.image = UIImage(cgImage: cgImage)
                    }
                }
            }
        }
        cell.layer.borderColor = UIColor.red.cgColor
        cell.layer.borderWidth = 2
        return cell
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return images.count
    }
}

extension ViewController: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {

        return images[indexPath.item].extent.size
    }

}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        picker.dismiss(animated: true, completion: nil)

        guard let uiImage = info[UIImagePickerControllerOriginalImage] as? UIImage
            else { fatalError("no image from image picker") }

        images.removeAll()
        collectionView.reloadData()

        if let image = CIImage(image: uiImage) {
            engine.recognize(IDCard: image) { idcard, error in
                guard let card = idcard else {
                    debugPrint(error?.localizedDescription ?? "unknow error")
                    return
                }
                debugPrint(card)
                DispatchQueue.main.async {
                    self.collectionView.reloadData()
                }
            }
        }
    }
}


class PreviewImageCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var previewImageView: UIImageView!

    override func prepareForReuse() {
        previewImageView.image = nil
    }
}
