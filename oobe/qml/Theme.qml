pragma Singleton
import QtQuick

QtObject {
    // ---- palette ----------------------------------------------------
    readonly property color accent: "#5aa6ff"
    readonly property color accentBright: "#7fbcff"
    readonly property color bg: "#1b1c20"
    readonly property color bgElevated: "#232429"
    readonly property color textPrimary: "#f2f3f5"
    readonly property color textSecondary: "#9a9ca3"
    readonly property color divider: "#33343a"
    readonly property color cardBg: "#26272c"
    readonly property color accentForeground: "#0d1117"

    // ---- shape --------------------------------------------------------
    readonly property int radiusWindow: 22
    readonly property int radiusCard: 16
    readonly property int radiusControl: 12
    readonly property int radiusPill: 999

    // ---- motion (Tahoe-ish: quick, slightly springy) -------------------
    readonly property int durationFast: 120
    readonly property int durationMedium: 220
    readonly property int durationSlow: 360
    readonly property int easingStandard: Easing.OutCubic
    readonly property int easingSpring: Easing.OutBack
    readonly property real pressScale: 0.96
    readonly property real hoverScale: 1.02

    // ---- elevation ------------------------------------------------------
    readonly property color shadowColor: "#60000000"
}
