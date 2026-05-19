import Foundation

struct TravelDocument: Identifiable, Hashable, Sendable {
    let id: UUID
    var tripId: UUID
    var itineraryItemId: UUID?
    var fileName: String
    var localRelativePath: String
    var fileType: String
    var fileSize: Int64?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        tripId: UUID,
        itineraryItemId: UUID? = nil,
        fileName: String,
        localRelativePath: String,
        fileType: String,
        fileSize: Int64? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.tripId = tripId
        self.itineraryItemId = itineraryItemId
        self.fileName = fileName
        self.localRelativePath = localRelativePath
        self.fileType = fileType
        self.fileSize = fileSize
        self.createdAt = createdAt
    }

    var systemImageName: String {
        switch fileType.lowercased() {
        case "pdf": return "doc.text.fill"
        case "png", "jpg", "jpeg", "heic", "heif", "gif", "webp", "tiff":
            return "photo.fill"
        case "txt", "md", "rtf":
            return "doc.plaintext.fill"
        case "zip", "tar", "gz":
            return "archivebox.fill"
        default:
            return "doc.fill"
        }
    }
}
