import CoreFoundation
import Darwin
import Foundation

typealias MTDeviceRef = UnsafeMutableRawPointer
typealias MTContactFrameCallback = @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, Int32, Double, Int32) -> Void

private typealias MTDeviceCreateDefaultFunction = @convention(c) () -> MTDeviceRef?
private typealias MTDeviceCreateListFunction = @convention(c) () -> Unmanaged<CFArray>?
private typealias MTDeviceStartFunction = @convention(c) (MTDeviceRef, Int32) -> Void
private typealias MTDeviceStopFunction = @convention(c) (MTDeviceRef) -> Void
private typealias MTDeviceReleaseFunction = @convention(c) (MTDeviceRef) -> Void
private typealias MTRegisterContactFrameCallbackFunction = @convention(c) (MTDeviceRef, MTContactFrameCallback) -> Void
private typealias MTUnregisterContactFrameCallbackFunction = @convention(c) (MTDeviceRef, MTContactFrameCallback) -> Void

final class MultitouchFramework {
    private static let frameworkPaths = [
        "/System/Library/PrivateFrameworks/MultitouchSupport.framework/Versions/Current/MultitouchSupport",
        "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport",
    ]

    private let handle: UnsafeMutableRawPointer
    private let createDefaultImpl: MTDeviceCreateDefaultFunction
    private let createListImpl: MTDeviceCreateListFunction
    private let startImpl: MTDeviceStartFunction
    private let stopImpl: MTDeviceStopFunction
    private let releaseImpl: MTDeviceReleaseFunction
    private let registerImpl: MTRegisterContactFrameCallbackFunction
    private let unregisterImpl: MTUnregisterContactFrameCallbackFunction

    init?() {
        guard let handle = Self.frameworkPaths.lazy.compactMap({ dlopen($0, RTLD_NOW) }).first else {
            return nil
        }

        guard let createDefault = MultitouchFramework.loadSymbol(named: "MTDeviceCreateDefault", from: handle, as: MTDeviceCreateDefaultFunction.self),
              let createList = MultitouchFramework.loadSymbol(named: "MTDeviceCreateList", from: handle, as: MTDeviceCreateListFunction.self),
              let start = MultitouchFramework.loadSymbol(named: "MTDeviceStart", from: handle, as: MTDeviceStartFunction.self),
              let stop = MultitouchFramework.loadSymbol(named: "MTDeviceStop", from: handle, as: MTDeviceStopFunction.self),
              let release = MultitouchFramework.loadSymbol(named: "MTDeviceRelease", from: handle, as: MTDeviceReleaseFunction.self),
              let register = MultitouchFramework.loadSymbol(named: "MTRegisterContactFrameCallback", from: handle, as: MTRegisterContactFrameCallbackFunction.self),
              let unregister = MultitouchFramework.loadSymbol(named: "MTUnregisterContactFrameCallback", from: handle, as: MTUnregisterContactFrameCallbackFunction.self) else {
            dlclose(handle)
            return nil
        }

        self.handle = handle
        createDefaultImpl = createDefault
        createListImpl = createList
        startImpl = start
        stopImpl = stop
        releaseImpl = release
        registerImpl = register
        unregisterImpl = unregister
    }

    deinit {
        dlclose(handle)
    }

    func createDefaultDevice() -> MTDeviceRef? {
        createDefaultImpl()
    }

    func deviceList() -> [MTDeviceRef] {
        guard let array = createListImpl()?.takeUnretainedValue() else {
            return []
        }

        let count = CFArrayGetCount(array)
        return (0..<count).compactMap { index in
            guard let pointer = CFArrayGetValueAtIndex(array, index) else {
                return nil
            }
            return UnsafeMutableRawPointer(mutating: pointer)
        }
    }

    func register(device: MTDeviceRef, callback: MTContactFrameCallback) {
        registerImpl(device, callback)
    }

    func unregister(device: MTDeviceRef, callback: MTContactFrameCallback) {
        unregisterImpl(device, callback)
    }

    func start(device: MTDeviceRef) {
        startImpl(device, 0)
    }

    func stop(device: MTDeviceRef) {
        stopImpl(device)
    }

    func release(device: MTDeviceRef) {
        releaseImpl(device)
    }

    private static func loadSymbol<T>(named name: String, from handle: UnsafeMutableRawPointer, as type: T.Type) -> T? {
        guard let symbol = dlsym(handle, name) else {
            return nil
        }
        return unsafeBitCast(symbol, to: type)
    }
}
