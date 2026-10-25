import SwiftUI

struct HistoryView: View {
    let craft: Craft

    var body: some View {
        Text("History").lgText(.screenTitle)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .lgScreen()
    }
}
