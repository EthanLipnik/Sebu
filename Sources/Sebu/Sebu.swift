import Foundation

public class Sebu {
    public static let `default` = Sebu()
    
    public static let defaultCachePath = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("Sebu")
    public let cachePath: URL
    
    public static let encoder = JSONEncoder()
    public static let decoder = JSONDecoder()
    
    public init(_ cachePath: URL = Sebu.defaultCachePath) {
        self.cachePath = cachePath
    }
    
    private var cacheInfo = Sebu.CacheInfo() {
        didSet {
            do {
                try Sebu.encoder
                    .encode(cacheInfo)
                    .write(to: cachePath.appendingPathComponent("CacheInfo"))
            } catch {
                print(error)
            }
        }
    }
    
    private var nsCache = NSCache<NSString, AnyObject>()
    
    private struct CacheInfo: Codable {
        var objects: [Object]
        
        init(objects: [Object]) {
            self.objects = objects
        }
        
        init(path: URL = Sebu.defaultCachePath.appendingPathComponent("CacheInfo")) {
            if let cacheInfo = try? Sebu.decoder.decode(CacheInfo.self, from: Data(contentsOf: path)) {
                self.objects = cacheInfo.objects
            } else {
                self.objects = []
            }
        }
        
        struct Object: Codable {
            var name: String
            var expiration: Date?
            
            var isExpired: Bool {
                return expiration != nil ? (expiration! < Date()) : false
            }
        }
        
        subscript(name: String) -> Object? {
            get {
                return objects.last(where: { $0.name == name })
            }
            set {
                if let index = objects.lastIndex(where: { $0.name == name }) {
                    
                    if let value = newValue {
                        objects[index] = value
                    } else {
                        objects.remove(at: index)
                    }
                } else if let value = newValue {
                    objects.append(value)
                }
            }
        }
        
        mutating func removeObject(_ name: String) {
            guard let index = objects.lastIndex(where: { $0.name == name }) else { return }
            objects.remove(at: index)
        }
    }
    
    //    private struct Object<T: Codable>: Codable {
    //        var expires: Date? = nil
    //        var object: T
    //
    //        init(expires: Date? = nil, object: T) {
    //            self.expires = expires
    //            self.object = object
    //        }
    //
    //        func encoded() throws -> Data {
    //            try Sebu.encoder.encode(self)
    //        }
    //    }
    
    public func save<T: Codable>(_ object: T, withName name: String, expiration: Date? = nil) throws {
        try checkForDirectory()
        
        try Sebu.encoder
            .encode(object)
            .write(to: cachePath.appendingPathComponent(name))
        cacheInfo[name] = .init(name: name, expiration: expiration)
        
        nsCache.setObject(object as AnyObject, forKey: name as NSString)
    }
    
    public func `get`<T: Codable>(withName name: String, shouldBypassExpiration bypassExpiration: Bool = false) throws -> T? {
        
        let isExpired = cacheInfo[name]?.isExpired ?? true
        
        if let cache = nsCache.object(forKey: name as NSString) as? T, (bypassExpiration || !isExpired) {
            return cache
        }
        
        let object = try Sebu.decoder
            .decode(T.self, from: Data(contentsOf: cachePath.appendingPathComponent(name)))
        
        if bypassExpiration || !isExpired {
            return object
        } else {
            return nil
        }
    }
    
    public func hasObject(withName name: String, shouldCheckExpiration checksExpiration: Bool = true) -> Bool {
        return cacheInfo.objects.contains(where: { $0.name == name && (checksExpiration ? !$0.isExpired : true) })
    }
    
    public func clearAll() throws {
        try FileManager.default.removeItem(at: cachePath)
        try FileManager.default.createDirectory(at: cachePath, withIntermediateDirectories: true, attributes: nil)
    }
    
    public func clear(_ name: String) throws {
        try FileManager.default.removeItem(at: cachePath.appendingPathComponent(name))
        cacheInfo.removeObject(name)
    }
    
    public func purgeOutdated() throws {
        let expiredObjects = cacheInfo.objects
            .filter({ $0.expiration != nil })
            .filter({ $0.expiration! < Date() })
        
        try expiredObjects.forEach({ try clear($0.name) })
    }
    
    public func getSize() throws -> Int? {
        return try cachePath.directoryTotalAllocatedSize()
    }
    
    private func checkForDirectory() throws {
        if !FileManager.default.fileExists(atPath: cachePath.path) {
            try FileManager.default.createDirectory(at: cachePath, withIntermediateDirectories: true, attributes: nil)
        }
    }
}

fileprivate extension URL {
    /// check if the URL is a directory and if it is reachable
    func isDirectoryAndReachable() throws -> Bool {
        guard try resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else {
            return false
        }
        return try checkResourceIsReachable()
    }

    /// returns total allocated size of a the directory including its subFolders or not
    func directoryTotalAllocatedSize(includingSubfolders: Bool = false) throws -> Int? {
        guard try isDirectoryAndReachable() else { return nil }
        if includingSubfolders {
            guard
                let urls = FileManager.default.enumerator(at: self, includingPropertiesForKeys: nil)?.allObjects as? [URL] else { return nil }
            return try urls.lazy.reduce(0) {
                    (try $1.resourceValues(forKeys: [.totalFileAllocatedSizeKey]).totalFileAllocatedSize ?? 0) + $0
            }
        }
        return try FileManager.default.contentsOfDirectory(at: self, includingPropertiesForKeys: nil).lazy.reduce(0) {
                 (try $1.resourceValues(forKeys: [.totalFileAllocatedSizeKey])
                    .totalFileAllocatedSize ?? 0) + $0
        }
    }
}
