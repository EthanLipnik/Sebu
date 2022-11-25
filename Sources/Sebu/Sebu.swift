import Foundation

open class Sebu {
    /// Defaults to ``persistent``.
    public static let `default` = Sebu.persistent
    public static let persistent = Sebu(isPersistent: true)
    public static let memory = Sebu(isPersistent: false)

    public static let defaultCachePath = FileManager.default.urls(
        for: .cachesDirectory,
        in: .userDomainMask
    )[0].appendingPathComponent("Sebu")
    public let cachePath: URL

    public static let encoder = JSONEncoder()
    public static let decoder = JSONDecoder()

    private lazy var syncTask: Task<Void, Error>? = nil

    public let isPersistent: Bool

    public init(_ cachePath: URL = Sebu.defaultCachePath, isPersistent: Bool = true) {
        self.cachePath = cachePath
        self.isPersistent = isPersistent
    }

    private lazy var nsCache = NSCache<NSString, AnyObject>()
    private lazy var cacheInfo: CacheInfo = {
        var path: URL?

        if isPersistent {
            path = Sebu.defaultCachePath.appendingPathComponent("CacheInfo")
        }
        return Sebu.CacheInfo(path: path)
    }()

    private struct CacheInfo: Codable {
        var objects: [Object] = []

        init(objects: [Object]) {
            self.objects = objects
        }

        init(path: URL?) {
            if let path,
               let contents = FileManager.default.contents(atPath: path.path) {
                do {
                    let cacheInfo = try Sebu.decoder.decode(
                        CacheInfo.self,
                        from: contents
                    )
                    objects = cacheInfo.objects
                } catch {
                    Log(error.localizedDescription)
                }
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

    public func set<T: Codable>(
        _ object: T,
        withName name: String,
        expiration: Date? = nil
    ) throws {
        nsCache.setObject(object as AnyObject, forKey: name as NSString)
        cacheInfo[name] = .init(name: name, expiration: expiration)

        guard isPersistent else { return }
        try checkForDirectory()
        try Sebu.encoder
            .encode(object)
            .write(to: cachePath.appendingPathComponent(name))

        Task(priority: .background) {
            try? await sync()
        }
    }

    public func get<T: Codable>(
        withName name: String,
        shouldBypassExpiration bypassExpiration: Bool = false
    ) throws -> T? {
        let isExpired = cacheInfo[name]?.isExpired ?? true

        if let cache = nsCache.object(forKey: name as NSString) as? T,
           bypassExpiration || !isExpired
        {
            return cache
        }

        guard isPersistent else { throw CocoaError(.fileWriteNoPermission) }

        let object = try Sebu.decoder
            .decode(T.self, from: Data(contentsOf: cachePath.appendingPathComponent(name)))

        if bypassExpiration || !isExpired {
            return object
        } else {
            return nil
        }
    }

    public func hasObject(
        withName name: String,
        shouldCheckExpiration checksExpiration: Bool = true
    ) -> Bool {
        return cacheInfo.objects
            .contains(where: { $0.name == name && (checksExpiration ? !$0.isExpired : true) })
    }

    public func clearAll() throws {
        nsCache.removeAllObjects()

        guard isPersistent else { return }
        try FileManager.default.removeItem(at: cachePath)
        try FileManager.default.createDirectory(
            at: cachePath,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    public func clear(_ name: String) throws {
        cacheInfo.removeObject(name)

        guard isPersistent else { return }
        try FileManager.default.removeItem(at: cachePath.appendingPathComponent(name))

        Task(priority: .background) {
            try? await sync()
        }
    }

    /// Only neccesary for persistent  caches
    public func purgeOutdated() throws {
        let expiredObjects = cacheInfo.objects
            .filter { $0.expiration != nil }
            .filter { $0.expiration! < Date() }

        try expiredObjects.forEach { try clear($0.name) }
    }

    public func getSize() throws -> Int? {
        return try cachePath.directoryTotalAllocatedSize()
    }

    private func checkForDirectory() throws {
        if !FileManager.default.fileExists(atPath: cachePath.path) {
            try FileManager.default.createDirectory(
                at: cachePath,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }

    private func sync() async throws {
        guard isPersistent else { return }

        syncTask?.cancel()

        syncTask = Task(priority: .background) { [cacheInfo, cachePath] in
            try await Task.sleep(nanoseconds: 2_000_000_000)

            let path = cachePath.appendingPathComponent("CacheInfo").path
            let data = try Sebu.encoder.encode(cacheInfo)

            if !FileManager.default.fileExists(atPath: path) {
                FileManager.default.createFile(atPath: path, contents: nil)
            }

            let fileHandle = FileHandle(forWritingAtPath: path)
            try fileHandle?.seekToEnd()
            try fileHandle?.write(contentsOf: data)
        }

        try await syncTask?.value
    }
}

private extension URL {
    /// Check if the URL is a directory and if it is reachable
    func isDirectoryAndReachable() throws -> Bool {
        guard try resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else {
            return false
        }
        return try checkResourceIsReachable()
    }

    /// - Returns: Total allocated size of a the directory including its subFolders or not
    func directoryTotalAllocatedSize(includingSubfolders: Bool = false) throws -> Int? {
        guard try isDirectoryAndReachable() else { return nil }
        if includingSubfolders {
            guard
                let urls = FileManager.default
                .enumerator(at: self, includingPropertiesForKeys: nil)?.allObjects as? [URL]
            else { return nil }
            return try urls.lazy.reduce(0) {
                (
                    try $1.resourceValues(forKeys: [.totalFileAllocatedSizeKey])
                        .totalFileAllocatedSize ?? 0
                ) + $0
            }
        }
        return try FileManager.default
            .contentsOfDirectory(at: self, includingPropertiesForKeys: nil).lazy.reduce(0) {
                (
                    try $1.resourceValues(forKeys: [.totalFileAllocatedSizeKey])
                        .totalFileAllocatedSize ?? 0
                ) + $0
            }
    }
}
