import SwiftUI

/// Placeholder until the People (Roster) spec is implemented.
struct PeopleView: View {
    var body: some View {
        ContentUnavailableView(
            "People",
            systemImage: "person.2",
            description: Text("The roster arrives with the People flow.")
        )
        .navigationTitle("People")
    }
}
