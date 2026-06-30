import SwiftUI

struct OnboardingView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    appMark

                    VStack(spacing: 8) {
                        Text(L10n.Onboarding.title)
                            .font(.title2.weight(.bold))
                            .multilineTextAlignment(.center)
                        Text(L10n.Onboarding.subtitle)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(spacing: 12) {
                        OnboardingStep(
                            symbol: "menubar.rectangle",
                            title: L10n.Onboarding.stepMenuBarTitle,
                            detail: L10n.Onboarding.stepMenuBarDetail
                        )
                        OnboardingStep(
                            symbol: "command",
                            title: L10n.Onboarding.stepShortcutTitle,
                            detail: L10n.Onboarding.stepShortcutDetail
                        )
                        OnboardingStep(
                            symbol: "doc.on.clipboard",
                            title: L10n.Onboarding.stepSavesTitle,
                            detail: L10n.Onboarding.stepSavesDetail
                        )
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 28)
                .padding(.bottom, 16)
            }

            VStack(spacing: 10) {
                Button(action: onContinue) {
                    Text(L10n.Onboarding.getStarted)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)

                Text(L10n.Onboarding.footer)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
        }
        .frame(width: 420, height: 520)
    }

    @ViewBuilder
    private var appMark: some View {
        if let image = NSApplication.shared.applicationIconImage {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .frame(width: 72, height: 72)
                .accessibilityHidden(true)
        } else {
            Image(systemName: "paperclip.circle.fill")
                .font(.system(size: 56))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
        }
    }
}

private struct OnboardingStep: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .nativeInsetBackground()
        .accessibilityElement(children: .combine)
    }
}