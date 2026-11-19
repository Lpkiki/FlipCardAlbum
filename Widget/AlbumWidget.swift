import WidgetKit
import SwiftUI

struct AlbumEntry: TimelineEntry { let date: Date; let state: AlbumState; var problem: String? = nil }
struct AlbumProvider: TimelineProvider {
    private func loadEntry() -> AlbumEntry {
        do { return AlbumEntry(date: .now, state: try AlbumStore.load()) }
        catch { return AlbumEntry(date: .now, state: AlbumState(), problem: error.localizedDescription) }
    }
    func placeholder(in context: Context) -> AlbumEntry { AlbumEntry(date: .now, state: AlbumState()) }
    func getSnapshot(in context: Context, completion: @escaping (AlbumEntry) -> Void) { completion(loadEntry()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<AlbumEntry>) -> Void) {
        completion(Timeline(entries: [loadEntry()], policy: .never))
    }
}
struct AlbumWidgetView: View {
    let entry: AlbumEntry
    var body: some View {
        Group {
            if let problem = entry.problem {
                VStack(spacing: 8) {
                    Label("共享相册不可用", systemImage: "exclamationmark.triangle")
                        .font(.headline)
                    Text(problem).font(.caption).multilineTextAlignment(.center)
                }.padding()
            } else {
                album
            }
        }
        .containerBackground(for: .widget) {
            if !entry.state.transparent,
               let image = UIImage(named: "widget_paging_card_bg", in: .main, compatibleWith: nil) {
                Image(uiImage: Self.backdrop(image)).resizable()
            } else {
                Color.clear
            }
        }
    }
    private static func backdrop(_ image: UIImage) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let size = CGSize(width: 720, height: 340)
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
    /// The host owns the static backdrop; only the pages belong to the animated tree.
    private var pagesState: AlbumState {
        var value = entry.state
        value.transparent = true
        return value
    }
    private var album: some View {
        AlbumBook(state: pagesState, isWidget: true)
            .overlay {
                HStack(spacing: 0) {
                    Button(intent: TurnPageIntent(direction: -1)) { Color.clear.contentShape(Rectangle()) }
                        .accessibilityLabel("上一页")
                    Button(intent: TurnPageIntent(direction: 1)) { Color.clear.contentShape(Rectangle()) }
                        .accessibilityLabel("下一页")
                }.buttonStyle(.plain)
            }

    }
}
@main struct AlbumWidget: Widget {
    let kind = "FlipCardAlbum"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AlbumProvider()) { AlbumWidgetView(entry: $0) }
            .configurationDisplayName("翻页卡册")
            .description("轻点左页或右页，翻阅属于你的照片。")
            .supportedFamilies([.systemMedium])
            .contentMarginsDisabled()
    }
}
