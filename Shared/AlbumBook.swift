import SwiftUI
import WidgetKit

/// Dimensions and transparent layers are reconstructed from the Android medium layout.
struct SleevePage: View {
    let state: AlbumState
    let page: Int
    let side: Int
    var body: some View {
        GeometryReader { proxy in
            let unit = proxy.size.width / 164
            ZStack(alignment: .topLeading) {
                AlbumLayer(name: "widget_paging_card_bottom_m")
                    .scaleEffect(x: side == 0 ? 1 : -1)
                AlbumLayer(name: "widget_paging_card_paper_m")
                    .scaleEffect(x: side == 0 ? -1 : 1)
                    .frame(width: (side == 0 ? 158 : 157) * unit, height: 99 * unit)
                    .offset(x: side == 0 ? 7 * unit : 0, y: 6.5 * unit)
                HStack(spacing: 8 * unit) {
                    ForEach(0..<2) { slot in
                        Group {
                            if let image = AlbumStore.image(page * 4 + side * 2 + slot, state: state) {
                                Image(uiImage: image).resizable().albumFullColor().scaledToFill()
                            } else {
                                Color.gray.opacity(0.15)
                            }
                        }
                        .frame(width: 69 * unit, height: 92 * unit)
                        .clipShape(RoundedRectangle(cornerRadius: 5 * unit))
                    }
                }.offset(x: (side == 0 ? 10.64 : 6.38) * unit, y: 10 * unit)
                AlbumLayer(name: "widget_paging_card_top_m")
                    .scaleEffect(x: side == 0 ? 1 : -1)
                    .frame(width: 157 * unit, height: 99 * unit)
                    .offset(x: side == 0 ? 7 * unit : 0, y: 6.5 * unit)
            }
        }
        .aspectRatio(164 / 114, contentMode: .fit)
    }
}

struct AlbumBook: View {
    let state: AlbumState
    var isWidget = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private func bankAnimation(isActive: Bool, side: Int) -> Animation? {
        guard !reduceMotion else { return nil }
        let incomingSide = state.direction > 0 ? 0 : 1
        if side == incomingSide {
            return isActive
                ? .linear(duration: 0.5).delay(0.5)
                : .linear(duration: 0.001).delay(1)
        }
        return isActive ? nil : .linear(duration: 0.5)
    }
    /// Stable banks let WidgetKit compare native scale transforms between archived entries.
    /// The outgoing bank retains the prior page while the incoming bank expands over it.
    private func pageBanks(side: Int) -> some View {
        let activeBank = state.revision % 2
        let previousPage = ((state.page - state.direction) % state.pageCount + state.pageCount) % state.pageCount
        let incomingSide = state.direction > 0 ? 0 : 1
        return ZStack {
            ForEach(0..<2) { bank in
                let isActive = bank == activeBank
                SleevePage(state: state, page: isActive ? state.page : previousPage, side: side)
                    .scaleEffect(x: isActive ? 1 : 0.001, y: 1, anchor: side == 0 ? .trailing : .leading)
                    .animation(bankAnimation(isActive: isActive, side: side), value: state.revision)
                    .zIndex((side == incomingSide) == isActive ? 1 : 0)
            }
        }
    }
    private func widgetPage(side: Int) -> some View {
        pageBanks(side: side)
    }
    var body: some View {
        GeometryReader { proxy in
            let width = min(proxy.size.width, proxy.size.height * 329 / 155)
            let unit = width / 329
            ZStack {
                if !state.transparent {
                    AlbumLayer(name: "widget_paging_card_bg")
                        .clipShape(RoundedRectangle(cornerRadius: 20 * unit))
                }
                HStack(spacing: 0) {
                    if isWidget {
                        widgetPage(side: 0)
                        widgetPage(side: 1)
                    } else {
                        pageBanks(side: 0)
                        pageBanks(side: 1)
                    }
                }.frame(width: 328 * unit, height: 114 * unit)
            }
            .frame(width: width, height: 155 * unit)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("翻页卡册，第\(state.page + 1)页")
    }
}

/// Resolve bundle resources before WidgetKit archives the view into SpringBoard.
private struct AlbumLayer: View {
    let name: String
    var body: some View {
        if let image = UIImage(named: name, in: .main, compatibleWith: nil) {
            Image(uiImage: image).resizable()
        }
    }
}

private extension Image {
    @ViewBuilder func albumFullColor() -> some View {
        if #available(iOS 18.0, *) {
            widgetAccentedRenderingMode(.fullColor)
        } else {
            self
        }
    }
}
