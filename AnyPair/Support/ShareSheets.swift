import SwiftUI
import UIKit

/// iOS share sheet for one or more files.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// "Save to Files" — lets the user pick a folder; the file is copied there.
struct SaveToFilesSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        UIDocumentPickerViewController(forExporting: [url], asCopy: true)
    }

    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}
}

/// What to present for a saved pairing file.
enum FileAction: Identifiable {
    case share(URL)
    case shareMany([URL])
    case saveToFiles(URL)

    var id: String {
        switch self {
        case .share(let url): return "share:" + url.path
        case .shareMany(let urls): return "shareMany:" + urls.map(\.path).joined()
        case .saveToFiles(let url): return "files:" + url.path
        }
    }
}

extension View {
    func fileActionSheet(_ action: Binding<FileAction?>) -> some View {
        sheet(item: action) { action in
            Group {
                switch action {
                case .share(let url): ShareSheet(items: [url])
                case .shareMany(let urls): ShareSheet(items: urls)
                case .saveToFiles(let url): SaveToFilesSheet(url: url)
                }
            }
            .ignoresSafeArea()
            .appLayoutDirection()
        }
    }
}
