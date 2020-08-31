//
//  ALConfirmViewController.swift
//  ALCameraViewController
//
//  Created by Alex Littlejohn on 2015/06/30.
//  Copyright (c) 2015 zero. All rights reserved.
//

import UIKit
import Photos

public class ConfirmViewController: UIViewController {
	
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var bottomInstrumentsView: UIView!
    @IBOutlet weak var confirmButton: UIButton!
    @IBOutlet weak var scanningProgressBar: UIProgressView!
    @IBOutlet weak var bottomScanningView: UIView!
    @IBOutlet weak var scanningLabel: UILabel!
    @IBOutlet weak var retakeButton: UIButton! {
        didSet {
            retakeButton.setTitle("RETAKE".localized(), for: .normal)
            retakeButton.clipsToBounds = true
            let blur = UIVisualEffectView(effect: UIBlurEffect(style: .light))
            blur.frame = retakeButton.bounds
            blur.isUserInteractionEnabled = false
            retakeButton.insertSubview(blur, at: 0)
        }
    }
    
    private let detectionAreaView = DetectionAreaView()
    private var spinner: UIActivityIndicatorView? = nil
    private var isFirstLayout = true
    
	public var onComplete: CameraViewCompletion?
    public var objectRecognizer: ObjectRecognizer?

	let asset: PHAsset?
	let image: UIImage?
    let detectionAreaTitle: String?
	
    public init(image: UIImage, title: String) {
		self.asset = nil
		self.image = image
        self.detectionAreaTitle = title
		super.init(nibName: "ConfirmViewController", bundle: CameraGlobals.shared.bundle)
	}
	
	public init(asset: PHAsset, title: String) {
		self.asset = asset
		self.image = nil
        self.detectionAreaTitle = title
		super.init(nibName: "ConfirmViewController", bundle: CameraGlobals.shared.bundle)
	}
	
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
	}
	
	public override var prefersStatusBarHidden: Bool {
		return true
	}
	
	public override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
		return UIStatusBarAnimation.slide
	}
	
	public override func viewDidLoad() {
		super.viewDidLoad()
        
        scrollView.delegate = self
        scrollView.minimumZoomScale = image?.scale ?? 1
        scrollView.maximumZoomScale = 3
        
        scanningLabel.text = "Scanning".localized()
		view.backgroundColor = UIColor.black
		showSpinner()
		disable()
        setupDetectionAreaView()
        setupProgressBar()
        
		if let asset = asset {
			_ = SingleImageFetcher()
				.setAsset(asset)
				.setTargetSize(largestPhotoSize())
				.onSuccess { [weak self] image in
					self?.configureWithImage(image)
					self?.hideSpinner()
					self?.enable()
				}
				.onFailure { [weak self] error in
					self?.hideSpinner()
				}
				.fetch()
		} else if let image = image {
			configureWithImage(image)
			hideSpinner()
			enable()
		}
	}
    
    public override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        retakeButton.layer.cornerRadius = retakeButton.bounds.height / 2
        confirmButton.layer.cornerRadius = confirmButton.bounds.height / 2
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if isFirstLayout {
            isFirstLayout = false
            spinner?.center = view.center
        }
    }
    
    private func setupDetectionAreaView() {
        detectionAreaView.setTitle(detectionAreaTitle ?? "", font: UIFont.montserratSemiBold(size: 17))
        detectionAreaView.isUserInteractionEnabled = false
        view.insertSubview(detectionAreaView, aboveSubview: scrollView)
        detectionAreaView.pinToView(scrollView)
    }
    
    private func setupProgressBar() {
        let cornerRadius: CGFloat = 4.0
        scanningProgressBar.layer.masksToBounds = true
        scanningProgressBar.layer.cornerRadius = cornerRadius
        // Set the rounded edge for the inner bar
        scanningProgressBar.layer.sublayers?[1].cornerRadius = cornerRadius
        scanningProgressBar.layer.sublayers?[1].masksToBounds = true
    }
	
	private func configureWithImage(_ image: UIImage) {
		buttonActions()
		imageView.image = image
	}
    
    private func presentRetakeAlert(message: String) {
        let alertController = AlertViewController()
        let cancelAction: VoidClosure = { [weak self] in self?.cancel() }
        alertController.setup(with: .init(title: "Please retake a photo".localized(),
                                          message: message,
                                          buttons: [.init(title: "RETAKE".localized(), isFocused: true, action: cancelAction)]))
        present(alertController, animated: true)
    }

    private func buttonActions() {
        confirmButton.action = { [weak self] in
            guard let self = self, let image = self.imageView.image else { return }
            
            let croppedImage = self.crop(image, targetAreaFrame: self.detectionAreaView.areaFrame, scrollView: self.scrollView) ?? image
            
            guard let recognizer = self.objectRecognizer else {
                self.startScanning(completion: { self.confirmPhoto(croppedImage) })
                return
            }

            recognizer.recognize(image: croppedImage, completion: { result in
                switch result {
                case .success:
                    self.startScanning(completion: { self.confirmPhoto(croppedImage) })
                case .failure(let error):
                    self.presentRetakeAlert(message: error.localizedDescription)
                }
            })
        }
		retakeButton.action = { [weak self] in self?.cancel() }
	}
	
	internal func cancel() {
		onComplete?(nil, nil)
	}
    
    func startScanning(completion: VoidClosure?) {
        let detectionAreaFrame = detectionAreaView.areaFrame
        let scannerContainerView = UIView()
        let scannerBarImageView = UIImageView()
        let gridImageView = UIImageView()
        
        scannerContainerView.clipsToBounds = true
        scannerContainerView.layer.cornerRadius = detectionAreaView.areaShapecornerRadius
        scannerBarImageView.contentMode = .scaleAspectFill
        scannerBarImageView.image = Image.Camera.scannerBar
        gridImageView.image = Image.Camera.grid
        
        view.addSubview(scannerContainerView)
        scannerContainerView.addSubview(gridImageView)
        scannerContainerView.addSubview(scannerBarImageView)
        
        scannerContainerView.frame = detectionAreaFrame
        gridImageView.frame = scannerContainerView.bounds
        scannerBarImageView.frame = scannerContainerView.bounds
        scannerBarImageView.frame.origin.y = scannerContainerView.bounds.origin.y - 40
        
        let numberOfScans = 5
        let durationPerScan: TimeInterval = 1.5
        let scanningDuration = Double(numberOfScans) * durationPerScan
        let relativeDuration: TimeInterval = durationPerScan / scanningDuration
        let hiddenDuration: TimeInterval = 0.3
        
        bottomInstrumentsView.isHiddenWithAnimation(true, duration: hiddenDuration)
        bottomScanningView.isHiddenWithAnimation(false, duration: hiddenDuration)
        UIView.animateKeyframes(withDuration: scanningDuration, delay: 0, options: [], animations: {
            
            UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 1) {
                self.scanningProgressBar.setProgress(1.0, animated: true)
            }
            
            var shouldScanFromBottomToTop = false
            for index in 0..<numberOfScans {
                UIView.addKeyframe(withRelativeStartTime: relativeDuration * Double(index), relativeDuration: relativeDuration) {
                    scannerBarImageView.transform = shouldScanFromBottomToTop ? .identity : CGAffineTransform(translationX: 0, y: scannerContainerView.bounds.height)
                }
                shouldScanFromBottomToTop.toggle()
            }
            
        }, completion: { _ in
            self.bottomInstrumentsView.isHiddenWithAnimation(false, duration: hiddenDuration)
            self.bottomScanningView.isHiddenWithAnimation(true, duration: hiddenDuration)
            scannerContainerView.isHiddenWithAnimation(true, duration: hiddenDuration, completion: {
                scannerContainerView.removeFromSuperview()
                completion?()
            })
        })
    }
	
    internal func confirmPhoto(_ image: UIImage) {
		disable()
		imageView.isHidden = true
		showSpinner()
		
		if let asset = asset {
			var fetcher = SingleImageFetcher()
				.onSuccess { [weak self] _ in
					self?.onComplete?(image, self?.asset)
					self?.hideSpinner()
					self?.enable()
				}
				.onFailure { [weak self] error in
					self?.hideSpinner()
					self?.showNoImageScreen(error)
				}
				.setAsset(asset)
			
			fetcher = fetcher.fetch()
        } else {
			onComplete?(image, nil)
			hideSpinner()
			enable()
		}
	}
	
	func showSpinner() {
		spinner = UIActivityIndicatorView()
        spinner!.style = .white
        spinner!.center = view.center
		spinner!.startAnimating()
		
		view.addSubview(spinner!)
        view.bringSubviewToFront(spinner!)
    }
	
	func hideSpinner() {
		spinner?.stopAnimating()
		spinner?.removeFromSuperview()
	}
	
	func disable() {
		confirmButton.isEnabled = false
	}
	
	func enable() {
		confirmButton.isEnabled = true
	}
	
	func showNoImageScreen(_ error: NSError) {
		let permissionsView = PermissionsView(frame: view.bounds)
		
		let desc = localizedString("error.cant-fetch-photo.description")
		
        permissionsView.configureInView(view, title: error.localizedDescription, description: desc, completion: { [weak self] in self?.cancel() })
    }
    
    private func crop(_ image: UIImage, targetAreaFrame: CGRect, scrollView: UIScrollView) -> UIImage? {
        var ratio: CGFloat = 0
        var imageHeight: CGFloat = 0
        
        if image.size.width > image.size.height {
            ratio = image.size.height / image.size.width
            imageHeight = imageView.frame.width * ratio
        } else {
            ratio = image.size.width / image.size.height
            imageHeight = imageView.frame.width / ratio
        }
        
        let imageSize = CGSize(width: imageView.frame.width, height: imageHeight)
        let imageOrigin = CGPoint(x: imageView.center.x - imageSize.width / 2, y: imageView.center.y - imageSize.height / 2)
        
        let targetAreaOriginInView = CGPoint(x: targetAreaFrame.origin.x + scrollView.contentOffset.x, y: targetAreaFrame.origin.y - imageOrigin.y + scrollView.contentOffset.y)
        let targetAreaMaxPointInView = CGPoint(x: targetAreaOriginInView.x + targetAreaFrame.size.width,
                                               y: targetAreaOriginInView.y + targetAreaFrame.size.height)
        let targetAreaOriginInPercentage = CGPoint(x: targetAreaOriginInView.x / imageSize.width,
                                                   y: targetAreaOriginInView.y / imageSize.height)
        let targetAreaMaxPointInPercentage = CGPoint(x: targetAreaMaxPointInView.x / imageSize.width,
                                                     y: targetAreaMaxPointInView.y / imageSize.height)
        
        let targetAreaOriginInImage = CGPoint(x: image.size.width * targetAreaOriginInPercentage.x,
                                              y: image.size.height * targetAreaOriginInPercentage.y)
        let targetAreaMaxPointInImage = CGPoint(x: image.size.width * targetAreaMaxPointInPercentage.x,
                                                y: image.size.height * targetAreaMaxPointInPercentage.y)
        let targetAreaSizeInImage = CGSize(width: targetAreaMaxPointInImage.x - targetAreaOriginInImage.x,
                                           height: targetAreaMaxPointInImage.y - targetAreaOriginInImage.y)
        
        let imageCroppingRect = CGRect(origin: targetAreaOriginInImage, size: targetAreaSizeInImage)
        guard let imageRef = image.cgImage?.cropping(to: imageCroppingRect) else { return nil }
        return UIImage(cgImage: imageRef, scale: image.scale, orientation: image.imageOrientation)
    }
}

// MARK: - UIScrollViewDelegate
extension ConfirmViewController: UIScrollViewDelegate {
    public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    public func scrollViewDidZoom(_ scrollView: UIScrollView) {
        guard let imageView = imageView else { return }

        let boundsSize = scrollView.bounds.size
        var frameToCenter = imageView.frame

        // Center horizontally
        if frameToCenter.size.width < boundsSize.width {
            frameToCenter.origin.x = (boundsSize.width - frameToCenter.size.width) / 2
        } else {
            frameToCenter.origin.x = 0
        }

        // Center vertically
        if frameToCenter.size.height < boundsSize.height {
            frameToCenter.origin.y = (boundsSize.height - frameToCenter.size.height) / 2
        } else {
            frameToCenter.origin.y = 0
        }

        imageView.frame = frameToCenter
    }
}

extension UIImageView {
    var contentClippingRect: CGRect {
        guard let image = image else { return bounds }
        guard contentMode == .scaleAspectFit else { return bounds }
        guard image.size.width > 0 && image.size.height > 0 else { return bounds }

        let scale: CGFloat
        if image.size.width > image.size.height {
            scale = bounds.width / image.size.width
        } else {
            scale = bounds.height / image.size.height
        }

        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let x = (bounds.width - size.width) / 2.0
        let y = (bounds.height - size.height) / 2.0

        return CGRect(x: x, y: y, width: size.width, height: size.height)
    }
}

extension UIImage {
	func crop(rect: CGRect) -> UIImage {

		var rectTransform: CGAffineTransform
		switch imageOrientation {
		case .left:
			rectTransform = CGAffineTransform(rotationAngle: radians(90)).translatedBy(x: 0, y: -size.height)
		case .right:
			rectTransform = CGAffineTransform(rotationAngle: radians(-90)).translatedBy(x: -size.width, y: 0)
		case .down:
			rectTransform = CGAffineTransform(rotationAngle: radians(-180)).translatedBy(x: -size.width, y: -size.height)
		default:
			rectTransform = CGAffineTransform.identity
		}
		
		rectTransform = rectTransform.scaledBy(x: scale, y: scale)
		
		if let cropped = cgImage?.cropping(to: rect.applying(rectTransform)) {
			return UIImage(cgImage: cropped, scale: scale, orientation: imageOrientation).fixOrientation()
		}
		
		return self
	}
	
	func fixOrientation() -> UIImage {
		if imageOrientation == .up {
			return self
		}
		
		UIGraphicsBeginImageContextWithOptions(size, false, scale)
		draw(in: CGRect(origin: .zero, size: size))
		let normalizedImage: UIImage = UIGraphicsGetImageFromCurrentImageContext() ?? self
		UIGraphicsEndImageContext()
		
		return normalizedImage
	}
}
