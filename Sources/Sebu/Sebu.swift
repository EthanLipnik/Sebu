import Foundation

public class Sebu {
    public static let cachePath = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("Sebu")
    public static let encoder = JSONEncoder()
    public static let decoder = JSONDecoder()
    
    private static var cacheInfo = Sebu.CacheInfo() {
        didSet {
            do {
                try Sebu.encoder
                    .encode(cacheInfo)
                    .write(to: Sebu.cachePath.appendingPathComponent("CacheInfo"))
            } catch {
                print(error)
            }
        }
    }
    
    private struct CacheInfo: Codable {
        var objects: [Object]
        
        init(objects: [Object]) {
            self.objects = objects
        }
        
        init(path: URL = Sebu.cachePath.appendingPathComponent("CacheInfo")) {
            if let cacheInfo = try? Sebu.decoder.decode(CacheInfo.self, from: Data(contentsOf: path)) {
                self.objects = cacheInfo.objects
            } else {
                self.objects = []
            }
        }
        
        struct Object: Codable {
            var name: String
            var expiration: Date?
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
    
    public class func save<T: Codable>(_ object: T, withName name: String, expiration: Date? = nil) throws {
        try Sebu.checkForDirectory()
        
        try Sebu.encoder
            .encode(object)
            .write(to: Sebu.cachePath.appendingPathComponent(name))
        cacheInfo[name] = .init(name: name, expiration: expiration)
    }
    
    public class func `get`<T: Codable>(withName name: String, shouldBypassExpiration bypassExpiration: Bool = false) throws -> T? {
        
        let object = try Sebu.decoder
            .decode(T.self, from: Data(contentsOf: Sebu.cachePath.appendingPathComponent(name)))
        
        if bypassExpiration {
            return object
        } else if let expires = cacheInfo[name]?.expiration, expires > Date() {
            return object
        } else {
            return nil
        }
    }
    
    public class func clearAll() throws {
        try FileManager.default.removeItem(at: Sebu.cachePath)
        try FileManager.default.createDirectory(at: Sebu.cachePath, withIntermediateDirectories: true, attributes: nil)
    }
    
    public class func clear(_ name: String) throws {
        try FileManager.default.removeItem(at: Sebu.cachePath.appendingPathComponent(name))
        cacheInfo.removeObject(name)
    }
    
    public class func purgeOutdated() throws {
        let expiredObjects = cacheInfo.objects
            .filter({ $0.expiration != nil })
            .filter({ $0.expiration! < Date() })
        
        try expiredObjects.forEach({ try clear($0.name) })
    }
    
    private class func checkForDirectory() throws {
        if !FileManager.default.fileExists(atPath: Sebu.cachePath.path) {
            try FileManager.default.createDirectory(at: Sebu.cachePath, withIntermediateDirectories: true, attributes: nil)
        }
    }
}
