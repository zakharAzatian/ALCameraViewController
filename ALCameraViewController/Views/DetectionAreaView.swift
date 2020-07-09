//
//  DetectionAreaView.swift
//  ALCameraViewController
//
//  Created by Zakhar Azatian on 7/9/20.
//  Copyright © 2020 zero. All rights reserved.
//

import UIKit

final public class DetectionAreaView: UIView {
    var sidePadding: CGFloat = 12.0
    var holeShapecornerRadius: CGFloat = 16.0
    
    private let backgroundView = UIView()
    private let maskLayer = CAShapeLayer()
    private let titleLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    private func commonInit() {
        setupHoleView()
        setupTitleLabel()
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        validateLayout()
    }
    
    func setTitle(_ title: String, font: UIFont?) {
        titleLabel.text = title
        titleLabel.font = font
    }
    
    private func validateLayout() {
        let width = bounds.width - sidePadding * 2
        let size = CGSize(width: width, height: width)
        let viewOrigin = CGPoint(x: center.x - size.width / 2, y: center.y - size.height / 2)
        
        let rect = CGRect(origin: viewOrigin, size: size)
        let boxPath = UIBezierPath(roundedRect: rect, cornerRadius: holeShapecornerRadius)
        let path = UIBezierPath(rect: backgroundView.bounds)
        path.append(boxPath)
        
        backgroundView.frame = CGRect(origin: .zero, size: CGSize(width: frame.width, height: frame.height))
        maskLayer.frame = bounds
        maskLayer.path = path.cgPath
        
        titleLabel.center = center
        titleLabel.frame.origin.y = viewOrigin.y - 36.0
        titleLabel.frame.size = CGSize(width: bounds.width, height: 20.0)
    }
    
    private func setupHoleView() {
        backgroundView.frame = CGRect(origin: .zero, size: CGSize(width: frame.width, height: frame.height))

        backgroundView.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        addSubview(backgroundView)
        
        maskLayer.frame = bounds
        maskLayer.fillRule = CAShapeLayerFillRule.evenOdd
        backgroundView.layer.mask = maskLayer
    }
    
    private func setupTitleLabel() {
        addSubview(titleLabel)
        titleLabel.textAlignment = .center
        titleLabel.textColor = .white
    }
}
