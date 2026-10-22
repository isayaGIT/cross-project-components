import SwiftUI
import UIKit

/// A UIKit blur that can be interactively scrubbed from blurred to clear.
/// Keeping one effect view alive avoids replacing the backdrop during a dismiss gesture.
struct ImageViewerBlur: UIViewRepresentable {
    let style: UIBlurEffect.Style
    var revealProgress: CGFloat = 0

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: style))
        view.backgroundColor = .clear
        context.coordinator.configure(view: view, style: style)
        context.coordinator.update(progress: revealProgress)
        return view
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        if context.coordinator.style != style {
            context.coordinator.configure(view: uiView, style: style)
        }
        context.coordinator.update(progress: revealProgress)
    }

    final class Coordinator {
        fileprivate var style: UIBlurEffect.Style?
        private var animator: UIViewPropertyAnimator?

        func configure(view: UIVisualEffectView, style: UIBlurEffect.Style) {
            // A paused UIViewPropertyAnimator must be finished before it is released.
            // stopAnimation(true) alone leaves it stopped-but-unfinalized and can crash
            // the app when SwiftUI tears down or reconfigures the representable.
            if let animator {
                animator.stopAnimation(true)
                animator.finishAnimation(at: .current)
            }
            self.animator = nil
            view.effect = UIBlurEffect(style: style)
            self.style = style

            let animator = UIViewPropertyAnimator(duration: 1, curve: .linear) {
                view.effect = nil
            }
            animator.pausesOnCompletion = true
            animator.startAnimation()
            animator.pauseAnimation()
            self.animator = animator
        }

        func update(progress: CGFloat) {
            animator?.fractionComplete = min(max(progress, 0), 1)
        }

        deinit {
            if let animator {
                if animator.state == .active || animator.state == .inactive {
                    animator.stopAnimation(true)
                }
                if animator.state == .stopped {
                    animator.finishAnimation(at: .current)
                }
            }
        }
    }
}
