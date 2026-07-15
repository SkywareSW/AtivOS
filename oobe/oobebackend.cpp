#include "oobebackend.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QImage>
#include <QProcess>
#include <QSettings>
#include <QStandardPaths>
#include <QVariantList>
#include <QVariantMap>

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

void OobeBackend::setTelemetry(bool enabled)
{
    QSettings settings(ativosConfigPath(), QSettings::IniFormat);
    settings.setValue(QStringLiteral("telemetry"), enabled);
    settings.sync();
}

bool OobeBackend::setAvatar(const QString &localFilePath)
{
    QString path = localFilePath;
    // QML file dialogs return file:// URLs.
    if (path.startsWith(QStringLiteral("file://"))) {
        path = path.mid(7);
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
