import SwiftUI

struct HomeView: View {
    let craft: Craft

    var body: some View {
        VStack(spacing: 16) {
            SunView().frame(width: 120, height: 120)
            Text(craft.name).lgText(.screenTitle)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .lgScreen()
    }
}
