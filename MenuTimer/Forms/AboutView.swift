//
//  AboutView.swift
//  MenuTimer
//
//  SwiftUI About window: icon, name, version, author and a decorative tagline.
//

import SwiftUI

/// The contents of the About window.
struct AboutView: View {

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "timer")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.tint)
                .padding(.top, 8)

            Text(AppInfo.name)
                .font(.title2.weight(.semibold))

            Text(AppInfo.versionDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Timers & alarms that live in your menu bar.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            Divider()
                .padding(.horizontal, 40)

            Text(AppInfo.author)
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .padding(24)
        .frame(width: 300, height: 280)
    }
}

#if DEBUG
#Preview {
    AboutView()
}
#endif
