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
	
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var bottomInstrumentsView: UIView!
    @IBOutlet weak var confirmButton: UIButton!
    @IBOutlet weak var retakeButton: UIButton! {
        didSet {
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
	
	public init(image: UIImage) {
		self.asset = nil
		self.image = image
		super.init(nibName: "ConfirmViewController", bundle: CameraGlobals.shared.bundle)
	}
	
	public init(asset: PHAsset) {
		self.asset = asset
		self.image = nil
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
		view.backgroundColor = UIColor.black
		showSpinner()
		disable()
        setupDetectionAreaView()
		
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
        view.insertSubview(detectionAreaView, aboveSubview: imageView)
        detectionAreaView.pinToSuperview()
    }
	
	private func configureWithImage(_ image: UIImage) {
		buttonActions()
		imageView.image = image
	}
    
    private func presentRetakeAlert(message: String) {
        let alertController = AlertViewController()
        alertController.setup(with: .init(title: "Please retake a photo", message: message, buttonTitle: "RETAKE", buttonAction: {
            self.cancel()
        }))
        present(alertController, animated: true)
    }

	private func buttonActions() {
		confirmButton.action = { [weak self] in
            guard let image = self?.imageView.image else { return }
            self?.objectRecognizer?.recognize(image: image, completion: { result in
                switch result {
                case .success:
                    self?.startScanning(completion: {
                        self?.confirmPhoto(image)
                    })
                case .failure(let error):
                    self?.presentRetakeAlert(message: error.localizedDescription)
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
        UIView.animateKeyframes(withDuration: scanningDuration, delay: 0, options: [], animations: {
            var shouldScanFromBottomToTop = false
            for index in 0..<numberOfScans {
                UIView.addKeyframe(withRelativeStartTime: relativeDuration * Double(index), relativeDuration: relativeDuration) {
                    scannerBarImageView.transform = shouldScanFromBottomToTop ? .identity : CGAffineTransform(translationX: 0, y: scannerContainerView.bounds.height)
                }
                shouldScanFromBottomToTop.toggle()
            }
        }, completion: { _ in
            self.bottomInstrumentsView.isHiddenWithAnimation(false, duration: hiddenDuration)
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
				.onSuccess { [weak self] image in
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
