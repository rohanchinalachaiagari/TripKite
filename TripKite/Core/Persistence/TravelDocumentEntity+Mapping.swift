import CoreData
import Foundation

extension TravelDocumentEntity {
    func toDomain() -> TravelDocument {
        TravelDocument(
            id: id ?? UUID(),
            tripId: trip?.id ?? UUID(),
            itineraryItemId: item?.id,
            fileName: fileName ?? "",
            localRelativePath: localRelativePath ?? "",
            fileType: fileType ?? "",
            fileSize: fileSize?.int64Value,
            createdAt: createdAt ?? Date()
        )
    }

    // Relationships (`trip`, `item`) are assigned by the repository when the
    // document is created. `apply` only writes scalar attributes.
    func apply(_ document: TravelDocument) {
        id = document.id
        fileName = document.fileName
        localRelativePath = document.localRelativePath
        fileType = document.fileType
        fileSize = document.fileSize.map { NSNumber(value: $0) }
        createdAt = document.createdAt
    }
}
