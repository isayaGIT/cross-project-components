// Adapted from c-villain/Shapes, BubbleBottomRight.swift.
// Copyright (c) 2023 Alexander Kraev. Licensed under the MIT License.
// See LICENSE in this directory for the full license text.

import SwiftUI

public struct BubbleBottomRight: Shape {

    var cornerRadius: CGFloat = 0.0
    var tail: (width: CGFloat, height: CGFloat) = (6, 17)
    
    public func path(in rect: CGRect) -> Path {
        Path { path in
            
            let rectDime = min(rect.height, rect.width)
            let pathRadius = cornerRadius >= rectDime / 2 ? rectDime / 2 : cornerRadius
            let pathTail: (width: CGFloat, height: CGFloat) = (tail.width, tail.height > rect.height ? rect.height : tail.height)
            
            // init point
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            
            // top line:
            path.addLine(to: .init(x: rect.maxX - pathRadius,
                                   y: rect.minY))
            
            // calculating the apex:
            let delta = rect.height - pathTail.height
            
            if delta > pathRadius {
                // add round corner on top right:
                path.addQuadCurve(to: CGPoint(x: rect.maxX,
                                              y: rect.minY + pathRadius),
                                  control: CGPoint(x: rect.maxX,
                                                   y: rect.minY))
                
                // right line:
                path.addLine(to: .init(x: rect.maxX,
                                       y: rect.maxY - (pathTail.width > 0 ? pathTail.height : pathRadius)))

                
            } else {
                path.addQuadCurve(to: CGPoint(x: rect.maxX,
                                              y: rect.minY + delta),
                                  control: CGPoint(x: rect.maxX,
                                                   y: rect.minY))
            }

            // tail:
            if pathTail.width > 0 {
                path.addCurve(to: CGPoint(x: rect.maxX + pathTail.width,
                                          y: rect.maxY),
                              control1: CGPoint(x: rect.maxX,
                                                y: rect.maxY),
                              control2: CGPoint(x: pathTail.width > 0 ? rect.maxX + 2 * pathTail.width : rect.maxX,
                                                y: rect.maxY))
                
                path.addQuadCurve(to: CGPoint(x: rect.maxX - pathRadius / 3,
                                              y: pathTail.width > 0 ? rect.maxY - pathRadius / (3 * tan (45.0)) : rect.maxY),
                                  control: CGPoint(x: rect.maxX,
                                                   y: rect.maxY))
            }
            
            //add round corner bottom right:
            path.addQuadCurve(to: CGPoint(x: rect.maxX - pathRadius,
                                          y: rect.maxY),
                              control: CGPoint(x: pathTail.width > 0 ? rect.maxX - pathRadius / 2 : rect.maxX,
                                               y: rect.maxY))
            
            // bottom line
            path.addLine(to: .init(x: rect.minX + pathRadius,
                                   y: rect.maxY))
            
            //add round corner bottom left:
            path.addQuadCurve(to: CGPoint(x: rect.minX,
                                          y: rect.maxY - pathRadius),
                              control: CGPoint(x: rect.minX,
                                               y: rect.maxY))
            
            //left line
            path.addLine(to: .init(x: rect.minX,
                                   y: rect.minY + pathRadius))
            
            //add round corner top left:
            path.addQuadCurve(to: CGPoint(x: rect.minX + pathRadius,
                                          y: rect.minY),
                              control: CGPoint(x: rect.minX,
                                               y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        }
    }
}

