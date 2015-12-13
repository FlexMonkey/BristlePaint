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
 
    
    let tau = CGFloat(M_PI * 2)
    let halfPi = CGFloat(M_PI_2)
  
    let diffuseCompositeFilter = CIFilter(name: "CISourceOverCompositing")!
    let normalCompositeFilter = CIFilter(name: "CIAdditionCompositing")!
    
    let slider = UISlider()
    var hue = CGFloat(0)
    
    static let ciContext = CIContext(EAGLContext: EAGLContext(API: EAGLRenderingAPI.OpenGLES2), options: [kCIContextWorkingColorSpace: NSNull()])
    static let size = CGSize(width: 1024, height: 1024)
    
    let bristleCount = 20
    var bristleAngles = [CGFloat]()
    
    var origin = CGPointZero
    var touchData = [TouchDatum]()
    
    typealias TouchDatum = (location: CGPoint, force: CGFloat, azimuthVector: CGVector, azimuthAngle: CGFloat)
    
    lazy var diffuseImageAccumulator: CIImageAccumulator =
    {
        [unowned self] in
        return CIImageAccumulator(extent: CGRect(origin: CGPointZero, size: ViewController.size), format: kCIFormatARGB8)
    }()
    
    lazy var normalImageAccumulator: CIImageAccumulator =
    {
        [unowned self] in
        return CIImageAccumulator(extent: CGRect(origin: CGPointZero, size: ViewController.size), format: kCIFormatARGB8)
    }()
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        slider.maximumValue = 1
        slider.addTarget(self, action: "sliderChangeHandler", forControlEvents: .ValueChanged)
        
        brushPreviewLayer.strokeColor = UIColor.whiteColor().CGColor
        brushPreviewLayer.lineWidth = 1
        brushPreviewLayer.fillColor = nil
        
        view.addSubview(spriteKitView)
        view.addSubview(slider)
        spriteKitView.layer.addSublayer(brushPreviewLayer)
        
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

    
    
    static func pathFromTouches(touchData: [TouchDatum], bristleAngles: [CGFloat]) -> CGPathRef?
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
                
                let x = touchDatum.location.x + sin(bristleAngle + touchDatum.azimuthAngle) * forceToRadius(touchDatum.force) * touchDatum.azimuthVector.dy
                let y = touchDatum.location.y + cos(bristleAngle + touchDatum.azimuthAngle) * forceToRadius(touchDatum.force) * touchDatum.azimuthVector.dx
                
                bezierPath.addLineToPoint(CGPoint(x: x, y: y))
            }
        }
        
        return bezierPath.CGPath
    }
    
    static func textureFromPath(path: CGPathRef, origin: CGPoint, imageAccumulator: CIImageAccumulator, compositeFilter: CIFilter, color: CGColorRef, lineWidth: CGFloat) -> SKTexture
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
        
        let filteredImageRef = ciContext.createCGImage(imageAccumulator.image(),
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
            $0.azimuthUnitVectorInView(spriteKitView),
            $0.azimuthAngleInView(spriteKitView)
            )}))

        for var i = 0; i < bristleAngles.count; i++
        {
            bristleAngles[i] = bristleAngles[i] - 0.02 + CGFloat(drand48() * 0.04)
        }
        
        if let path = ViewController.pathFromTouches(touchData, bristleAngles: bristleAngles)
        {
            brushPreviewLayer.path = path
        }
    }
    
    var lastTouchPoint = CGPointZero
    
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?)
    {
        brushPreviewLayer.path = nil
        
        guard let path = ViewController.pathFromTouches(touchData, bristleAngles: bristleAngles) else
        {
            return
        }
        
        let texture = ViewController.textureFromPath(path,
            origin: origin,
            imageAccumulator: diffuseImageAccumulator,
            compositeFilter: diffuseCompositeFilter,
            color: diffuseColor.colorWithAlphaComponent(0.25).CGColor,
            lineWidth: 3)
        
        let normalMap = ViewController.textureFromPath(path,
            origin: origin,
            imageAccumulator: normalImageAccumulator,
            compositeFilter: normalCompositeFilter,
            color: UIColor(white: 1, alpha: 0.1).CGColor, lineWidth: 3).textureByGeneratingNormalMapWithSmoothness(2, contrast: 8)
        
        backgroundNode.texture = texture
        backgroundNode.normalTexture = normalMap
    }
    
    override func viewDidLayoutSubviews()
    {
        
        
        spriteKitView.frame = CGRect(origin: CGPoint(x: (view.frame.width - 1024) / 2, y: 0), size: ViewController.size)
        
        spriteKitScene.size = ViewController.size
        
        backgroundNode.size = ViewController.size
        
        backgroundNode.position = CGPoint(x: spriteKitView.frame.width / 2, y: spriteKitView.frame.height / 2)
        
        slider.frame = CGRect(x: 0,
            y: view.frame.height - slider.intrinsicContentSize().height - 20,
            width: view.frame.width,
            height: slider.intrinsicContentSize().height).insetBy(dx: 20, dy: 0)
    }
}