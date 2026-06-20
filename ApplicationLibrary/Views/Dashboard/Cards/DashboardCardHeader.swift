import SwiftUI

public struct DashboardCardHeader: View {
    private let image: Image
    private let tinted: Bool
    private let title: LocalizedStringKey

    public init(icon: String, title: LocalizedStringKey) {
        image = Image(systemName: icon)
        tinted = true
        self.title = title
    }

    // Custom asset icon (e.g. a brand logo) rendered in its original colors.
    public init(image name: String, title: LocalizedStringKey) {
        image = Image(name, bundle: ApplicationLibrary.bundle)
        tinted = false
        self.title = title
    }

    public var body: some View {
        HStack(spacing: 8) {
            iconView
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
        }
    }

    @ViewBuilder
    private var iconView: some View {
        if tinted {
            image.foregroundStyle(.primary)
        } else {
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
        }
    }
}
