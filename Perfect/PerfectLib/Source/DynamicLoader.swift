//
//  DynamicLoader.swift
//  PerfectLib
//
//  Created by Riven on 16/4/14.
//  Copyright © 2016年 Riven. All rights reserved.
//

#if os(Linux)
    import SwiftGlibc
#else
    import Darwin
#endif

class DynamicLoader {
    // sketchy! PerfectServerModuleInit is not defined as convention(c)
    // but it does not seem to matter provided it is Void->Void
    // I am unsure on how to convert a void* to a legit Swift ()->() func
    typealias InitFunction = @convention(c) () -> ()
    let initFuncName = "PerfectServerModeleInit"
    init() { }
    
    func loadFramework(atPath: String) -> Bool {
        let resolvedPath = atPath.stringByResolvingSymlinksInPath
        let moduleName = resolvedPath.lastPathComponent.stringByDeletingPathExtension
        let file = File(resolvedPath + "/" + moduleName)
        if file.exists() {
            let realPath = file.realPath()
            return self.loadRealPath(realPath, moduleName: moduleName)
        }
        
        return false
    }
    
    func loadLibrary(atPath: String) -> Bool {
        let resolvedPath = atPath.stringByResolvingSymlinksInPath
        let moduleName = resolvedPath.lastPathComponent.stringByDeletingPathExtension
        let file = File(resolvedPath)
        if file.exists() {
            let realPath = file.realPath()
            return self.loadRealPath(realPath, moduleName: moduleName)
        }
        return false
    }
    
    private func loadRealPath(realPath: String, moduleName: String) -> Bool {
        let openRes = dlopen(realPath, RTLD_NOW|RTLD_LOCAL)
        if openRes != nil {
            // this is fragile
            let newModuleName = moduleName.stringByReplacingString("-", withString: "_").stringByReplacingString(" ", withString: "_")
            let symbolName = "_TF\(newModuleName.utf8.count)\(newModuleName)\(initFuncName.utf8.count)\(initFuncName)FT_T_"
            let sym = dlsym(openRes, symbolName)
            if sym != nil {
                let f: InitFunction = unsafeBitCast(sym, InitFunction.self)
                f()
                dlclose(openRes)
                return true
            }
            else {
                print("Error loading \(realPath). Symbol \(symbolName) not found.")
                dlclose(openRes)
            }
        }
        else {
            print("Errno \(String.fromCString(dlerror())!)")
        }
        return false
    }
}
