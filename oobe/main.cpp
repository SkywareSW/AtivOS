#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QIcon>
#include <QUrl>

#include "oobebackend.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("AtivOS Setup Assistant"));
    app.setOrganizationName(QStringLiteral("AtivOS"));
    app.setDesktopFileName(QStringLiteral("org.ativos.oobe"));
    app.setWindowIcon(QIcon::fromTheme(QStringLiteral("ativos-logo")));

    OobeBackend backend;

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("Backend"), &backend);
    engine.load(QUrl(QStringLiteral("qrc:/qt/qml/org/ativos/oobe/qml/Main.qml")));

    if (engine.rootObjects().isEmpty()) {
        return -1;
    }

    return app.exec();
}
