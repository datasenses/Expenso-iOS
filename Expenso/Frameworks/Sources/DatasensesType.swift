//
//  DatasensesType.swift
//  Datasenses
//
//  Created by Duc Nguyen on 12/3/24.
//  Copyright © 2024 Datasenses. All rights reserved.
//

import Foundation

/// Property keys must be String objects and the supported value types need to conform to DatasensesType.
/// DatasensesType can be either String, Int, UInt, Double, Float, Bool, [DatasensesType], [String: DatasensesType], Date, URL, or NSNull.
/// Numbers are not NaN or infinity
public protocol DatasensesType: Any {
    /**
     Checks if this object has nested object types that Datasenses supports.
     */
    func isValidNestedTypeAndValue() -> Bool
    
    func equals(rhs: DatasensesType) -> Bool
}

extension Optional: DatasensesType {
    /**
     Checks if this object has nested object types that Datasenses supports.
     */
    public func isValidNestedTypeAndValue() -> Bool {
        guard let val = self else { return true } // nil is valid
        switch val {
        case let v as DatasensesType:
            return v.isValidNestedTypeAndValue()
        default:
            // non-nil but cannot be unwrapped to DatasensesType
            return false
        }
    }
    
    public func equals(rhs: DatasensesType) -> Bool {
        if let v = self as? String, rhs is String {
            return v == rhs as! String
        } else if let v = self as? NSString, rhs is NSString {
            return v == rhs as! NSString
        } else if let v = self as? NSNumber, rhs is NSNumber {
            return v.isEqual(to: rhs as! NSNumber)
        } else if let v = self as? Int, rhs is Int {
            return v == rhs as! Int
        } else if let v = self as? UInt, rhs is UInt {
            return v == rhs as! UInt
        } else if let v = self as? Double, rhs is Double {
            return v == rhs as! Double
        } else if let v = self as? Float, rhs is Float {
            return v == rhs as! Float
        } else if let v = self as? Bool, rhs is Bool {
            return v == rhs as! Bool
        } else if let v = self as? Date, rhs is Date {
            return v == rhs as! Date
        } else if let v = self as? URL, rhs is URL {
            return v == rhs as! URL
        } else if self is NSNull && rhs is NSNull {
            return true
        }
        return false
    }
}
extension String: DatasensesType {
    /**
     Checks if this object has nested object types that Datasenses supports.
     Will always return true.
     */
    public func isValidNestedTypeAndValue() -> Bool { return true }
    
    public func equals(rhs: DatasensesType) -> Bool {
        if rhs is String {
            return self == rhs as! String
        }
        return false
    }
}

extension NSString: DatasensesType {
    /**
     Checks if this object has nested object types that Datasenses supports.
     Will always return true.
     */
    public func isValidNestedTypeAndValue() -> Bool { return true }
    
    public func equals(rhs: DatasensesType) -> Bool {
        if rhs is NSString {
            return self == rhs as! NSString
        }
        return false
    }
}

extension NSNumber: DatasensesType {
    /**
     Checks if this object has nested object types that Datasenses supports.
     Will always return true.
     */
    public func isValidNestedTypeAndValue() -> Bool {
        return !self.doubleValue.isInfinite && !self.doubleValue.isNaN
    }
    
    public func equals(rhs: DatasensesType) -> Bool {
        if rhs is NSNumber {
            return self.isEqual(rhs)
        }
        return false
    }
}

extension Int: DatasensesType {
    /**
     Checks if this object has nested object types that Datasenses supports.
     Will always return true.
     */
    public func isValidNestedTypeAndValue() -> Bool { return true }
    
    public func equals(rhs: DatasensesType) -> Bool {
        if rhs is Int {
            return self == rhs as! Int
        }
        return false
    }
}

extension UInt: DatasensesType {
    /**
     Checks if this object has nested object types that Datasenses supports.
     Will always return true.
     */
    public func isValidNestedTypeAndValue() -> Bool { return true }
    
    public func equals(rhs: DatasensesType) -> Bool {
        if rhs is UInt {
            return self == rhs as! UInt
        }
        return false
    }
}
extension Double: DatasensesType {
    /**
     Checks if this object has nested object types that Datasenses supports.
     Will always return true.
     */
    public func isValidNestedTypeAndValue() -> Bool {
        return !self.isInfinite && !self.isNaN
    }
    
    public func equals(rhs: DatasensesType) -> Bool {
        if rhs is Double {
            return self == rhs as! Double
        }
        return false
    }
}
extension Float: DatasensesType {
    /**
     Checks if this object has nested object types that Datasenses supports.
     Will always return true.
     */
    public func isValidNestedTypeAndValue() -> Bool {
        return !self.isInfinite && !self.isNaN
    }
    
    public func equals(rhs: DatasensesType) -> Bool {
        if rhs is Float {
            return self == rhs as! Float
        }
        return false
    }
}
extension Bool: DatasensesType {
    /**
     Checks if this object has nested object types that Datasenses supports.
     Will always return true.
     */
    public func isValidNestedTypeAndValue() -> Bool { return true }
    
    public func equals(rhs: DatasensesType) -> Bool {
        if rhs is Bool {
            return self == rhs as! Bool
        }
        return false
    }
}

extension Date: DatasensesType {
    /**
     Checks if this object has nested object types that Datasenses supports.
     Will always return true.
     */
    public func isValidNestedTypeAndValue() -> Bool { return true }
    
    public func equals(rhs: DatasensesType) -> Bool {
        if rhs is Date {
            return self == rhs as! Date
        }
        return false
    }
}

extension URL: DatasensesType {
    /**
     Checks if this object has nested object types that Datasenses supports.
     Will always return true.
     */
    public func isValidNestedTypeAndValue() -> Bool { return true }
    
    public func equals(rhs: DatasensesType) -> Bool {
        if rhs is URL {
            return self == rhs as! URL
        }
        return false
    }
}

extension NSNull: DatasensesType {
    /**
     Checks if this object has nested object types that Datasenses supports.
     Will always return true.
     */
    public func isValidNestedTypeAndValue() -> Bool { return true }
    
    public func equals(rhs: DatasensesType) -> Bool {
        if rhs is NSNull {
            return true
        }
        return false
    }
}

extension Array: DatasensesType {
    /**
     Checks if this object has nested object types that Datasenses supports.
     */
    public func isValidNestedTypeAndValue() -> Bool {
        for element in self {
            guard let _ = element as? DatasensesType else {
                return false
            }
        }
        return true
    }
    
    public func equals(rhs: DatasensesType) -> Bool {
        if rhs is [DatasensesType] {
            let rhs = rhs as! [DatasensesType]
            
            if self.count != rhs.count {
                return false
            }
            
            if !isValidNestedTypeAndValue() {
                return false
            }
            
            let lhs = self as! [DatasensesType]
            for (i, val) in lhs.enumerated() {
                if !val.equals(rhs: rhs[i]) {
                    return false
                }
            }
            return true
        }
        return false
    }
}

extension NSArray: DatasensesType {
    /**
     Checks if this object has nested object types that Datasenses supports.
     */
    public func isValidNestedTypeAndValue() -> Bool {
        for element in self {
            guard let _ = element as? DatasensesType else {
                return false
            }
        }
        return true
    }
    
    public func equals(rhs: DatasensesType) -> Bool {
        if rhs is [DatasensesType] {
            let rhs = rhs as! [DatasensesType]
            
            if self.count != rhs.count {
                return false
            }
            
            if !isValidNestedTypeAndValue() {
                return false
            }
            
            let lhs = self as! [DatasensesType]
            for (i, val) in lhs.enumerated() {
                if !val.equals(rhs: rhs[i]) {
                    return false
                }
            }
            return true
        }
        return false
    }
}

extension Dictionary: DatasensesType {
    /**
     Checks if this object has nested object types that Datasenses supports.
     */
    public func isValidNestedTypeAndValue() -> Bool {
        for (key, value) in self {
            guard let _ = key as? String, let _ = value as? DatasensesType else {
                return false
            }
        }
        return true
    }
    
    public func equals(rhs: DatasensesType) -> Bool {
        if rhs is [String: DatasensesType] {
            let rhs = rhs as! [String: DatasensesType]
            
            if self.keys.count != rhs.keys.count {
                return false
            }
            
            if !isValidNestedTypeAndValue() {
                return false
            }
            
            for (key, val) in self as! [String: DatasensesType] {
                guard let rVal = rhs[key] else {
                    return false
                }
                
                if !val.equals(rhs: rVal) {
                    return false
                }
            }
            return true
        }
        return false
    }
}

func assertPropertyTypes(_ properties: Properties?) {
    if let properties = properties {
        for (_, v) in properties {
            DSAssert(v.isValidNestedTypeAndValue(),
                     "Property values must be of valid type (DatasensesType) and valid value. Got \(type(of: v)) and Value \(v)")
        }
    }
}

extension Dictionary {
    func get<T>(key: Key, defaultValue: T) -> T {
        if let value = self[key] as? T {
            return value
        }
        
        return defaultValue
    }
}
