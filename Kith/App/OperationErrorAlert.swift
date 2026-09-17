import SwiftUI

private struct OperationErrorAlert: ViewModifier {
    let title: LocalizedStringKey
    @Binding var message: String?

    private var isPresented: Binding<Bool> {
        Binding(
            get: { message != nil },
            set: { if !$0 { message = nil } }
        )
    }

    func body(content: Content) -> some View {
        content.alert(title, isPresented: isPresented) {
            Button("OK", role: .cancel) { message = nil }
        } message: {
            Text(message ?? "")
        }
    }
}

extension View {
    func operationErrorAlert(_ title: LocalizedStringKey, message: Binding<String?>) -> some View {
        modifier(OperationErrorAlert(title: title, message: message))
    }
}
