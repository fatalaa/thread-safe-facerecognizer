//: Playground - noun: a place where people can play

import UIKit
import PlaygroundSupport

public struct Settings {}

public struct Result {}

public class RecognitionAlgorithm {
    func apply(settings: Settings) {}
    
    func process(image: UIImage) -> Result {
        let result = Result()
        
        return result
    }
}

public protocol Listener: class {
    func faceRecognizer(_ faceRecognizer: FaceRecognizer,
                        didProcess frame: UIImage,
                        result: Result)
}

public protocol FaceRecognizer {
    
    /// Add a listener
    func add(listener: Listener)
    
    /// Remove a listener
    func remove(listener: Listener)
    
    /// The setter applies the recognitionSettings to the RecognitionAlgorithm.
    var recognitionSettings: Settings { get set }
    
    /// Process a frame and invokes the listeners on the specified queue.
    ///
    /// - parameter frame: The frame to process.
    /// - parameter completionQueue: The queue on which the listeners are invoked.
    func process(frame: UIImage, completionQueue: DispatchQueue)
}

class DefaultFaceRecognizer: FaceRecognizer {
    
    /// Generic purpose wrapper object to have isEqual on structs, protocols types and
    /// non NSObject based classes without implementing Equatable.
    private class Wrapper<T>: NSObject {
        let wrappedValue: T
        
        init(with wrappable: T) {
            wrappedValue = wrappable
        }
    }
    
    // Creating an algorithm instance is not cost effective, so it's created lazily.
    private lazy var algorithm: RecognitionAlgorithm = {
        let algorithm = RecognitionAlgorithm()
        return algorithm
    }()
    
    init(with cacheSize: Int = 20, recognitionSettings: Settings, queue: DispatchQueue = DispatchQueue(label: "RecognitionQueue", qos: .background, attributes: .concurrent)) {
        computedFrames = NSCache()
        computedFrames.countLimit = cacheSize
        recognitionQueue = queue
        currentSettings = Wrapper(with: recognitionSettings)
        self.recognitionSettings = recognitionSettings
    }
    
    private var listeners: [Wrapper<Listener>] = []
    
    private var previousSettings: Wrapper<Settings>?
    private var currentSettings: Wrapper<Settings>
    
    var recognitionSettings: Settings {
        get {
            return currentSettings.wrappedValue
        }
        set {
            let wrapped = Wrapper(with: newValue)
            if !wrapped.isEqual(currentSettings) {
                previousSettings = currentSettings
                currentSettings = wrapped
            }
        }
    }
    
    // NSCache is more suitable than a Dictionary(You can specify the maximum number of stored items, etc.)
    private var computedFrames: NSCache<UIImage, Wrapper<Result>>
    private let recognitionQueue: DispatchQueue
    
    func add(listener: Listener) {
        listeners.append(Wrapper(with: listener))
    }
    
    func remove(listener: Listener) {
        if let index = listeners.index(where: { $0.isEqual(Wrapper(with: listener)) }) {
            listeners.remove(at: index)
        }
    }
    
    func process(frame: UIImage, completionQueue: DispatchQueue) {
        // Let's check if we already computed the result for the given frame.
        if let result = computedFrames.object(forKey: frame) {
            completionQueue.sync {
                listeners.forEach {
                    $0.wrappedValue.faceRecognizer(self, didProcess: frame, result: result.wrappedValue)
                }
            }
            return
        }
        // Using barrier will block the queue until the algorithm finishes, and the listeners are notified.
        recognitionQueue.sync(flags: .barrier) {
            // Check if we have to apply new settings to the algorithm
            if let settings = previousSettings, !settings.isEqual(currentSettings) {
                algorithm.apply(settings: currentSettings.wrappedValue)
            }
            let result = algorithm.process(image: frame)
            completionQueue.sync {
                listeners.forEach {
                    $0.wrappedValue.faceRecognizer(self, didProcess: frame, result: result)
                }
            }
        }
    }
}



















