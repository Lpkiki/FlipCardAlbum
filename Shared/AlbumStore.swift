import Foundation
import UIKit
import ImageIO
import WidgetKit
import Darwin

struct AlbumState: Codable, Equatable {
    var page = 0
    var revision = 0
    var direction = 1
    var transparent = false
    var sound = true
    var photos: [String] = []
    var pageCount: Int { photos.isEmpty ? 2 : max(1, (photos.count + 3) / 4) }
    mutating func turn(_ delta: Int) {
        direction = delta >= 0 ? 1 : -1
        page = ((page + direction) % pageCount + pageCount) % pageCount
        revision += 1
    }
}

enum AlbumStorageError: LocalizedError {
    case sharedContainerUnavailable
    var errorDescription: String? {
        String(localized: "无法读取共享相册，请重新打开 App；若仍无法恢复，请重新安装。")
    }
}

/// One shared container owns the album; no process-local fallback can silently fork it.
struct AlbumStore {
    static let group = "group.com.lpkiki.FlipCardAlbum"
    static var directory: URL {
        get throws {
            guard let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) else {
                throw AlbumStorageError.sharedContainerUnavailable
            }
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            return root
        }
    }
    static func load() throws -> AlbumState {
        let path = try directory.appendingPathComponent("album.json")
        guard FileManager.default.fileExists(atPath: path.path) else { return AlbumState() }
        return try JSONDecoder().decode(AlbumState.self, from: Data(contentsOf: path))
    }
    private static func save(_ state: AlbumState, reloadWidgets: Bool) throws {
        try JSONEncoder().encode(state).write(to: directory.appendingPathComponent("album.json"), options: .atomic)
        if reloadWidgets { WidgetCenter.shared.reloadTimelines(ofKind: "FlipCardAlbum") }
    }
    /// Serialize read-modify-write across the app and AppIntent extension processes.
    @discardableResult static func update(reloadWidgets: Bool = true, _ change: (inout AlbumState) -> Void) throws -> AlbumState {
        let lockPath = try directory.appendingPathComponent("album.lock").path
        let descriptor = open(lockPath, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw CocoaError(.fileWriteUnknown) }
        defer { close(descriptor) }
        guard flock(descriptor, LOCK_EX) == 0 else { throw CocoaError(.fileWriteUnknown) }
        defer { flock(descriptor, LOCK_UN) }
        var state = try load()
        change(&state)
        try save(state, reloadWidgets: reloadWidgets)
        return state
    }
    static func image(_ index: Int, state: AlbumState) -> UIImage? {
        if !state.photos.isEmpty {
            let name = state.photos[index % state.photos.count]
            guard !name.contains("/"), !name.contains(".."), let root = try? directory else { return nil }
            return UIImage(contentsOfFile: root.appendingPathComponent(name).path)
        }
        return UIImage(named: "widget_paging_card_\((index + 4) % 8 + 1)", in: .main, compatibleWith: nil)
    }
    static func importImage(_ data: Data) throws -> String {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 600,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
              let encoded = UIImage(cgImage: thumbnail).pngData() else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let name = UUID().uuidString + ".png"
        try encoded.write(to: directory.appendingPathComponent(name), options: .atomic)
        return name
    }
}

/// Decoding and downsampling do not occupy the UI actor.
actor PhotoImporter {
    static let shared = PhotoImporter()
    func store(_ data: Data) throws -> String { try AlbumStore.importImage(data) }
}
