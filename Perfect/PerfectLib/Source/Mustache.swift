//
//  Mustache.swift
//  PerfectLib
//
//  Created by Riven on 16/4/21.
//  Copyright © 2016年 Riven. All rights reserved.
//

import ICU

let mustacheExtension = "mustache"

enum MustacheTagType {
    case Plain // plain text
    case Tag // some tag. not sure which ye
    case Hash
    case Slash
    case Amp
    case Caret
    case Bang
    case Partial
    case Delims
    case UnescapedName
    case Name
    case UnencodedName
    case Pragma
    case None
}

/// This enum type represents the parsing and the runtime evaluation exceptions which may be generated.
public enum MustacheError: ErrorType {
    /// The mustache template was malformed.
    case SyntaxError(String)
    /// An exception occurred while evaluating the template
    case EvaluationError(String)
}

/// This class represents an individual scope for mustache template values.
/// A mustache template handler will return a `MustacheEvaluationContext.MapType` object as a result from its `PageHandler.valuesForResponse` function
public class MustacheEvaluationContext {
    public typealias MapType = Dictionary<String, Any>
    public typealias SequenceType = Array<MapType>
    
    /// The parent of this context
    public var parent: MustacheEvaluationContext? = nil
    /// Provides access to the current WebResponse object
}
