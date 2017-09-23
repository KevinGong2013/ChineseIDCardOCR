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

    var images = [UIImage?]()

    lazy var engine = KGEngine.default

    override func viewDidLoad() {
        super.viewDidLoad()

        engine.debugBlock = { image in
            self.images.append(UIImage(ciImage: image))
        }

        engine.classify(IDCard: #imageLiteral(resourceName: "demo1")) { (idcard, error) in
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

extension ViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return images.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath) as! PreviewImageCollectionViewCell

        cell.previewImageView.image = images[indexPath.item]
        cell.layer.borderColor = UIColor.red.cgColor
        cell.layer.borderWidth = 0.5
        return cell
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return images.count
    }
}

extension ViewController: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {

        return images[indexPath.item]?.size ?? CGSize(width: 44, height: 44)
    }

}

class PreviewImageCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var previewImageView: UIImageView!
    
}



