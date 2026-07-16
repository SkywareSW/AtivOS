#include "oobebackend.h"

#include <QCoreApplication>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QImage>
#include <QProcess>
#include <QRegularExpression>
#include <QSettings>
#include <QStandardPaths>
#include <QTemporaryFile>
#include <QTextStream>
#include <QVariantList>
#include <QVariantMap>

namespace {
// Where the preset avatar images live inside the Qt resource system, per
// qt_add_qml_module's URI-derived resource path (org.ativos.oobe -> org/ativos/oobe).
const char *kPresetAvatarResourceDir = ":/qt/qml/org/ativos/oobe/assets/avatars";
}

namespace {

QString configDir()
{
    QString dir = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation);
    return dir;
}

QString ativosConfigPath()
{
    QDir dir(configDir() + QStringLiteral("/ativos"));
    if (!dir.exists()) {
        dir.mkpath(QStringLiteral("."));
    }
    return dir.filePath(QStringLiteral("oobe.conf"));
}

// Runs the root helper with the given subcommand + args via pkexec, gated
// by the org.ativos.oobe.systemconfig polkit action (allow_active, so this
// doesn't stall the wizard on a password prompt for the same user that's
// already authenticated at the console). Optional stdin payload is used
// for anything sensitive (passwords) so it never shows up in `ps`.
bool runSystemConfigHelper(const QStringList &args, const QString &stdinPayload = QString())
{
    QStringList fullArgs = {QStringLiteral("/usr/local/bin/ativos-system-config")};
    fullArgs += args;

    QProcess proc;
    proc.start(QStringLiteral("pkexec"), fullArgs);
    if (!proc.waitForStarted(3000)) {
        return false;
    }
    if (!stdinPayload.isEmpty()) {
        proc.write(stdinPayload.toUtf8());
    }
    proc.closeWriteChannel();
    proc.waitForFinished(15000);
    return proc.exitStatus() == QProcess::NormalExit && proc.exitCode() == 0;
}

} // namespace

OobeBackend::OobeBackend(QObject *parent)
    : QObject(parent)
{
}

QString OobeBackend::currentUser() const
{
    QString user = qEnvironmentVariable("USER");
    if (user.isEmpty()) {
        user = qEnvironmentVariable("LOGNAME");
    }
    return user;
}

QVariantList OobeBackend::availableLanguages() const
{
    // A curated, always-available shortlist rather than parsing the full
    // glibc locale archive — this only sets the *session* display language
    // (system LANG was already chosen during install). Keeps the picker
    // fast and predictable regardless of what got generated at install time.
    struct Entry { const char *code; const char *label; };
    static const Entry entries[] = {
        {"en_US", "English (United States)"},
        {"en_GB", "English (United Kingdom)"},
        {"de_DE", "Deutsch"},
        {"fr_FR", "Français"},
        {"es_ES", "Español"},
        {"it_IT", "Italiano"},
        {"pt_BR", "Português (Brasil)"},
        {"nl_NL", "Nederlands"},
        {"tr_TR", "Türkçe"},
        {"pl_PL", "Polski"},
        {"ru_RU", "Русский"},
        {"el_GR", "Ελληνικά"},
        {"ja_JP", "日本語"},
        {"ko_KR", "한국어"},
        {"zh_CN", "简体中文"},
    };

    QVariantList list;
    for (const auto &e : entries) {
        QVariantMap m;
        m["code"] = QString::fromLatin1(e.code);
        m["label"] = QString::fromUtf8(e.label);
        list.append(m);
    }
    return list;
}

void OobeBackend::applyLanguage(const QString &localeCode)
{
    // Plasma reads this file for a per-user locale override, independent of
    // the system-wide /etc/locale.conf written by the installer.
    QSettings settings(configDir() + QStringLiteral("/plasma-localerc"), QSettings::IniFormat);
    const QString locale = localeCode + QStringLiteral(".UTF-8");
    settings.beginGroup(QStringLiteral("Formats"));
    settings.setValue(QStringLiteral("LANG"), locale);
    settings.endGroup();
    settings.beginGroup(QStringLiteral("Translations"));
    settings.setValue(QStringLiteral("LANGUAGE"), localeCode);
    settings.endGroup();
    settings.sync();
}

QVariantList OobeBackend::availableTimezones() const
{
    // A curated shortlist of major-city zones covering every UTC offset,
    // rather than the full ~600-entry IANA tzdata list — fast to scroll,
    // and every real timezone shares a name with (or is a short hop from)
    // one of these in the picker's search field.
    struct Entry { const char *id; const char *label; };
    static const Entry entries[] = {
        {"Pacific/Midway", "Midway Island (UTC−11)"},
        {"Pacific/Honolulu", "Honolulu (UTC−10)"},
        {"America/Anchorage", "Anchorage (UTC−9)"},
        {"America/Los_Angeles", "Los Angeles (UTC−8)"},
        {"America/Denver", "Denver (UTC−7)"},
        {"America/Chicago", "Chicago (UTC−6)"},
        {"America/New_York", "New York (UTC−5)"},
        {"America/Halifax", "Halifax (UTC−4)"},
        {"America/Sao_Paulo", "São Paulo (UTC−3)"},
        {"Atlantic/Azores", "Azores (UTC−1)"},
        {"UTC", "Coordinated Universal Time (UTC)"},
        {"Europe/London", "London (UTC+0)"},
        {"Europe/Paris", "Paris (UTC+1)"},
        {"Europe/Berlin", "Berlin (UTC+1)"},
        {"Europe/Athens", "Athens (UTC+2)"},
        {"Europe/Nicosia", "Nicosia (UTC+2)"},
        {"Europe/Bucharest", "Bucharest (UTC+2)"},
        {"Europe/Moscow", "Moscow (UTC+3)"},
        {"Asia/Istanbul", "Istanbul (UTC+3)"},
        {"Asia/Dubai", "Dubai (UTC+4)"},
        {"Asia/Karachi", "Karachi (UTC+5)"},
        {"Asia/Kolkata", "Mumbai / Delhi (UTC+5:30)"},
        {"Asia/Dhaka", "Dhaka (UTC+6)"},
        {"Asia/Bangkok", "Bangkok (UTC+7)"},
        {"Asia/Shanghai", "Shanghai (UTC+8)"},
        {"Asia/Singapore", "Singapore (UTC+8)"},
        {"Asia/Tokyo", "Tokyo (UTC+9)"},
        {"Asia/Seoul", "Seoul (UTC+9)"},
        {"Australia/Sydney", "Sydney (UTC+10)"},
        {"Pacific/Auckland", "Auckland (UTC+12)"},
    };

    QVariantList list;
    for (const auto &e : entries) {
        QVariantMap m;
        m["id"] = QString::fromLatin1(e.id);
        m["label"] = QString::fromUtf8(e.label);
        list.append(m);
    }
    return list;
}

QString OobeBackend::currentTimezone() const
{
    // /etc/localtime is a symlink into the tzdata zoneinfo tree; the part
    // after ".../zoneinfo/" is the IANA id (e.g. "Europe/Nicosia").
    QFileInfo link(QStringLiteral("/etc/localtime"));
    if (!link.isSymLink()) {
        return QStringLiteral("UTC");
    }
    QString target = link.symLinkTarget();
    int idx = target.indexOf(QStringLiteral("zoneinfo/"));
    if (idx < 0) {
        return QStringLiteral("UTC");
    }
    return target.mid(idx + QStringLiteral("zoneinfo/").length());
}

bool OobeBackend::applyTimezone(const QString &tzId)
{
    return runSystemConfigHelper({QStringLiteral("timezone"), tzId});
}

QVariantList OobeBackend::availableKeyboardLayouts() const
{
    struct Entry { const char *code; const char *label; };
    static const Entry entries[] = {
        {"us", "US (QWERTY)"},
        {"gb", "UK"},
        {"de", "German"},
        {"fr", "French (AZERTY)"},
        {"es", "Spanish"},
        {"it", "Italian"},
        {"pt", "Portuguese"},
        {"nl", "Dutch"},
        {"tr", "Turkish"},
        {"pl", "Polish"},
        {"ru", "Russian"},
        {"gr", "Greek"},
        {"jp", "Japanese"},
        {"kr", "Korean"},
        {"cn", "Chinese"},
    };

    QVariantList list;
    for (const auto &e : entries) {
        QVariantMap m;
        m["code"] = QString::fromLatin1(e.code);
        m["label"] = QString::fromUtf8(e.label);
        list.append(m);
    }
    return list;
}

QString OobeBackend::currentKeyboardLayout() const
{
    QProcess proc;
    proc.start(QStringLiteral("localectl"), {QStringLiteral("status")});
    proc.waitForFinished(3000);
    const QString out = QString::fromUtf8(proc.readAllStandardOutput());
    QRegularExpression re(QStringLiteral("X11 Layout:\\s*(\\S+)"));
    auto match = re.match(out);
    if (match.hasMatch()) {
        return match.captured(1);
    }
    return QStringLiteral("us");
}

bool OobeBackend::applyKeyboardLayout(const QString &layoutCode)
{
    // Apply live to the current session immediately (no root) so the
    // change is visible right away in the wizard itself...
    QProcess::execute(QStringLiteral("setxkbmap"), {layoutCode});
    // ...and persist it system-wide (root, via the helper) so it survives
    // to the login screen and every other session.
    return runSystemConfigHelper({QStringLiteral("keymap"), layoutCode});
}

void OobeBackend::applyAppearance(bool darkMode, const QString &accentHex)
{
    const QString scheme = darkMode ? QStringLiteral("BreezeDark") : QStringLiteral("BreezeLight");

    QProcess::execute(QStringLiteral("plasma-apply-colorscheme"), {scheme});
    QProcess::execute(QStringLiteral("plasma-apply-lookandfeel"), {
        QStringLiteral("-a"),
        darkMode ? QStringLiteral("org.kde.breezedark.desktop") : QStringLiteral("org.kde.breeze.desktop")
    });

    if (!accentHex.isEmpty()) {
        QProcess::execute(QStringLiteral("kwriteconfig6"), {
            QStringLiteral("--file"), QStringLiteral("kdeglobals"),
            QStringLiteral("--group"), QStringLiteral("General"),
            QStringLiteral("--key"), QStringLiteral("AccentColor"),
            accentHex
        });
        QProcess::execute(QStringLiteral("kwriteconfig6"), {
            QStringLiteral("--file"), QStringLiteral("kdeglobals"),
            QStringLiteral("--group"), QStringLiteral("General"),
            QStringLiteral("--key"), QStringLiteral("AccentColorFromWallpaper"),
            QStringLiteral("false")
        });
    }
}

QString OobeBackend::currentFullName() const
{
    QProcess proc;
    proc.start(QStringLiteral("getent"), {QStringLiteral("passwd"), currentUser()});
    proc.waitForFinished(3000);
    const QString line = QString::fromUtf8(proc.readAllStandardOutput()).trimmed();
    const QStringList fields = line.split(QStringLiteral(":"));
    if (fields.size() >= 5) {
        // GECOS field is comma-separated; full name is the first part.
        return fields.at(4).split(QStringLiteral(",")).value(0);
    }
    return QString();
}

QString OobeBackend::currentHostname() const
{
    QProcess proc;
    proc.start(QStringLiteral("hostnamectl"), {QStringLiteral("hostname")});
    proc.waitForFinished(3000);
    return QString::fromUtf8(proc.readAllStandardOutput()).trimmed();
}

bool OobeBackend::setFullName(const QString &fullName)
{
    if (fullName.trimmed().isEmpty()) {
        return true;
    }
    return runSystemConfigHelper({QStringLiteral("fullname"), currentUser(), fullName.trimmed()});
}

bool OobeBackend::setHostname(const QString &hostname)
{
    static const QRegularExpression valid(QStringLiteral("^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$"));
    if (!valid.match(hostname).hasMatch()) {
        return false;
    }
    return runSystemConfigHelper({QStringLiteral("hostname"), hostname});
}

bool OobeBackend::setPassword(const QString &newPassword)
{
    if (newPassword.isEmpty()) {
        return false;
    }
    // Password travels over the helper's stdin, never as an argv entry
    // (argv is visible to every user via `ps`).
    const QString payload = currentUser() + QStringLiteral("\n") + newPassword + QStringLiteral("\n");
    return runSystemConfigHelper({QStringLiteral("password")}, payload);
}

bool OobeBackend::isUsernameAvailable(const QString &username) const
{
    static const QRegularExpression valid(QStringLiteral("^[a-z_][a-z0-9_-]{0,31}$"));
    if (!valid.match(username).hasMatch()) {
        return false;
    }
    QProcess proc;
    proc.start(QStringLiteral("id"), {username});
    proc.waitForFinished(3000);
    // Exit code non-zero means "no such user" — i.e. available.
    return proc.exitCode() != 0;
}

bool OobeBackend::renameUsername(const QString &newUsername)
{
    if (newUsername.isEmpty() || newUsername == currentUser()) {
        return true;
    }
    if (!isUsernameAvailable(newUsername)) {
        return false;
    }
    return runSystemConfigHelper({QStringLiteral("rename"), currentUser(), newUsername});
}

bool OobeBackend::checkNetwork() const
{
    // nmcli is always present (NetworkManager is enabled by the base
    // installer). "full" means connected with internet reachability.
    QProcess proc;
    proc.start(QStringLiteral("nmcli"), {QStringLiteral("-t"), QStringLiteral("-f"), QStringLiteral("CONNECTIVITY"), QStringLiteral("networking")});
    proc.waitForFinished(3000);
    const QString out = QString::fromUtf8(proc.readAllStandardOutput()).trimmed();
    if (!out.isEmpty()) {
        return out.contains(QStringLiteral("full"), Qt::CaseInsensitive);
    }
    // Fallback if nmcli's connectivity check is disabled: just see if a
    // default route exists.
    QProcess fallback;
    fallback.start(QStringLiteral("nmcli"), {QStringLiteral("-t"), QStringLiteral("-f"), QStringLiteral("STATE"), QStringLiteral("g")});
    fallback.waitForFinished(3000);
    return QString::fromUtf8(fallback.readAllStandardOutput()).trimmed().compare(QStringLiteral("connected"), Qt::CaseInsensitive) == 0;
}

void OobeBackend::openNetworkSettings() const
{
    QProcess::startDetached(QStringLiteral("kcmshell6"), {QStringLiteral("kcm_networkmanagement")});
}

bool OobeBackend::gameModeEnabled() const
{
    QProcess proc;
    proc.start(QStringLiteral("systemctl"), {QStringLiteral("--user"), QStringLiteral("is-enabled"), QStringLiteral("gamemoded")});
    proc.waitForFinished(3000);
    return QString::fromUtf8(proc.readAllStandardOutput()).trimmed().compare(QStringLiteral("enabled")) == 0;
}

void OobeBackend::setGameMode(bool enabled)
{
    // gamemoded runs as a per-user systemd service — no root required.
    QProcess::execute(QStringLiteral("systemctl"), {
        QStringLiteral("--user"),
        enabled ? QStringLiteral("enable") : QStringLiteral("disable"),
        QStringLiteral("--now"),
        QStringLiteral("gamemoded")
    });
    QSettings settings(ativosConfigPath(), QSettings::IniFormat);
    settings.setValue(QStringLiteral("gameMode"), enabled);
    settings.sync();
}

bool OobeBackend::mangoHudEnabled() const
{
    QSettings settings(ativosConfigPath(), QSettings::IniFormat);
    return settings.value(QStringLiteral("mangoHud"), false).toBool();
}

void OobeBackend::setMangoHudEnabled(bool enabled)
{
    // MangoHud stays opt-in per launch (`mangohud %command%`); this just
    // records whether the user wants it pre-selected by default in the
    // AtivOS game launcher integration, and drops a MANGOHUD=1 default
    // into the user's environment.d so a plain `mangohud` invocation with
    // no extra flags still picks up AtivOS's tuned overlay layout.
    QSettings settings(ativosConfigPath(), QSettings::IniFormat);
    settings.setValue(QStringLiteral("mangoHud"), enabled);
    settings.sync();

    const QString envDir = QDir::homePath() + QStringLiteral("/.config/environment.d");
    QDir().mkpath(envDir);
    QFile envFile(envDir + QStringLiteral("/ativos-mangohud.conf"));
    if (envFile.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        QTextStream out(&envFile);
        if (enabled) {
            out << "MANGOHUD=1\n";
        }
        envFile.close();
    }
}

QString OobeBackend::performanceProfile() const
{
    QSettings settings(ativosConfigPath(), QSettings::IniFormat);
    return settings.value(QStringLiteral("performanceProfile"), QStringLiteral("balanced")).toString();
}

bool OobeBackend::applyPerformanceProfile(const QString &profileId)
{
    QString sched;
    if (profileId == QStringLiteral("responsive")) {
        sched = QStringLiteral("scx_bpfland");
    } else if (profileId == QStringLiteral("battery")) {
        sched = QStringLiteral("scx_lavd");
    } else {
        sched = QStringLiteral("scx_rusty");
    }

    const bool ok = runSystemConfigHelper({QStringLiteral("scheduler"), sched});
    if (ok) {
        QSettings settings(ativosConfigPath(), QSettings::IniFormat);
        settings.setValue(QStringLiteral("performanceProfile"), profileId);
        settings.sync();
    }
    return ok;
}

QVariantList OobeBackend::availableOptionalApps() const
{
    struct Entry { const char *id; const char *name; const char *description; const char *manager; const char *pkg; };
    static const Entry entries[] = {
        {"steam", "Steam", "Valve's game store and Proton compatibility layer.", "pacman", "steam"},
        {"vscode", "VS Code", "Microsoft's code editor, via Flathub.", "flatpak", "com.visualstudio.code"},
        {"gimp", "GIMP", "Free, full-featured image editor.", "pacman", "gimp"},
        {"vlc", "VLC", "Plays almost any video or audio file.", "pacman", "vlc"},
        {"libreoffice", "LibreOffice", "Full office suite — docs, sheets, slides.", "pacman", "libreoffice-fresh"},
        {"obs", "OBS Studio", "Screen recording and live streaming.", "pacman", "obs-studio"},
    };

    QVariantList list;
    for (const auto &e : entries) {
        QVariantMap m;
        m["id"] = QString::fromLatin1(e.id);
        m["name"] = QString::fromLatin1(e.name);
        m["description"] = QString::fromLatin1(e.description);
        m["manager"] = QString::fromLatin1(e.manager);
        m["pkg"] = QString::fromLatin1(e.pkg);
        list.append(m);
    }
    return list;
}

void OobeBackend::installOptionalApps(const QVariantList &appIds)
{
    if (appIds.isEmpty()) {
        return;
    }

    const QVariantList all = availableOptionalApps();
    QStringList specs;
    for (const QVariant &idVar : appIds) {
        const QString id = idVar.toString();
        for (const QVariant &entryVar : all) {
            const QVariantMap entry = entryVar.toMap();
            if (entry["id"].toString() == id) {
                specs << entry["manager"].toString() + QStringLiteral(":") + entry["pkg"].toString();
                break;
            }
        }
    }
    if (specs.isEmpty()) {
        return;
    }

    // Fire-and-forget: package installs can take minutes, and the wizard
    // shouldn't block on them. The helper runs detached under pkexec and
    // keeps going after this process (and the wizard) exits.
    QStringList args = {QStringLiteral("/usr/local/bin/ativos-system-config"), QStringLiteral("install-apps")};
    args += specs;
    QProcess::startDetached(QStringLiteral("pkexec"), args);
}

void OobeBackend::setTelemetry(bool enabled)
{
    QSettings settings(ativosConfigPath(), QSettings::IniFormat);
    settings.setValue(QStringLiteral("telemetry"), enabled);
    settings.sync();
}

QVariantList OobeBackend::availablePresetAvatars() const
{
    QVariantList result;
    QDirIterator it(QString::fromLatin1(kPresetAvatarResourceDir), QStringList{"*.png", "*.jpg", "*.jpeg"},
                     QDir::Files, QDirIterator::NoIteratorFlags);
    while (it.hasNext()) {
        it.next();
        // Files baked in via qt_add_qml_module's RESOURCES live under ":/qt/qml/...";
        // QML wants the "qrc:" URL scheme form of that same path.
        result.append(QStringLiteral("qrc") + it.filePath());
    }
    return result;
}

bool OobeBackend::setAvatar(const QString &localFilePath)
{
    QString path = localFilePath;
    // QML file dialogs return file:// URLs.
    if (path.startsWith(QStringLiteral("file://"))) {
        path = path.mid(7);
    }

    // Built-in presets are baked into the binary's Qt resource system and
    // arrive here as "qrc:/..." URLs — not real files on disk, so the
    // pkexec helper below can't read them directly. Copy the bytes out to
    // a real temp file first and continue as if that were the chosen file.
    QTemporaryFile presetExtract;
    if (path.startsWith(QStringLiteral("qrc:"))) {
        const QString resourcePath = path.mid(3); // "qrc:/foo" -> ":/foo"
        QFile resourceFile(resourcePath);
        if (!resourceFile.open(QIODevice::ReadOnly)) {
            return false;
        }
        presetExtract.setFileTemplate(QDir::tempPath() + QStringLiteral("/ativos-avatar-XXXXXX.png"));
        if (!presetExtract.open()) {
            return false;
        }
        presetExtract.write(resourceFile.readAll());
        presetExtract.close();
        path = presetExtract.fileName();
    }

    if (!QFile::exists(path)) {
        return false;
    }

    // 1. Standard freedesktop user face icon — several tools honor this
    //    directly with no root needed.
    QImage img(path);
    if (!img.isNull()) {
        const QImage scaled = img.scaled(256, 256, Qt::KeepAspectRatioByExpanding, Qt::SmoothTransformation);
        const int x = (scaled.width() - 256) / 2;
        const int y = (scaled.height() - 256) / 2;
        const QImage cropped = scaled.copy(x, y, 256, 256);
        const QString facePath = QDir::homePath() + QStringLiteral("/.face.icon");
        cropped.save(facePath, "PNG");
        QFile::remove(QDir::homePath() + QStringLiteral("/.face"));
        QFile::link(facePath, QDir::homePath() + QStringLiteral("/.face"));
    }

    // 2. AccountsService — what SDDM's Breeze theme actually reads for the
    //    login screen face. Requires root; gated by the
    //    org.ativos.oobe.setavatar polkit action (allow_active, so this
    //    doesn't prompt for a password mid-wizard).
    QProcess proc;
    proc.start(QStringLiteral("pkexec"), {
        QStringLiteral("/usr/local/bin/ativos-set-avatar"),
        currentUser(),
        path
    });
    proc.waitForFinished(5000);
    return true;
}

void OobeBackend::finish()
{
    QDir dir(configDir() + QStringLiteral("/ativos"));
    if (!dir.exists()) {
        dir.mkpath(QStringLiteral("."));
    }
    QFile marker(dir.filePath(QStringLiteral("oobe-done")));
    marker.open(QIODevice::WriteOnly);
    marker.close();

    QCoreApplication::quit();
}
