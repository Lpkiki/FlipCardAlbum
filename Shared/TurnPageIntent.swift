import AppIntents
import WidgetKit

struct TurnPageIntent: AppIntent {
    static var title: LocalizedStringResource = "翻页"
    static var openAppWhenRun = false
    @Parameter(title: "方向") var direction: Int
    init() { direction = 1 }
    init(direction: Int) { self.direction = direction }
    func perform() async throws -> some IntentResult {
        try AlbumStore.update(reloadWidgets: false) { $0.turn(direction) }
        return .result()
    }
}
