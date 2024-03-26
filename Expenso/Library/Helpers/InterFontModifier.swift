//
//  InterFontModifier.swift
//  Expenso
//
//  Created by Sameer Nawaz on 31/01/21.
//

import SwiftUI

enum InternalFontType: String {
    case bold = "Inter-Bold"
    case medium = "Inter-Medium"
    case regular = "Inter-Regular"
    case semiBold = "Inter-SemiBold"
}

struct InternalFont: ViewModifier {
    
    var weight: Font.Weight
    var size: CGFloat
    
    init(_ type: Font.Weight = .regular, size: CGFloat = 16) {
        self.weight = type
        self.size = size
    }
    
    func body(content: Content) -> some View {
        
        content.font(Font.system(size: size, weight:weight))
    }
}
