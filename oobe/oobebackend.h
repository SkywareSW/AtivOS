#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariant>

class OobeBackend : public QObject
{
    Q_OBJECT

public:
    explicit OobeBackend(QObject *parent = nullptr);

    Q_INVOKABLE QString currentUser() const;
    Q_INVOKABLE QVariantList availableLanguages() const;

    // Language / region — per-user session override, no root needed.
    Q_INVOKABLE void applyLanguage(const QString &localeCode);

    // Timezone & keyboard — system-wide, root required via the
    // org.ativos.oobe.systemconfig polkit action.
    Q_INVOKABLE QVariantList availableTimezones() const;
    Q_INVOKABLE QString currentTimezone() const;
    Q_INVOKABLE bool applyTimezone(const QString &tzId);
    Q_INVOKABLE QVariantList availableKeyboardLayouts() const;
    Q_INVOKABLE QString currentKeyboardLayout() const;
    Q_INVOKABLE bool applyKeyboardLayout(const QString &layoutCode);

    // Appearance — Plasma color scheme + accent color, no root needed.
    Q_INVOKABLE void applyAppearance(bool darkMode, const QString &accentHex);

    // Account — full name, hostname, password, and (optionally) username
    // all route through the same root helper as the other system-wide
    // settings below.
    Q_INVOKABLE QString currentFullName() const;
    Q_INVOKABLE QString currentHostname() const;
    Q_INVOKABLE bool setFullName(const QString &fullName);
    Q_INVOKABLE bool setHostname(const QString &hostname);
    Q_INVOKABLE bool setPassword(const QString &newPassword);
    Q_INVOKABLE bool isUsernameAvailable(const QString &username) const;
    Q_INVOKABLE bool renameUsername(const QString &newUsername);

    // Network — best-effort connectivity probe + hand off to Plasma's own
    // network KCM (which handles its own polkit/wifi-password prompts).
    Q_INVOKABLE bool checkNetwork() const;
    Q_INVOKABLE void openNetworkSettings() const;

    // Gaming / performance — gamemoded is a user-session service (no root),
    // MangoHud default is just a stored preference, scheduler profile
    // switching goes through scxctl (root, via the same helper).
    Q_INVOKABLE bool gameModeEnabled() const;
    Q_INVOKABLE void setGameMode(bool enabled);
    Q_INVOKABLE bool mangoHudEnabled() const;
    Q_INVOKABLE void setMangoHudEnabled(bool enabled);
    Q_INVOKABLE QString performanceProfile() const;
    Q_INVOKABLE bool applyPerformanceProfile(const QString &profileId);

    // Optional apps — installed best-effort in the background via the root
    // helper so the wizard never blocks waiting on a package manager.
    Q_INVOKABLE QVariantList availableOptionalApps() const;
    Q_INVOKABLE void installOptionalApps(const QVariantList &appIds);

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
