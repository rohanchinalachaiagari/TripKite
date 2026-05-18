import Foundation

enum ImageFormat: String, Hashable {
    case png
    case jpeg
    case heic

    var fileExtension: String {
        switch self {
        case .png: return "png"
        case .jpeg: return "jpg"
        case .heic: return "heic"
        }
    }
}

enum ImageFormatDetection {
    // Detects PNG/JPEG/HEIC from raw bytes. Returns nil for unrecognized data
    // so callers can choose a fallback (typically .jpeg).
    static func detect(_ data: Data) -> ImageFormat? {
        guard data.count >= 12 else { return nil }
        let bytes = [UInt8](data.prefix(12))

        // PNG: 89 50 4E 47 0D 0A 1A 0A
        if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            return .png
        }
        // JPEG: FF D8 FF
        if bytes.starts(with: [0xFF, 0xD8, 0xFF]) {
            return .jpeg
        }
        // HEIC: bytes 4-11 spell "ftypheic" (or "ftypheix", "ftyphevc", etc.)
        if bytes[4] == 0x66, bytes[5] == 0x74, bytes[6] == 0x79, bytes[7] == 0x70,
           bytes[8] == 0x68, bytes[9] == 0x65, bytes[10] == 0x69,
           (bytes[11] == 0x63 || bytes[11] == 0x78 || bytes[11] == 0x73) {
            return .heic
        }
        return nil
    }
}
