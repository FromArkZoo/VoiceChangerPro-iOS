import SwiftUI

// About / Acknowledgements sheet. Hosts version info and the MIT attribution
// for Signalsmith Stretch (required by the license — kept in-app rather than
// only in repo so end users can find it).
struct AboutSheet: View {
    @Environment(\.dismiss) private var dismiss

    private var versionString: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(v) (\(b))"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                appInfo
                divider
                openSource
                Spacer(minLength: 40)
            }
            .padding(24)
        }
        .background(Theme.background.ignoresSafeArea())
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                TagLabel(text: "ABOUT", filled: .black)
                Text("JB\nVOICE\nCHANGER")
                    .font(Theme.headline(40))
                    .tracking(-2)
                    .lineSpacing(-6)
                    .foregroundColor(.black)
            }
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(.black)
                    .frame(width: 40, height: 40)
                    .background(Theme.tertiary)
                    .overlay(Rectangle().stroke(Color.black, lineWidth: Theme.thinBorderWidth))
            }
            .buttonStyle(.plain)
        }
    }

    private var appInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(versionString)
                .font(Theme.headline(20))
                .foregroundColor(.black)
            Text("REAL-TIME VOICE PROCESSING")
                .font(Theme.label(11))
                .tracking(2)
                .foregroundColor(Theme.onSurfaceVariant)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.black)
            .frame(height: Theme.thinBorderWidth)
    }

    private var openSource: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("OPEN SOURCE")
                .font(Theme.label(11))
                .tracking(2)
                .foregroundColor(Theme.onSurfaceVariant)

            attributionCard(
                name: "Signalsmith Stretch",
                role: "Pitch shifting · formant preservation",
                license: "MIT License",
                copyright: "Copyright (c) 2022 Geraint Luff / Signalsmith Audio Ltd.",
                color: Theme.secondary
            )
        }
    }

    private func attributionCard(name: String,
                                 role: String,
                                 license: String,
                                 copyright: String,
                                 color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Rectangle()
                    .fill(color)
                    .frame(width: 8)
                    .frame(maxHeight: .infinity)
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(Theme.headline(18))
                        .foregroundColor(.black)
                    Text(role.uppercased())
                        .font(Theme.label(10))
                        .tracking(2)
                        .foregroundColor(Theme.onSurfaceVariant)
                }
                Spacer(minLength: 0)
                Text(license.uppercased())
                    .font(Theme.label(10))
                    .tracking(1)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(copyright)
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundColor(Theme.onSurfaceVariant)

            Text(mitLicenseText)
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundColor(Theme.onSurfaceVariant)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Theme.surfaceContainer)
        .overlay(Rectangle().stroke(Color.black, lineWidth: Theme.thinBorderWidth))
    }

    private let mitLicenseText: String = """
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
"""
}

#Preview {
    AboutSheet()
}
