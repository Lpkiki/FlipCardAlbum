import SwiftUI
import PhotosUI
import AVFoundation

@main struct FlipCardAlbumApp: App {
    var body: some Scene { WindowGroup { AlbumScreen() } }
}
struct AlbumScreen: View {
    @State private var state = AlbumState()
    @State private var audioPlayer: AVAudioPlayer?
    @State private var picks: [PhotosPickerItem] = []
    @State private var error: String?
    @State private var importing = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text("翻页卡册").font(.largeTitle.bold())
                        Text("把喜欢的瞬间，一页一页收藏").foregroundStyle(.secondary)
                    }
                    AlbumBook(state: state).aspectRatio(2.12, contentMode: .fit)
                        .overlay {
                            HStack(spacing: 0) {
                                Button { turn(-1) } label: { Color.clear.contentShape(Rectangle()) }.accessibilityLabel("上一页").accessibilityIdentifier("previousPage")
                                Button { turn(1) } label: { Color.clear.contentShape(Rectangle()) }.accessibilityLabel("下一页").accessibilityIdentifier("nextPage")
                            }.buttonStyle(.plain)
                        }
                        .gesture(DragGesture(minimumDistance: 20).onEnded { value in turn(value.translation.width < 0 ? 1 : -1) })
                    HStack {
                        Text("轻点两侧，翻阅卡册").foregroundStyle(.secondary)
                        Spacer()
                        Text("\(state.page + 1) / \(state.pageCount)").monospacedDigit().accessibilityIdentifier("pageNumber")
                    }.font(.subheadline)
                    VStack(spacing: 20) {
                        PhotosPicker(selection: $picks, maxSelectionCount: 24, matching: .images) {
                            Label(importing ? "正在导入…" : "选择卡册照片", systemImage: "photo.on.rectangle.angled")
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                        }.buttonStyle(.borderedProminent).disabled(importing)
                        Toggle("隐藏卡册底色", isOn: $state.transparent).accessibilityIdentifier("transparentToggle")
                        Text(backgroundHelp).font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                        Toggle("App 内翻页音效", isOn: $state.sound)
                        Divider()
                        VStack(alignment: .leading, spacing: 10) {
                            Label("添加到桌面", systemImage: "plus.square.dashed").font(.headline)
                            Text("长按主屏幕空白处，选择“编辑”→“添加小组件”，搜索“翻页卡册”，添加中号组件。轻点左右两侧即可翻页。").font(.subheadline).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.padding(22).background(.background, in: RoundedRectangle(cornerRadius: 26))
                    Text("照片仅保存在本机 · 无需联网").font(.footnote).foregroundStyle(.secondary)
                }.padding(22).frame(maxWidth: 650)
            }.frame(maxWidth: .infinity).background(Color(uiColor: .systemGroupedBackground))
            .task { reload() }
            .onChange(of: state.transparent) { _, value in update { $0.transparent = value } }
            .onChange(of: state.sound) { _, value in update { $0.sound = value } }
            .onChange(of: scenePhase) { _, phase in if phase == .active { reload() } }
            .onChange(of: picks) { _, items in Task { await importPhotos(items) } }
            .onOpenURL { url in if url.host == "next" { turn(1) } else if url.host == "previous" { turn(-1) } }
            .alert("未能保存", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("好") { error = nil } } message: { Text(error ?? "") }
        }
    }
    private var backgroundHelp: String {
        if #available(iOS 26.0, *) {
            return "此开关仅隐藏卡册底色。系统透明外观需在主屏幕“编辑”→“自定义”中选择，并会影响整个桌面。"
        }
        return "此开关仅隐藏卡册底色，桌面小组件的系统底板仍会保留。壁纸截图贴合方案见项目说明。"
    }
    private func turn(_ direction: Int) {
        if state.sound { playPageSound() }
        withAnimation(reduceMotion ? nil : .linear(duration: 1)) { update { $0.turn(direction) } }
    }
    private func reload() {
        do { state = try AlbumStore.load() } catch { self.error = error.localizedDescription }
    }
    private func playPageSound() {
        guard let url = Bundle.main.url(forResource: "page-turn", withExtension: "mp3") else { return }
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } catch { self.error = error.localizedDescription }
    }
    private func update(_ change: (inout AlbumState) -> Void) { do { state = try AlbumStore.update(change) } catch { self.error = error.localizedDescription } }
    @MainActor private func importPhotos(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        importing = true
        defer { importing = false }
        do {
            var names: [String] = []
            for item in items {
                guard let data = try await item.loadTransferable(type: Data.self) else { continue }
                let name = try await PhotoImporter.shared.store(data)
                names.append(name)
            }
            guard !names.isEmpty else { return }
            update { $0.photos = names; $0.page = 0; $0.revision += 1 }
        } catch { self.error = error.localizedDescription }
    }
}
