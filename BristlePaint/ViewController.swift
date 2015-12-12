//
//  ViewController.swift
//  BristlePaint
//
//  Created by Simon Gladman on 10/12/2015.
//  Copyright © 2015 Simon Gladman. All rights reserved.
//


import UIKit
import SpriteKit

class ViewController: UIViewController
{
    let spriteKitView = SKView()
    let spriteKitScene = SKScene()
    let backgroundNode = SKSpriteNode()
    
    let brushPreviewLayer = CAShapeLayer()
    let brushPreviewPath = UIBezierPath()
    let bristleCount = 1
    let brushRadiusMultiplier = CGFloat(100)
    let brushInnerRadius = CGFloat(2)
    
    let tau = CGFloat(M_PI * 2)
    let halfPi = CGFloat(M_PI_2)
  
    let diffuseCompositeFilter = CIFilter(name: "CIColorBlendMode")!
    let normalCompositeFilter = CIFilter(name: "CIAdditionCompositing")!
    let blur = CIFilter(name: "CIDiscBlur", withInputParameters: [kCIInputRadiusKey : 2])
    
    let slider = UISlider()
    var hue = CGFloat(0)
    
    let ciContext = CIContext(EAGLContext: EAGLContext(API: EAGLRenderingAPI.OpenGLES2), options: [kCIContextWorkingColorSpace: NSNull()])
    let size = CGSize(width: 1024, height: 1024)
    
    lazy var diffuseImageAccumulator: CIImageAccumulator =
    {
        [unowned self] in
        return CIImageAccumulator(extent: CGRect(origin: CGPointZero, size: self.size), format: kCIFormatARGB8)
    }()
    
    lazy var normalImageAccumulator: CIImageAccumulator =
    {
        [unowned self] in
        return CIImageAccumulator(extent: CGRect(origin: CGPointZero, size: self.size), format: kCIFormatARGB8)
        }()
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        slider.maximumValue = 1
        slider.addTarget(self, action: "sliderChangeHandler", forControlEvents: .ValueChanged)
        
        brushPreviewLayer.strokeColor = UIColor.whiteColor().CGColor
        brushPreviewLayer.lineWidth = 1
        
        view.addSubview(spriteKitView)
        view.addSubview(slider)
        view.layer.addSublayer(brushPreviewLayer)
        
        view.backgroundColor =  UIColor.blackColor()
        
        sliderChangeHandler()
        
        // ---
        
        spriteKitView.presentScene(spriteKitScene)
        
        for position in [[0,1024], [1024,512]]
        {
            let light = SKLightNode()
            
            light.position = CGPoint(x: position[0], y: position[1])
           
            light.falloff = 0
            light.categoryBitMask = UInt32(1)
            backgroundNode.lightingBitMask = UInt32(1)
            spriteKitScene.addChild(light)
        }
        
        spriteKitScene.addChild(backgroundNode)
        
    }
    
    func sliderChangeHandler()
    {
        hue = CGFloat(slider.value)
        
        slider.minimumTrackTintColor = diffuseColor
        slider.maximumTrackTintColor = diffuseColor
        slider.thumbTintColor = diffuseColor
    }
    
    var diffuseColor: UIColor
    {
        return UIColor(hue: hue, saturation: 1, brightness: 1, alpha: 1)
    }

    func textureFromTouches(touches: [UITouch], origin: CGPoint, imageAccumulator: CIImageAccumulator, compositeFilter: CIFilter, color: CGColorRef, lineWidth: CGFloat, useBlur:Bool = false) -> SKTexture
    {
        UIGraphicsBeginImageContext(size)
        
        let cgContext = UIGraphicsGetCurrentContext()
        
        CGContextSetLineWidth(cgContext, lineWidth)
        CGContextSetLineCap(cgContext, CGLineCap.Round)
        
        CGContextSetStrokeColorWithColor(cgContext, color)

        CGContextSetLineJoin(cgContext, CGLineJoin.Round)
        CGContextSetFlatness(cgContext, 0)
        
        CGContextMoveToPoint(cgContext,
            origin.x,
            origin.y)
        
        for touch in touches
        {            
            CGContextAddLineToPoint(cgContext,
                touch.locationInView(spriteKitView).x,
                touch.locationInView(spriteKitView).y)
        }
        
        CGContextStrokePath(cgContext)
        
        let drawnImage = UIGraphicsGetImageFromCurrentImageContext()
        
        UIGraphicsEndImageContext()
        
        compositeFilter.setValue(CIImage(image: drawnImage),
            forKey: kCIInputImageKey)
        compositeFilter.setValue(imageAccumulator.image(),
            forKey: kCIInputBackgroundImageKey)
        
        imageAccumulator.setImage(compositeFilter.valueForKey(kCIOutputImageKey) as! CIImage)
        
        let finalImage: CIImage
        
        if useBlur
        {
            blur?.setValue(imageAccumulator.image(), forKey: kCIInputImageKey)
            
            finalImage = blur?.valueForKey(kCIOutputImageKey) as! CIImage
        }
        else
        {
            finalImage = imageAccumulator.image()
        }
        
        let filteredImageRef = self.ciContext.createCGImage(finalImage,
            fromRect: CGRect(origin: CGPointZero, size: size))
        
        
        return SKTexture(CGImage: filteredImageRef)
    }
    
    var origin = CGPointZero
    var xxxx = [UITouch]()
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?)
    {
        guard let touch = touches.first else
        {
            return
        }
        
        origin = touch.locationInView(spriteKitView)
        xxxx = [UITouch]()
    }
    
    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?)
    {
        guard let
            touch = touches.first,
            coalescedTouces = event?.coalescedTouchesForTouch(touch) where
            touch.type == UITouchType.Stylus else
        {
            return
        }
        
        xxxx.appendContentsOf(coalescedTouces)
        
        let normalisedAlititudeAngle =  (halfPi - touch.altitudeAngle) / halfPi
//        let dx = touch.azimuthUnitVectorInView(view).dx * 40 * normalisedAlititudeAngle
//        let dy = touch.azimuthUnitVectorInView(view).dy * 40 * normalisedAlititudeAngle
        
        // drawBrushPreview(touch.locationInView(view), force: touch.force / touch.maximumPossibleForce, dx: dx, dy: dy)
       
 
    }
    
    var lastTouchPoint = CGPointZero
    
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?)
    {
        let texture = textureFromTouches(xxxx,
            origin: origin,
            imageAccumulator: diffuseImageAccumulator,
            compositeFilter: diffuseCompositeFilter,
            color: diffuseColor.colorWithAlphaComponent(0.25).CGColor,
            lineWidth: 6, useBlur: true)
        
        let normalMap = textureFromTouches(xxxx,
            origin: origin,
            imageAccumulator: normalImageAccumulator,
            compositeFilter: normalCompositeFilter,
            color: UIColor(white: 1, alpha: 0.1).CGColor, lineWidth: 4).textureByGeneratingNormalMapWithSmoothness(2, contrast: 8)
        
        backgroundNode.texture = texture
        backgroundNode.normalTexture = normalMap
    }
    
    override func viewDidLayoutSubviews()
    {
        
        
        spriteKitView.frame = CGRect(origin: CGPoint(x: (view.frame.width - 1024) / 2, y: 0), size: size)
        
        spriteKitScene.size = size
        
        backgroundNode.size = size
        
        backgroundNode.position = CGPoint(x: spriteKitView.frame.width / 2, y: spriteKitView.frame.height / 2)
        
        slider.frame = CGRect(x: 0,
            y: view.frame.height - slider.intrinsicContentSize().height - 20,
            width: view.frame.width,
            height: slider.intrinsicContentSize().height).insetBy(dx: 20, dy: 0)
    }
}