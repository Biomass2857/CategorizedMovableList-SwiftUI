import SwiftUI

@available(iOS 16, *)
extension View {
    @ViewBuilder func `conditionalModifier`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
