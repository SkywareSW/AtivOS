cmake_minimum_required(VERSION 3.16)
project(ativos-oobe VERSION 1.0 LANGUAGES CXX)

set(CMAKE_AUTOMOC ON)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_INCLUDE_CURRENT_DIR ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2 QuickDialogs2)

qt_standard_project_setup(REQUIRES 6.5)

qt_add_executable(ativos-oobe
    main.cpp
    oobebackend.cpp
    oobebackend.h
)

qt_add_qml_module(ativos-oobe
    URI org.ativos.oobe
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/Theme.qml
        qml/components/PillButton.qml
        qml/pages/WelcomePage.qml
        qml/pages/LanguagePage.qml
        qml/pages/AppearancePage.qml
        qml/pages/NetworkPage.qml
        qml/pages/PrivacyPage.qml
        qml/pages/AvatarPage.qml
        qml/pages/FinishPage.qml
    RESOURCES
        assets/logo.png
)

target_link_libraries(ativos-oobe PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::QuickDialogs2
)

install(TARGETS ativos-oobe RUNTIME DESTINATION bin)
