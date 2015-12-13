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
    let brushRadiusMultiplier = CGFloat(100)
    let brushInnerRadius = CGFloat(2)
    
    let tau = CGFloat(M_PI * 2)
    let halfPi = CGFloat(M_PI_2)
  
    let diffuseCompositeFilter = CIFilter(name: "CIColorBlendMode")!
    let normalCompositeFilter = CIFilter(name: "CIAdditionCompositing")!
    
    let slider = UISlider()
    var hue = CGFloat(0)
    
    let ciContext = CIContext(EAGLContext: EAGLContext(API: EAGLRenderingAPI.OpenGLES2), options: [kCIContextWorkingColorSpace: NSNull()])
    let size = CGSize(width: 1024, height: 1024)
    
    let bristleCount = 15
    var bristleAngles = [CGFloat]()
    
    var origin = CGPointZero
    var touchData = [TouchDatum]()
    
    typealias TouchDatum = (location: CGPoint, force: CGFloat, azimuth: CGVector)
    
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
        
        for _ in 0 ... bristleCount
        {
            bristleAngles.append(CGFloat(drand48()) * tau)
        }
        
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

    
    
    func pathFromTouches(touchData: [TouchDatum]) -> CGPathRef?
    {
        guard let firstTouchDatum = touchData.first,
            firstBristleAngle = bristleAngles.first else
        {
            return nil
        }
        
        func forceToRadius(force: CGFloat) -> CGFloat
        {
            return 10 + force * 100
        }
        
        let bezierPath = UIBezierPath()
        
        for var i = 0; i < bristleAngles.count; i++
        {
            let x = firstTouchDatum.location.x + sin(firstBristleAngle) * forceToRadius(firstTouchDatum.force)
            let y = firstTouchDatum.location.y + cos(firstBristleAngle) * forceToRadius(firstTouchDatum.force)
            
            bezierPath.moveToPoint(CGPoint(x: x, y: y))
            
            for touchDatum in touchData
            {
                let bristleAngle = bristleAngles[i]
                
                let x = touchDatum.location.x + sin(bristleAngle) * forceToRadius(touchDatum.force) * touchDatum.azimuth.dy
                let y = touchDatum.location.y + cos(bristleAngle) * forceToRadius(touchDatum.force) * touchDatum.azimuth.dx
                
                bezierPath.addLineToPoint(CGPoint(x: x, y: y))
                
                bristleAngles[i] = bristleAngles[i] - 0.4 + (CGFloat(drand48()) * 0.8)
            }
        }
        
        return bezierPath.CGPath
    }
    
    func textureFromPath(path: CGPathRef, origin: CGPoint, imageAccumulator: CIImageAccumulator, compositeFilter: CIFilter, color: CGColorRef, lineWidth: CGFloat) -> SKTexture
    {
        UIGraphicsBeginImageContext(size)
        
        let cgContext = UIGraphicsGetCurrentContext()
        
        CGContextSetLineWidth(cgContext, lineWidth)
        CGContextSetLineCap(cgContext, CGLineCap.Round)
        
        CGContextSetStrokeColorWithColor(cgContext, color)

        CGContextAddPath(cgContext, path)
        
        CGContextStrokePath(cgContext)
        
        let drawnImage = UIGraphicsGetImageFromCurrentImageContext()
        
        UIGraphicsEndImageContext()
        
        compositeFilter.setValue(CIImage(image: drawnImage),
            forKey: kCIInputImageKey)
        compositeFilter.setValue(imageAccumulator.image(),
            forKey: kCIInputBackgroundImageKey)
        
        imageAccumulator.setImage(compositeFilter.valueForKey(kCIOutputImageKey) as! CIImage)
        
        let filteredImageRef = self.ciContext.createCGImage(imageAccumulator.image(),
            fromRect: CGRect(origin: CGPointZero, size: size))
        
        
        return SKTexture(CGImage: filteredImageRef)
    }

    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?)
    {
        guard let touch = touches.first else
        {
            return
        }
        
        origin = touch.locationInView(spriteKitView)
        touchData = [TouchDatum]()
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
        
        touchData.appendContentsOf(coalescedTouces.map({(
            $0.locationInView(spriteKitView),
            $0.force / $0.maximumPossibleForce,
            $0.azimuthUnitVectorInView(spriteKitView)
            )}))
        
        let normalisedAlititudeAngle =  (halfPi - touch.altitudeAngle) / halfPi
//        let dx = touch.azimuthUnitVectorInView(view).dx * 40 * normalisedAlititudeAngle
//        let dy = touch.azimuthUnitVectorInView(view).dy * 40 * normalisedAlititudeAngle
        
        // drawBrushPreview(touch.locationInView(view), force: touch.force / touch.maximumPossibleForce, dx: dx, dy: dy)
       
 
    }
    
    var lastTouchPoint = CGPointZero
    
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?)
    {
        guard let path = pathFromTouches(touchData) else
        {
            return
        }
        
        let texture = textureFromPath(path,
            origin: origin,
            imageAccumulator: diffuseImageAccumulator,
            compositeFilter: diffuseCompositeFilter,
            color: diffuseColor.colorWithAlphaComponent(0.25).CGColor,
            lineWidth: 3)
        
        let normalMap = textureFromPath(path,
            origin: origin,
            imageAccumulator: normalImageAccumulator,
            compositeFilter: normalCompositeFilter,
            color: UIColor(white: 1, alpha: 0.1).CGColor, lineWidth: 3).textureByGeneratingNormalMapWithSmoothness(2, contrast: 8)
        
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