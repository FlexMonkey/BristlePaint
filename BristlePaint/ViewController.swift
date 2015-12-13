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
    let tau = CGFloat(M_PI * 2)
    let halfPi = CGFloat(M_PI_2)
    
    typealias TouchDatum = (location: CGPoint, force: CGFloat, azimuthVector: CGVector, azimuthAngle: CGFloat)
    typealias PendingPath = (path: CGPathRef, origin: CGPoint, color: UIColor, shapeLayer: CAShapeLayer)
    
    let spriteKitView = SKView()
    let spriteKitScene = SKScene()
    let backgroundNode = SKSpriteNode()
    
    let brushPreviewLayer = CAShapeLayer()

    let diffuseCompositeFilter = CIFilter(name: "CISourceOverCompositing")!
    let normalCompositeFilter = CIFilter(name: "CIAdditionCompositing")!
    
    let slider = UISlider()
    var hue = CGFloat(0)
    
    static let ciContext = CIContext(EAGLContext: EAGLContext(API: EAGLRenderingAPI.OpenGLES2), options: [kCIContextWorkingColorSpace: NSNull()])
    static let size = CGSize(width: 1024, height: 1024)
    
    let bristleCount = 20
    var origin = CGPointZero
    var touchData = [TouchDatum]()
    var pendingPaths = [PendingPath]()
    
    var diffuseColor: UIColor
    {
        return UIColor(hue: hue, saturation: 1, brightness: 1, alpha: 1)
    }
    
    lazy var bristleAngles: [CGFloat] =
    {
        [unowned self] in
        
        var bristleAngles = [CGFloat]()
        
        for _ in 0 ... self.bristleCount
        {
            bristleAngles.append(CGFloat(drand48()) * self.tau)
        }
        
        return bristleAngles
    }()
 
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
    
    // MARL: Initialisation
    
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
 
        initSpriteKit()
    }
    
    func initSpriteKit()
    {
        spriteKitView.presentScene(spriteKitScene)
        
        for position in [[0,1024], [1024, 1024]]
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
    
    // MARK: User gesture handlers
    
    func sliderChangeHandler()
    {
        hue = CGFloat(slider.value)
        
        slider.minimumTrackTintColor = diffuseColor
        slider.maximumTrackTintColor = diffuseColor
        slider.thumbTintColor = diffuseColor
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

        if let path = ViewController.pathFromTouches(touchData, bristleAngles: bristleAngles)
        {
            brushPreviewLayer.path = path
        }
    }
  
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?)
    {
        brushPreviewLayer.path = nil
        
        guard let path = ViewController.pathFromTouches(touchData, bristleAngles: bristleAngles) else
        {
            return
        }
        
        let temporaryLayer = CAShapeLayer()
        temporaryLayer.fillColor = nil
        temporaryLayer.strokeColor = diffuseColor.CGColor
        temporaryLayer.path = path
        
        spriteKitView.layer.addSublayer(temporaryLayer)
        
        pendingPaths.append((path, origin, diffuseColor, temporaryLayer))
        drawPendingPath()
    }
    
    // MARK: BristlePaint mechanics
    
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

    
    func drawPendingPath()
    {
        guard pendingPaths.count > 0 else
        {
            return
        }
        
        let pendingPath = pendingPaths.removeFirst()
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0))
        {
            let diffuseMape = ViewController.textureFromPath(pendingPath.path,
                origin: pendingPath.origin,
                imageAccumulator: self.diffuseImageAccumulator,
                compositeFilter: self.diffuseCompositeFilter,
                color: pendingPath.color.colorWithAlphaComponent(1).CGColor,
                lineWidth: 2)
            
            let normalMap = ViewController.textureFromPath(pendingPath.path,
                origin: pendingPath.origin,
                imageAccumulator: self.normalImageAccumulator,
                compositeFilter: self.normalCompositeFilter,
                color: UIColor(white: 1, alpha: 0.1).CGColor, lineWidth: 2).textureByGeneratingNormalMapWithSmoothness(0.5, contrast: 3)
            
            dispatch_async(dispatch_get_main_queue())
            {
                pendingPath.shapeLayer.removeFromSuperlayer()
                
                self.backgroundNode.texture = diffuseMape
                self.backgroundNode.normalTexture = normalMap
                
                self.drawPendingPath()
            }
        }
    }
    
    // MARK: Layout
    
    override func prefersStatusBarHidden() -> Bool
    {
        return true
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