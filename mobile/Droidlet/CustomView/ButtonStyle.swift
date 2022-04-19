import Foundation
import SwiftUI

struct CustomButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.bottom)
            .foregroundColor(.white)
            .clipShape(Capsule())
    }
}
