//
//  String.swift
//  LoosePhabric
//
//  Created by David Lynch on 1/24/25.
//

import Foundation

extension String {
    var htmlDecoded: String {
        let decoded = try? NSAttributedString(data: Data(utf8), options: [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ], documentAttributes: nil).string

        return decoded ?? self
    }

    var isNumeric: Bool {
        let digits = CharacterSet.decimalDigits
        let stringSet = CharacterSet(charactersIn: self)

        return digits.isSuperset(of: stringSet)
    }
}
