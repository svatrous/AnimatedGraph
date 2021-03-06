//
//  Graph2View.swift
//  Graph
//
//  Created by Alexandr on 24.01.17.
//  Copyright © 2017 Alexandr. All rights reserved.
//

import UIKit

protocol GraphViewUsageProtocol {
    
    /// At first you need to configure graph with launch data.
    ///
    /// - Parameters:
    ///   - points: Launch array of points
    ///   - columnNames: Bottom located column names.
    ///   - title: Title of graph
    func configure(withPoints points: [Double], columnNames: [String]?, title: String?)
    
    
    /// Animate Graph to min values
    func animateToMinValues()
    
    /// Use this method to animate graph with other points and column names.
    /// - Parameters:
    ///   - points: Array of points
    ///   - columnNames: Array of column names
    func animate(withPoints points: [Double], columnNames: [String]?)
}

class GraphView: UIView, GraphViewUsageProtocol {
    
    enum LabelsAlignment {
        case left
        case right
    }
    
    var startColor: UIColor = UIColor.red
    var endColor: UIColor = UIColor.green
    var startGraphColor: UIColor = UIColor.red
    var endGraphColor: UIColor = UIColor.green
    var fontColor: UIColor = UIColor.white
    var graphLineColor: UIColor = UIColor.white
    var lineWidth: CGFloat = 2.0
    var isEnabledDots = true
    var isEnabledLines = true
    var labelsAlignment: LabelsAlignment = .left
    var labelsTextColor: UIColor = UIColor.white
    var linesColor: UIColor = UIColor.white
    var linesWidth: CGFloat = 1.0
    var numberFormatter: ((Double) -> NumberFormatter)!
    var maxHorizontalLines = 3
    var maxVerticalLines = 8
    var graphPadding: UIEdgeInsets {
        get {
            return graphLayer.padding
        }
        set {
            graphLayer.padding = newValue
        }
    }
    
    var graphPoints: [Double] = []
    var graphColumnNames: [String]?
    var title = ""
    
    private var graphLayer = GraphLayer()
    private var graphGradientLayer = CAGradientLayer()
    private var graphLineLayer = CAShapeLayer()
    private var linesLayer = CAShapeLayer()
    private var dotsLayer = [CAShapeLayer]()
    private var bottomLabels = [UILabel]()
    
    // MARK: - Life Cycle
    
    required override init(frame: CGRect) {
        super.init(frame: frame)
        
        layer.addSublayer(graphLayer)
        layer.addSublayer(linesLayer)
        
        graphGradientLayer.mask = graphLayer
        layer.addSublayer(graphGradientLayer)
        layer.addSublayer(graphLineLayer)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init?(coder aDecoder: NSCoder) is not required")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        graphLayer.frame.size = frame.size
    }
    
    // MARK: - Public
    
    func animateToMinValues() {
        animate(withPoints: graphPoints, columnNames: graphColumnNames, animateToMinValues: true)
    }
    
    func animate(withPoints points: [Double], columnNames: [String]?) {
        animate(withPoints: points, columnNames: columnNames, animateToMinValues: false)
    }
    
    func configure(withPoints points: [Double], columnNames: [String]?, title: String?) {
        if let columnNames = columnNames {
            assert(points.count == columnNames.count, "'points' and 'columns' count must be the same")
            graphColumnNames = columnNames
        }
        
        graphPoints = points
        graphGradientLayer.colors = [startGraphColor.cgColor, endGraphColor.cgColor]
        graphLineLayer.strokeColor = graphLineColor.cgColor
        graphLineLayer.fillColor = UIColor.clear.cgColor
        graphLineLayer.lineWidth = lineWidth
        
        if isEnabledDots {
            for _ in 0..<graphPoints.count {
                let circleLayer = CAShapeLayer()
                layer.addSublayer(circleLayer)
                dotsLayer.append(circleLayer)
            }
        }
        
        if let title = title {
            self.title = title
        }
        
        removeLabels()
        
        if graphPoints.count > 0 {
            graphLayer.fillProperties(points: graphPoints)
            
            graphGradientLayer.frame = bounds
            graphGradientLayer.startPoint = CGPoint(x: 0.5, y: graphLayer.highestYPoint / bounds.size.height)
            graphGradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
            
            graphLineLayer.path = graphLayer.graphPath.cgPath
            
            titleLabel()
            
            if isEnabledLines {
                drawLines()
            }
            
            addLabels()
            
            if isEnabledDots {
                drawDots()
            }
        }
    }
    
    // MARK: - Private
    
    private func animate(withPoints points: [Double], columnNames: [String]?, animateToMinValues: Bool) {
        graphLayer.isAnimatingMinValues = animateToMinValues
        
        if let columnNames = columnNames {
            assert(points.count == columnNames.count, "'points' and 'columns' count must be the same")
            
            graphColumnNames = columnNames
            var i = 0
            for label in bottomLabels {
                label.text = columnNames[i]
                i += 1
            }
        }
        
        let previousHighestY = graphLayer.highestYPoint
        let previousLine = graphLayer.graphPath.cgPath
        
        var animation = CABasicAnimation(keyPath: "path")
        animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
        animation.fromValue = graphLayer.previousPath.cgPath
        animation.toValue = graphLayer.rectangle(withPoints: points).cgPath
        animation.duration = 0.4
        animation.fillMode = kCAFillModeForwards
        animation.isRemovedOnCompletion = false
        graphLayer.add(animation, forKey: "path")
        
        let currentHighestY = graphLayer.highestYPoint
        let currentLine = graphLayer.graphPath.cgPath
        
        animation = CABasicAnimation(keyPath: "startPoint")
        animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
        animation.fromValue = CGPoint(x: 0.5, y: previousHighestY! / bounds.size.height)
        animation.toValue = CGPoint(x: 0.5, y: currentHighestY! / bounds.size.height)
        animation.duration = 0.4
        animation.fillMode = kCAFillModeForwards
        animation.isRemovedOnCompletion = false
        graphGradientLayer.add(animation, forKey: "startPoint")
        
        animation = CABasicAnimation(keyPath: "path")
        animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
        animation.fromValue = previousLine
        animation.toValue = currentLine
        animation.duration = 0.4
        animation.fillMode = kCAFillModeForwards
        animation.isRemovedOnCompletion = false
        graphLineLayer.add(animation, forKey: "path")
        
        if isEnabledDots {
            var i = 0
            for dot in dotsLayer {
                var point = CGPoint(x: graphLayer.columnXPoint(column: i),
                                    y: graphLayer.columnYPoint(graphPoint: graphLayer.graphPoints[i]))
                point.x -= 5.0/2
                point.y -= 5.0/2
                
                let circle = UIBezierPath(ovalIn: CGRect(origin: point,
                                                         size: CGSize(width: 5.0, height: 5.0)))
                
                animation = CABasicAnimation(keyPath: "path")
                animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
                animation.fromValue = dot.path
                animation.toValue = circle.cgPath
                animation.duration = 0.4
                animation.fillMode = kCAFillModeForwards
                animation.isRemovedOnCompletion = false
                dot.add(animation, forKey: "path")
                
                i += 1
                
                dot.path = circle.cgPath
            }
        }
        
        graphPoints = points
        removeLabels()
        addLabels()
    }
    
    private func removeLabels() {
        for subview in subviews {
            if subview is UILabel {
                subview.removeFromSuperview()
            }
        }
    }
    
    private func titleLabel() {
        let margin: CGFloat = 8
        let labelHeight: CGFloat = 25
        let labelSize: CGFloat = 16
        
        let label = UILabel(frame: CGRect(x: margin,
                                          y: margin,
                                          width: frame.size.width - margin,
                                          height: labelHeight))
        label.text = title
        label.font = UIFont.boldSystemFont(ofSize: labelSize)
        label.textColor = fontColor
        label.textAlignment = .center
        addSubview(label)
    }
    
    private func drawLines() {
        let linePath = UIBezierPath()
        
        for i in 0...(maxHorizontalLines - 1) {
            let y: CGFloat = graphLayer.graphHeight/CGFloat((maxHorizontalLines - 1))*CGFloat(i) + graphLayer.padding.top
            let moveX: CGFloat = graphLayer.padding.left
            let addLineX: CGFloat = graphLayer.bounds.width - graphLayer.padding.right
            
            linePath.move(to: CGPoint(x: moveX + linesWidth,
                                      y: y))
            linePath.addLine(to: CGPoint(x: addLineX - linesWidth,
                                         y: y))
        }
        
        for i in 0...(maxVerticalLines - 1) {
            let x: CGFloat = graphLayer.graphWidth/CGFloat((maxVerticalLines - 1))*CGFloat(i) + graphLayer.padding.left
            let moveY: CGFloat = graphPadding.top
            let addLineY: CGFloat = graphPadding.top + graphLayer.graphHeight
            
            if i == maxVerticalLines - 1 {
                linePath.move(to: CGPoint(x: x - linesWidth,
                                          y: moveY))
                linePath.addLine(to: CGPoint(x: x - linesWidth,
                                             y: addLineY))
            } else {
                linePath.move(to: CGPoint(x: x + linesWidth,
                                          y: moveY))
                linePath.addLine(to: CGPoint(x: x + linesWidth,
                                             y: addLineY))
            }
        }
        
        linesLayer.path = linePath.cgPath
        linesLayer.lineDashPattern = [NSNumber(value: 2), NSNumber(value: 4)]
        linesLayer.lineJoin = kCALineCapButt
        linesLayer.strokeColor = linesColor.withAlphaComponent(0.3).cgColor
        linesLayer.lineWidth = linesWidth
    }
    
    private func formatValue(_ value: Double) -> String {
        let decimal = Decimal(value)
        return numberFormatter(value).string(from: NSDecimalNumber(decimal: decimal))!
    }
    
    private func addLabels() {
        let labelHeight: CGFloat = 12.0
        let labelSize: CGFloat = 11.0
        
        // side labels
        for i in 0...(maxHorizontalLines - 1) {
            let padding: CGFloat = 4.0
            let label = UILabel(frame: CGRect(x: labelsAlignment == .left ? 0.0 : bounds.width - graphLayer.padding.right + padding,
                                              y: graphLayer.graphHeight/CGFloat((maxHorizontalLines - 1))*CGFloat(maxHorizontalLines - 1 - i) + graphLayer.padding.top - labelHeight/2,
                                              width: labelsAlignment == .left ? graphLayer.padding.left - padding : graphLayer.padding.right - padding,
                                              height: labelHeight))
            
            let value = (1.0 / Double(maxHorizontalLines - 1) * Double(i) ) * (graphPoints.max()! - graphPoints.min()!) + graphPoints.min()!
            label.text = "\(formatValue(value))"
            label.font = label.font.withSize(labelSize)
            label.textColor = labelsTextColor
            label.textAlignment = labelsAlignment == .left ? .left : .right
            addSubview(label)
        }
        
        //bottom labels
        if let graphColumnNames = graphColumnNames {
            bottomLabels = [UILabel]()
            
            let pointY = graphLayer.bounds.height - graphLayer.padding.bottom/2
            for i in 0..<graphLayer.graphPoints.count {
                let pointX = graphLayer.columnXPoint(column: i)
                
                let label = UILabel(frame: CGRect(x: pointX - graphLayer.padding.left/2,
                                                  y: pointY - labelHeight/2,
                                                  width: labelsAlignment == .left ? graphLayer.padding.left : graphLayer.padding.right,
                                                  height: labelHeight))
                label.text = String(describing: graphColumnNames[i])
                label.font = label.font.withSize(labelSize)
                label.textColor = fontColor
                label.textAlignment = .center
                addSubview(label)
                
                bottomLabels.append(label)
            }
        }
    }
    
    private func drawDots() {
        for i in 0..<graphLayer.graphPoints.count {
            var point = CGPoint(x: graphLayer.columnXPoint(column: i),
                                y: graphLayer.columnYPoint(graphPoint: graphLayer.graphPoints[i]))
            point.x -= 5.0/2
            point.y -= 5.0/2
            
            let circle = UIBezierPath(ovalIn: CGRect(origin: point,
                                                     size: CGSize(width: 5.0, height: 5.0)))
            let circleLayer = dotsLayer[i]
            circleLayer.path = circle.cgPath
            circleLayer.fillColor = fontColor.cgColor
        }
    }
    
    override func draw(_ rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()
        let colors = [startColor.cgColor, endColor.cgColor] as CFArray
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        let colorLocation: [CGFloat] = [0.0, 1.0]
        
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: colorLocation)
        
        let startPoint = CGPoint.zero
        let endPoint = CGPoint(x: 0, y: bounds.size.height)
        
        context!.drawLinearGradient(gradient!,
                                    start: startPoint,
                                    end: endPoint,
                                    options: CGGradientDrawingOptions(rawValue: 0))
    }
    
}
