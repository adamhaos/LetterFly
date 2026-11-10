import UIKit

/// Named vibration patterns, so each kind of moment has its own feel.
/// Every pattern respects the player's haptics setting.
final class Haptics {
    static let shared = Haptics()

    var isEnabled: Bool {
        get { defaults.object(forKey: enabledKey) as? Bool ?? true }
        set { defaults.set(newValue, forKey: enabledKey) }
    }

    private let defaults = UserDefaults.standard
    private let enabledKey = "haptics.enabled"
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let notificationGenerator = UINotificationFeedbackGenerator()

    /// A light tick, for picking menu options and ordinary letters.
    func select() {
        guard isEnabled else { return }
        selectionGenerator.selectionChanged()
    }

    func tap(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    /// A firm, solid knock for picking up a 2× letter.
    func bonusLetter() {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 1)
    }

    func success() {
        guard isEnabled else { return }
        notificationGenerator.notificationOccurred(.success)
    }

    func warning() {
        guard isEnabled else { return }
        notificationGenerator.notificationOccurred(.warning)
    }

    func error() {
        guard isEnabled else { return }
        notificationGenerator.notificationOccurred(.error)
    }

    /// A celebratory triple: success, then two quick rising taps.
    func themeWord() {
        guard isEnabled else { return }
        notificationGenerator.notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.7)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 1)
        }
    }

    /// A heartbeat for the final seconds: stronger as the clock runs out.
    func clockTick(secondsLeft: Int) {
        guard isEnabled else { return }
        let intensity = CGFloat(min(1, 0.35 + 0.065 * Double(10 - secondsLeft)))
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: intensity)
    }
}
