import SwiftUI
import QuickLook

// SwiftUI doesn't ship a native QuickLook modifier on iOS, so we wrap
// QLPreviewController in a UIViewControllerRepresentable. Presented via the
// `quickLookSheet(url:)` modifier below so the call site stays tiny.
struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: QLPreviewController, context: Context) {
        context.coordinator.url = url
        controller.reloadData()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        var url: URL

        init(url: URL) {
            self.url = url
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL
        }
    }
}

// Internal wrapper makes the URL Identifiable for `.sheet(item:)` without
// adding a global `extension URL: Identifiable` that could collide with future
// SDK changes.
private struct PreviewItem: Identifiable {
    let id: URL
    var url: URL { id }
    init(_ url: URL) { self.id = url }
}

extension View {
    // Presents a QuickLook preview when the bound URL is non-nil. Setting the
    // binding to nil (e.g., by swiping the sheet away) dismisses the preview.
    func quickLookSheet(url: Binding<URL?>) -> some View {
        let item = Binding<PreviewItem?>(
            get: { url.wrappedValue.map(PreviewItem.init) },
            set: { url.wrappedValue = $0?.url }
        )
        return sheet(item: item) { item in
            QuickLookPreview(url: item.url)
                .ignoresSafeArea()
        }
    }
}
