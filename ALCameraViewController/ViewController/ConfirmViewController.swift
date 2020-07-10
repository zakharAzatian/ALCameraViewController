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
    private let cropOverlay = CropOverlay()
    private var spinner: UIActivityIndicatorView? = nil
    private var cropOverlayLeftConstraint = NSLayoutConstraint()
    private var cropOverlayTopConstraint = NSLayoutConstraint()
    private var cropOverlayWidthConstraint = NSLayoutConstraint()
    private var cropOverlayHeightConstraint = NSLayoutConstraint()
    private var isFirstLayout = true
	
    var croppingParameters: CroppingParameters {
        didSet {
            cropOverlay.isResizable = croppingParameters.allowResizing
            cropOverlay.minimumSize = croppingParameters.minimumSize
        }
    }

    private let cropOverlayDefaultPadding: CGFloat = 20
    private var cropOverlayDefaultFrame: CGRect {
        let buttonsViewGap: CGFloat = 20 * 2 + 64
        let centeredViewBounds: CGRect
        if view.bounds.size.height > view.bounds.size.width {
            centeredViewBounds = CGRect(x: 0,
                                        y: 0,
                                        width: view.bounds.size.width,
                                        height: view.bounds.size.height - buttonsViewGap)
        } else {
            centeredViewBounds = CGRect(x: 0,
                                        y: 0,
                                        width: view.bounds.size.width - buttonsViewGap,
                                        height: view.bounds.size.height)
        }
        
        let cropOverlayWidth = min(centeredViewBounds.size.width, centeredViewBounds.size.height) - 2 * cropOverlayDefaultPadding
        let cropOverlayX = centeredViewBounds.size.width / 2 - cropOverlayWidth / 2
        let cropOverlayY = centeredViewBounds.size.height / 2 - cropOverlayWidth / 2

        return CGRect(x: cropOverlayX,
                      y: cropOverlayY,
                      width: cropOverlayWidth,
                      height: cropOverlayWidth)
    }
	
	public var onComplete: CameraViewCompletion?

	let asset: PHAsset?
	let image: UIImage?
	
	public init(image: UIImage, croppingParameters: CroppingParameters) {
		self.croppingParameters = croppingParameters
		self.asset = nil
		self.image = image
		super.init(nibName: "ConfirmViewController", bundle: CameraGlobals.shared.bundle)
	}
	
	public init(asset: PHAsset, croppingParameters: CroppingParameters) {
		self.croppingParameters = croppingParameters
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
        loadCropOverlay()
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
            activateCropOverlayConstraint()
            spinner?.center = view.center
        }
    }
    
    private func setupDetectionAreaView() {
        view.insertSubview(detectionAreaView, aboveSubview: imageView)
        detectionAreaView.pinToSuperview()
    }

    private func activateCropOverlayConstraint() {
        cropOverlayLeftConstraint.constant = cropOverlayDefaultFrame.origin.x
        cropOverlayTopConstraint.constant = cropOverlayDefaultFrame.origin.y
        cropOverlayWidthConstraint.constant = cropOverlayDefaultFrame.size.width
        cropOverlayHeightConstraint.constant = cropOverlayDefaultFrame.size.height

        cropOverlayLeftConstraint.isActive = true
        cropOverlayTopConstraint.isActive = true
        cropOverlayWidthConstraint.isActive = true
        cropOverlayHeightConstraint.isActive = true
    }

    private func loadCropOverlay() {
        cropOverlay.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cropOverlay)

        cropOverlayLeftConstraint = cropOverlay.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 0)
        cropOverlayTopConstraint = cropOverlay.topAnchor.constraint(equalTo: view.topAnchor, constant: 0)
        cropOverlayWidthConstraint = cropOverlay.widthAnchor.constraint(equalToConstant: 0)
        cropOverlayHeightConstraint = cropOverlay.heightAnchor.constraint(equalToConstant: 0)

        cropOverlay.delegate = self
        cropOverlay.isHidden = !croppingParameters.isEnabled
        cropOverlay.isResizable = croppingParameters.allowResizing
        cropOverlay.isMovable = croppingParameters.allowMoving
        cropOverlay.minimumSize = croppingParameters.minimumSize
    }
	
	private func configureWithImage(_ image: UIImage) {
		buttonActions()
		
		imageView.image = image
	}

	private func buttonActions() {
		confirmButton.action = { [weak self] in self?.confirmPhoto() }
		retakeButton.action = { [weak self] in self?.cancel() }
	}
	
	internal func cancel() {
		onComplete?(nil, nil)
	}
	
	internal func confirmPhoto() {
		
		guard let image = imageView.image else {
			return
		}
		
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
			if croppingParameters.isEnabled {
				let rect = normalizedRect(makeProportionalCropRect(), orientation: image.imageOrientation)
				fetcher = fetcher.setCropRect(rect)
			}
			
			fetcher = fetcher.fetch()
		} else {
			var newImage = image
			
			if croppingParameters.isEnabled {
				let cropRect = makeProportionalCropRect()
				let resizedCropRect = CGRect(x: (image.size.width) * cropRect.origin.x,
				                     y: (image.size.height) * cropRect.origin.y,
				                     width: (image.size.width * cropRect.width),
				                     height: (image.size.height * cropRect.height))
				newImage = image.crop(rect: resizedCropRect)
			}
			
			onComplete?(newImage, nil)
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
	
	private func makeProportionalCropRect() -> CGRect {
        let cropRect = cropOverlay.croppedRect

		let normalizedX = max(0, cropRect.origin.x / imageView.frame.width)
		let normalizedY = max(0, cropRect.origin.y / imageView.frame.height)

        let extraWidth = min(0, cropRect.origin.x)
        let extraHeight = min(0, cropRect.origin.y)

		let normalizedWidth = min(1, (cropRect.width + extraWidth) / imageView.frame.width)
		let normalizedHeight = min(1, (cropRect.height + extraHeight) / imageView.frame.height)
		
		return CGRect(x: normalizedX, y: normalizedY, width: normalizedWidth, height: normalizedHeight)
	}
	
}

extension ConfirmViewController: CropOverlayDelegate {

    func didMoveCropOverlay(newFrame: CGRect) {
        cropOverlayLeftConstraint.constant = newFrame.origin.x
        cropOverlayTopConstraint.constant = newFrame.origin.y
        cropOverlayWidthConstraint.constant = newFrame.size.width
        cropOverlayHeightConstraint.constant = newFrame.size.height
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
