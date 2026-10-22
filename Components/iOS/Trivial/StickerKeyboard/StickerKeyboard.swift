import SwiftUI

/// A lightweight, reusable Unicode emoji picker.
///
/// The picker owns only its presentation and category selection. The caller owns
/// draft text, insertion behavior, focus, and placement in the surrounding layout.
public struct StickerKeyboard: View {
    public struct Configuration: Equatable {
        /// The panel's preferred height, in points.
        public var height: CGFloat
        /// Number of emoji columns in the grid.
        public var columns: Int

        public init(height: CGFloat = 270, columns: Int = 8) {
            self.height = max(180, height)
            self.columns = min(12, max(4, columns))
        }

        public static let standard = Configuration()
    }

    public static let defaultHeight: CGFloat = Configuration.standard.height

    public let configuration: Configuration
    private let onSelect: (String) -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedCategory: Category = .smileys

    public init(
        configuration: Configuration = .standard,
        onSelect: @escaping (String) -> Void
    ) {
        self.configuration = configuration
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(Category.allCases) { category in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedCategory = category
                        }
                    } label: {
                        Image(systemName: category.symbol)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(selectedCategory == category ? Color.primary : Color.secondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(category.label)
                    .accessibilityAddTraits(selectedCategory == category ? .isSelected : [])
                }
            }
            .padding(.horizontal, 8)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.primary.opacity(0.10))
                    .frame(height: 1)
            }

            ScrollView {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: configuration.columns),
                    spacing: 4
                ) {
                    ForEach(selectedCategory.emojis, id: \.self) { emoji in
                        Button {
                            onSelect(emoji)
                        } label: {
                            Text(emoji)
                                .font(.system(size: 27))
                                .frame(maxWidth: .infinity)
                                .frame(height: 38)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Insert \(emoji)")
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
            }
        }
        .frame(height: configuration.height)
        .background(.regularMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.08))
                .frame(height: 1)
        }
    }

    private enum Category: String, CaseIterable, Identifiable {
        case smileys, people, nature, food, activities, travel, objects, symbols

        var id: String { rawValue }
        var label: String {
            switch self {
            case .smileys: "Smileys"
            case .people: "People"
            case .nature: "Nature"
            case .food: "Food"
            case .activities: "Activities"
            case .travel: "Travel"
            case .objects: "Objects"
            case .symbols: "Symbols"
            }
        }
        var symbol: String {
            switch self {
            case .smileys: "face.smiling"
            case .people: "hand.wave"
            case .nature: "leaf"
            case .food: "fork.knife"
            case .activities: "basketball"
            case .travel: "car"
            case .objects: "lightbulb"
            case .symbols: "heart"
            }
        }
        var emojis: [String] {
            switch self {
            case .smileys: ["😀", "😃", "😄", "😁", "😆", "😅", "🤣", "😂", "🙂", "🙃", "😉", "😊", "😇", "🥰", "😍", "🤩", "😘", "😗", "😚", "😙", "🥲", "😋", "😛", "😜", "🤪", "😝", "🤑", "🤗", "🤭", "🫢", "🫣", "🤫", "🤔", "🫡", "🤐", "🤨", "😐", "😑", "😶", "🫥", "😏", "😒", "🙄", "😬", "😮‍💨", "🤥", "😌", "😔", "😪", "🤤", "😴", "😷", "🤒", "🤕", "🤢", "🤮", "🥵", "🥶", "🥴", "😵", "🤯", "🥳", "🥹", "😭", "😤", "😡", "🤬", "😈", "💀", "💩", "🤡", "👻", "👽", "🤖"]
            case .people: ["👋", "🤚", "🖐️", "✋", "🖖", "👌", "🤌", "🤏", "✌️", "🤞", "🫰", "🤟", "🤘", "🤙", "👈", "👉", "👆", "👇", "☝️", "👍", "👎", "✊", "👊", "🤛", "🤜", "👏", "🙌", "🫶", "🤲", "🙏", "💪", "🦾", "🧠", "👀", "👁️", "👄", "💋", "👶", "🧒", "👦", "👧", "🧑", "👨", "👩", "🧑‍💻", "👨‍💻", "👩‍💻", "🧑‍🎨", "🕺", "💃", "🧘"]
            case .nature: ["🐶", "🐱", "🐭", "🐹", "🐰", "🦊", "🐻", "🐼", "🐻‍❄️", "🐨", "🐯", "🦁", "🐮", "🐷", "🐸", "🐵", "🙈", "🙉", "🙊", "🐔", "🐧", "🐦", "🦆", "🦉", "🦇", "🐺", "🐗", "🐴", "🦄", "🐝", "🪱", "🦋", "🐌", "🐞", "🐜", "🪲", "🕷️", "🦂", "🐢", "🐍", "🦎", "🦖", "🌵", "🌲", "🌳", "🌴", "🌱", "🌿", "☘️", "🍀", "🍁", "🍂", "🍃", "🌷", "🌹", "🌺", "🌸", "🌼", "🌻", "🌞", "🌝", "🌛", "🌜", "🌚", "⭐", "🌟", "✨", "⚡", "🔥", "🌈", "☀️", "🌤️", "🌧️", "❄️", "☃️", "🌊"]
            case .food: ["🍏", "🍎", "🍐", "🍊", "🍋", "🍌", "🍉", "🍇", "🍓", "🫐", "🍈", "🍒", "🍑", "🥭", "🍍", "🥥", "🥝", "🍅", "🍆", "🥑", "🥦", "🥬", "🥒", "🌶️", "🫑", "🌽", "🥕", "🫒", "🧄", "🧅", "🥔", "🍠", "🥐", "🥯", "🍞", "🥖", "🧀", "🥚", "🍳", "🧈", "🥞", "🧇", "🥓", "🍗", "🍖", "🌭", "🍔", "🍟", "🍕", "🫓", "🥪", "🥙", "🧆", "🌮", "🌯", "🫔", "🥗", "🥘", "🍝", "🍜", "🍲", "🍛", "🍣", "🍱", "🥟", "🍤", "🍙", "🍚", "🍘", "🍥", "🥠", "🥮", "🍢", "🍡", "🍧", "🍨", "🍦", "🥧", "🧁", "🍰", "🎂", "🍮", "🍭", "🍬", "🍫", "🍿", "🍩", "🍪", "☕", "🧋", "🥤", "🧃", "🍵", "🍺", "🍷"]
            case .activities: ["⚽", "🏀", "🏈", "⚾", "🥎", "🎾", "🏐", "🏉", "🥏", "🎱", "🪀", "🏓", "🏸", "🏒", "🏑", "🥍", "🏏", "🪃", "🥅", "⛳", "🪁", "🏹", "🎣", "🤿", "🥊", "🥋", "🎽", "🛹", "🛼", "🛷", "⛸️", "🥌", "🎿", "⛷️", "🏂", "🪂", "🏋️", "🤼", "🤸", "⛹️", "🤺", "🤾", "🏌️", "🏇", "🧘", "🏄", "🏊", "🤽", "🚣", "🧗", "🚴", "🚵", "🎯", "🎮", "🕹️", "🎲", "♟️", "🎭", "🎨", "🎼", "🎤", "🎧", "🎹", "🥁", "🎷", "🎺", "🎸", "🪕", "🎻", "🎬", "🎟️", "🎪", "🎫", "🎉", "🎊", "🎈"]
            case .travel: ["🚗", "🚕", "🚙", "🚌", "🚎", "🏎️", "🚓", "🚑", "🚒", "🚐", "🛻", "🚚", "🚛", "🚜", "🛵", "🏍️", "🛺", "🚲", "🛴", "🛹", "🚏", "🛣️", "🛤️", "⛽", "🛞", "🚨", "🚥", "🚦", "🛑", "🚧", "⚓", "🛟", "⛵", "🛶", "🚤", "🛳️", "⛴️", "🛥️", "🚢", "✈️", "🛩️", "🛫", "🛬", "🪂", "💺", "🚁", "🚟", "🚠", "🚡", "🛰️", "🚀", "🛸", "🌍", "🌎", "🌏", "🌐", "🗺️", "🧭", "🏔️", "⛰️", "🌋", "🗻", "🏕️", "🏖️", "🏜️", "🏝️", "🏞️", "🏟️", "🏛️", "🏗️", "🧱", "🏠", "🏡", "🏢", "🏣", "🏥", "🏦", "🏨", "🏩", "🏪", "🏫", "🏬", "🏭", "🏯", "🏰", "💒", "🗼", "🗽", "⛪", "🕌", "🛕", "🕍"]
            case .objects: ["⌚", "📱", "📲", "💻", "⌨️", "🖥️", "🖨️", "🖱️", "🖲️", "🕹️", "💽", "💾", "💿", "📀", "📷", "📸", "📹", "🎥", "📽️", "🎞️", "📞", "☎️", "📟", "📠", "📺", "📻", "🎙️", "🎚️", "🎛️", "🧭", "⏱️", "⏰", "⌛", "⏳", "📡", "🔋", "🪫", "🔌", "💡", "🔦", "🕯️", "🪔", "🧯", "🛢️", "💸", "💵", "💴", "💶", "💷", "💰", "💳", "🪙", "💎", "⚖️", "🪜", "🧰", "🪛", "🔧", "🔨", "⚒️", "🛠️", "⛏️", "🪚", "🔩", "⚙️", "🧱", "⛓️", "🧲", "🔫", "💣", "🧨", "🪓", "🪃", "🧹", "🧺", "🧻", "🪣", "🧼", "🪥", "🧽", "🧴", "🛎️", "🔑", "🗝️", "🚪", "🪑", "🛏️", "🛋️", "🪞", "🪟", "🧸", "🪆", "🖼️", "🛍️", "🎁"]
            case .symbols: ["❤️", "🧡", "💛", "💚", "💙", "💜", "🖤", "🤍", "🤎", "🩷", "🩵", "🩶", "💔", "❤️‍🔥", "❤️‍🩹", "❣️", "💕", "💞", "💓", "💗", "💖", "💘", "💝", "💟", "☮️", "✝️", "☪️", "🕉️", "☸️", "✡️", "🔯", "🕎", "☯️", "☦️", "🛐", "⛎", "♈", "♉", "♊", "♋", "♌", "♍", "♎", "♏", "♐", "♑", "♒", "♓", "🆔", "⚛️", "🉑", "☢️", "☣️", "📴", "📳", "🈶", "🈚", "🈸", "🈺", "🈷️", "✴️", "🆚", "💯", "🔞", "🚫", "⛔", "❗", "❓", "‼️", "⁉️", "🔱", "⚜️", "🔰", "♻️", "✅", "❌", "⭕", "🚩", "🏳️", "🏴", "🏁"]
            }
        }
    }
}
