import SwiftUI

// Bauhaus design system — 4px black borders, zero corner radius, offset shadow
// (x:4 y:4 pure black, no blur). Brand palette locked to the mockup.
enum Theme {
    // Palette
    static let primary   = Color(red: 0xC4/255.0, green: 0x1D/255.0, blue: 0x31/255.0) // #C41D31
    static let secondary = Color(red: 0x1E/255.0, green: 0x62/255.0, blue: 0xBF/255.0) // #1E62BF
    static let tertiary  = Color(red: 0xFF/255.0, green: 0xD7/255.0, blue: 0x09/255.0) // #FFD709
    static let background = Color(red: 0xFF/255.0, green: 0xFB/255.0, blue: 0xFF/255.0) // #FFFBFF
    static let surfaceHighest = Color(red: 0xEC/255.0, green: 0xE9/255.0, blue: 0xD3/255.0) // #ECE9D3
    static let surfaceContainer = Color(red: 0xF8/255.0, green: 0xF4/255.0, blue: 0xE0/255.0) // #F8F4E0
    static let onSurfaceVariant = Color(red: 0x66/255.0, green: 0x65/255.0, blue: 0x58/255.0) // #666558

    // Typography — SF Pro is the fallback, used throughout. The design calls for
    // Public Sans Black + Space Grotesk; SF Pro in black weight reads close enough
    // for the brutalist look and avoids shipping custom fonts in this pass.
    static func headline(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black, design: .default)
    }

    static func label(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .default)
    }

    // Border + shadow primitives
    static let borderWidth: CGFloat = 4
    static let thinBorderWidth: CGFloat = 2
    static let shadowOffset: CGFloat = 4
    static let deepShadowOffset: CGFloat = 8
}

// Heavy black rectangular border around any view.
struct BauhausBorder: ViewModifier {
    var width: CGFloat = Theme.borderWidth
    func body(content: Content) -> some View {
        content.overlay(
            Rectangle().stroke(Color.black, lineWidth: width)
        )
    }
}

// Offset-shadow block — the signature Bauhaus "this thing is a button" cue.
// Shadow is solid black, no blur, fixed offset.
struct BauhausShadow: ViewModifier {
    var offset: CGFloat = Theme.shadowOffset
    func body(content: Content) -> some View {
        content
            .compositingGroup()
            .shadow(color: .black, radius: 0, x: offset, y: offset)
    }
}

extension View {
    func bauhausBorder(_ width: CGFloat = Theme.borderWidth) -> some View {
        modifier(BauhausBorder(width: width))
    }

    func bauhausShadow(_ offset: CGFloat = Theme.shadowOffset) -> some View {
        modifier(BauhausShadow(offset: offset))
    }
}

// Stylised uppercase label used for tags / section kickers.
struct TagLabel: View {
    let text: String
    var bordered: Bool = false
    var filled: Color? = nil

    var body: some View {
        Text(text.uppercased())
            .font(Theme.label(10))
            .kerning(1.5)
            .foregroundColor(filled != nil ? .white : .black)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(filled ?? Color.clear)
            .modifier(ConditionalBorder(bordered: bordered))
            .fixedSize(horizontal: true, vertical: false)
    }
}

private struct ConditionalBorder: ViewModifier {
    let bordered: Bool
    func body(content: Content) -> some View {
        if bordered {
            content.overlay(Rectangle().stroke(Color.black, lineWidth: 2))
        } else {
            content
        }
    }
}

// Big block-style page headline, e.g. "VOICE\nPRESETS".
struct PageHeader: View {
    let kicker: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TagLabel(text: kicker, filled: Theme.primary)
                .padding(.bottom, 12)
            Text(title.uppercased())
                .font(Theme.headline(56))
                .tracking(-2)
                .foregroundColor(.black)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Rectangle()
                .fill(Color.black)
                .frame(width: 128, height: 8)
                .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
