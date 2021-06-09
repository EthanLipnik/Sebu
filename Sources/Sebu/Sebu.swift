import Foundation

public class Sebu {
    public static let cachePath = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("Sebu")
    public static let encoder = JSONEncoder()
    public static let decoder = JSONDecoder()
    
    private struct Object<T: Codable>: Codable {
        var expires: Date? = nil
        var object: T
        
        init(expires: Date? = nil, object: T) {
            self.expires = expires
            self.object = object
        }
        
        func encoded() throws -> Data {
            try Sebu.encoder.encode(self)
        }
    }
    
    public class func save<T: Codable>(_ object: T, withName name: String, expiration: Date? = nil) throws {
        try Sebu.checkForDirectory()
        
        try Object(expires: expiration, object: object)
            .encoded()
            .write(to: Sebu.cachePath.appendingPathComponent(name))
    }
    
    public class func `get`<T: Codable>(withName name: String, shouldBypassCache bypassCache: Bool = false) throws -> T? {
        let object = try Sebu.decoder
            .decode(Object<T>.self, from: Data(contentsOf: Sebu.cachePath.appendingPathComponent(name)))
        
        if bypassCache {
            return object.object
        } else if let expires = object.expires, expires > Date() {
            return object.object
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
    }
    
    private class func checkForDirectory() throws {
        if !FileManager.default.fileExists(atPath: Sebu.cachePath.path) {
            try FileManager.default.createDirectory(at: Sebu.cachePath, withIntermediateDirectories: true, attributes: nil)
        }
    }
}
