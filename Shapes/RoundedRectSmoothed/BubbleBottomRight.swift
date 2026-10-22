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
            path.move(to: CGPoint(x: rect.width/2, y: rect.minY))
            
            // top line:
            path.addLine(to: .init(x: rect.width - pathRadius,
                                   y: rect.minY))
            
            // calculating the apex:
            let delta = rect.height - pathTail.height
            
            if delta > pathRadius {
                // add round corner on top right:
                path.addQuadCurve(to: CGPoint(x: rect.width,
                                              y: pathRadius),
                                  control: CGPoint(x: rect.width,
                                                   y: rect.minY))
                
                // right line:
                path.addLine(to: .init(x: rect.width,
                                       y: rect.height - (pathTail.width > 0 ? pathTail.height : pathRadius)))

                
            } else {
                path.addQuadCurve(to: CGPoint(x: rect.width,
                                              y: delta),
                                  control: CGPoint(x: rect.width,
                                                   y: rect.minY))
            }

            // tail:
            if pathTail.width > 0 {
                path.addCurve(to: CGPoint(x: rect.width + pathTail.width,
                                          y: rect.height),
                              control1: CGPoint(x: rect.width,
                                                y: rect.height),
                              control2: CGPoint(x: pathTail.width > 0 ? rect.width + 2 * pathTail.width : rect.width,
                                                y: rect.height))
                
                path.addQuadCurve(to: CGPoint(x: rect.width - Double(pathRadius / 3),
                                              y: pathTail.width > 0 ? rect.height - pathRadius / (3 * tan (45.0)) : rect.height),
                                  control: CGPoint(x: rect.width,
                                                   y: rect.height))
            }
            
            //add round corner bottom right:
            path.addQuadCurve(to: CGPoint(x: rect.width - pathRadius,
                                          y: rect.height),
                              control: CGPoint(x: pathTail.width > 0 ? rect.width - pathRadius / 2 : rect.width,
                                               y: rect.height))
            
            // bottom line
            path.addLine(to: .init(x: pathRadius,
                                   y: rect.height))
            
            //add round corner bottom left:
            path.addQuadCurve(to: CGPoint(x: rect.minX,
                                          y: rect.height - pathRadius),
                              control: CGPoint(x: rect.minX,
                                               y: rect.height))
            
            //left line
            path.addLine(to: .init(x: rect.minX,
                                   y: pathRadius))
            
            //add round corner top left:
            path.addQuadCurve(to: CGPoint(x: pathRadius,
                                          y: rect.minY),
                              control: CGPoint(x: rect.minX,
                                               y: rect.minY))
            path.addLine(to: CGPoint(x: rect.width / 2, y: rect.minY))
        }
    }
}

