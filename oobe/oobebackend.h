#pragma once

#include <QObject>
#include <QString>
#include <QStringList>

class OobeBackend : public QObject
{
    Q_OBJECT

public:
    explicit OobeBackend(QObject *parent = nullptr);

    Q_INVOKABLE QString currentUser() const;
    Q_INVOKABLE QVariantList availableLanguages() const;

    // Language / region — per-user session override, no root needed.
    Q_INVOKABLE void applyLanguage(const QString &localeCode);

    // Appearance — Plasma color scheme + accent color, no root needed.
    Q_INVOKABLE void applyAppearance(bool darkMode, const QString &accentHex);

    // Network — best-effort connectivity probe + hand off to Plasma's own
    // network KCM (which handles its own polkit/wifi-password prompts).
    Q_INVOKABLE bool checkNetwork() const;
    Q_INVOKABLE void openNetworkSettings() const;

    // Privacy — local preference only, stored for future AtivOS components
    // to respect. AtivOS has no telemetry today; this just records the
    // choice.
    Q_INVOKABLE void setTelemetry(bool enabled);

    // Avatar — writes ~/.face.icon immediately (no root), and best-effort
    // updates AccountsService (used by SDDM) via a small polkit-gated
    // helper.
    Q_INVOKABLE bool setAvatar(const QString &localFilePath);

    // Called on the last page — marks first-run complete so the autostart
    // launcher won't show this again, then quits.
    Q_INVOKABLE void finish();
};
