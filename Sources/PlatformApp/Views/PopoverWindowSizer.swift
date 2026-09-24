import AppKit
import QuartzCore
import SwiftUI

struct PopoverWindowSizer: NSViewRepresentable {
    let contentSize: CGSize
    var animateChanges = false
    var transparentBackground = false

    func makeNSView(context: Context) -> WindowSizingView {
        WindowSizingView(
            contentSize: contentSize,
            animateChanges: animateChanges,
            transparentBackground: transparentBackground
        )
    }

    func updateNSView(_ nsView: WindowSizingView, context: Context) {
        nsView.contentSize = contentSize
        nsView.animateChanges = animateChanges
        nsView.transparentBackground = transparentBackground
        nsView.resizeWindowIfNeeded()
    }
}

final class WindowSizingView: NSView {
    var contentSize: CGSize
    var animateChanges: Bool
    var transparentBackground: Bool

    init(contentSize: CGSize, animateChanges: Bool, transparentBackground: Bool) {
        self.contentSize = contentSize
        self.animateChanges = animateChanges
        self.transparentBackground = transparentBackground
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        resizeWindowIfNeeded()
    }

    func resizeWindowIfNeeded() {
        guard let window else { return }

        DispatchQueue.main.async { [weak self, weak window] in
            guard let self, let window else { return }
            if self.transparentBackground {
                window.isOpaque = false
                window.backgroundColor = .clear
            }
            let currentFrame = window.frame
            let currentContent = window.contentRect(forFrameRect: currentFrame)
            let targetFrame = PopoverWindowLayout.frame(
                currentFrame: currentFrame,
                currentContentSize: currentContent.size,
                targetContentSize: self.contentSize
            )

            guard abs(currentFrame.width - targetFrame.width) > 0.5
                    || abs(currentFrame.height - targetFrame.height) > 0.5 else { return }

            if self.animateChanges {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.22
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    window.animator().setFrame(targetFrame, display: true)
                }
            } else {
                window.setFrame(targetFrame, display: true, animate: false)
            }
        }
    }
}

enum PopoverWindowLayout {
    static func frame(
        currentFrame: CGRect,
        currentContentSize: CGSize,
        targetContentSize: CGSize
    ) -> CGRect {
        let chromeWidth = max(0, currentFrame.width - currentContentSize.width)
        let chromeHeight = max(0, currentFrame.height - currentContentSize.height)
        let targetWidth = targetContentSize.width + chromeWidth
        let targetHeight = targetContentSize.height + chromeHeight

        return CGRect(
            x: currentFrame.maxX - targetWidth,
            y: currentFrame.maxY - targetHeight,
            width: targetWidth,
            height: targetHeight
        )
    }
}
