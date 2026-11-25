cmake_minimum_required(VERSION 4.1)

project(Fcitx5Osk LANGUAGES C)

include(GNUInstallDirs)

# Where are binaries installed
set(INSTALL_BIN_DIR "${CMAKE_INSTALL_FULL_BINDIR}")

# Where is data installed
set(INSTALL_DATA_DIR "${CMAKE_INSTALL_FULL_DATADIR}")

# Where to install dbus config
set(DBUS_CONFIG_PARENT_DIR "/etc" CACHE PATH "The parent directory of dbus config directory")

# Where to run cargo
set(CARGO_TARGET_DIR ${CMAKE_BINARY_DIR}/cargo_target)

add_subdirectory(fcitx5-osk-kwin-launcher)

# Tell CMake to build Rust binary
add_custom_target(build_rust ALL
    COMMAND cargo build --release --target-dir ${CARGO_TARGET_DIR}
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
)

# Rust binary full path
set(FCITX5_OSK_BIN ${CARGO_TARGET_DIR}/release/fcitx5-osk-ja)
set(FCITX5_OSK_KEY_HELPER_BIN ${CARGO_TARGET_DIR}/release/fcitx5-osk-ja-key-helper)
set(FCITX5_OSK_KWIN_LAUNCHER_BIN ${CARGO_TARGET_DIR}/release/fcitx5-osk-ja-kwin-launcher)

# Configure files
configure_file(${CMAKE_SOURCE_DIR}/pkg/share/applications/xyz.enoki.fcitx5.osk.desktop.in
    ${CMAKE_BINARY_DIR}/share/applications/xyz.enoki.fcitx5.osk.desktop
    @ONLY
)
configure_file(${CMAKE_SOURCE_DIR}/pkg/share/dbus-1/services/xyz.enoki.fcitx5.osk.service.in
    ${CMAKE_BINARY_DIR}/share/dbus-1/services/xyz.enoki.fcitx5.osk.service
    @ONLY
)
configure_file(${CMAKE_SOURCE_DIR}/pkg/lib/systemd/system/fcitx5-osk-ja-key-helper.service.in
    ${CMAKE_BINARY_DIR}/lib/systemd/system/fcitx5-osk-ja-key-helper.service
    @ONLY
)
configure_file(${CMAKE_SOURCE_DIR}/pkg/share/applications/xyz.enoki.fcitx5.osk.KwinLauncher.desktop.in
    ${CMAKE_BINARY_DIR}/share/applications/xyz.enoki.fcitx5.osk.KwinLauncher.desktop
    @ONLY
)
configure_file(${CMAKE_SOURCE_DIR}/pkg/share/dbus-1/services/xyz.enoki.fcitx5.osk.KwinLauncher.service.in
    ${CMAKE_BINARY_DIR}/share/dbus-1/services/xyz.enoki.fcitx5.osk.KwinLauncher.service
    @ONLY
)
file(MAKE_DIRECTORY "${CMAKE_BINARY_DIR}/etc/xdg/fcitx5-osk-ja/themes")
file(CREATE_LINK
        ${CMAKE_INSTALL_FULL_DATADIR}/fcitx5-osk-ja/themes/breeze-light.toml
        ${CMAKE_BINARY_DIR}/etc/xdg/fcitx5-osk-ja/themes/breeze-light.toml
        SYMBOLIC
)

# Install fcitx5-osk's executables
install(PROGRAMS
        ${FCITX5_OSK_BIN}
        ${FCITX5_OSK_KEY_HELPER_BIN}
    TYPE BIN
    COMPONENT Fcitx5Osk
)

# Install fcitx5-osk's data files
install(FILES
        ${CMAKE_BINARY_DIR}/share/applications/xyz.enoki.fcitx5.osk.desktop
    DESTINATION ${CMAKE_INSTALL_DATADIR}/applications
    COMPONENT Fcitx5Osk
)
install(FILES
        ${CMAKE_BINARY_DIR}/share/dbus-1/services/xyz.enoki.fcitx5.osk.service
    DESTINATION ${CMAKE_INSTALL_DATADIR}/dbus-1/services
    COMPONENT Fcitx5Osk
)
install(FILES
        ${CMAKE_SOURCE_DIR}/assets/icons/fcitx5-osk.svg
    DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/scalable/apps
    RENAME xyz.enoki.fcitx5.osk.svg
    COMPONENT Fcitx5Osk
)
install(FILES
        ${CMAKE_SOURCE_DIR}/LICENSE
    DESTINATION ${CMAKE_INSTALL_DATADIR}/licenses/fcitx5-osk-ja
    COMPONENT Fcitx5Osk
)
install(DIRECTORY
        ${CMAKE_SOURCE_DIR}/pkg/share/fcitx5-osk-ja
    TYPE DATA
    COMPONENT Fcitx5Osk
)
install(DIRECTORY
        ${CMAKE_SOURCE_DIR}/assets/layouts
        ${CMAKE_SOURCE_DIR}/assets/key_sets
    DESTINATION ${CMAKE_INSTALL_DATADIR}/fcitx5-osk-ja/examples
    COMPONENT Fcitx5Osk
)
install(FILES
        ${CMAKE_BINARY_DIR}/share/dbus-1/services/xyz.enoki.fcitx5.osk.service
    DESTINATION ${CMAKE_INSTALL_DATADIR}/dbus-1/services
    COMPONENT Fcitx5Osk
)

# Install fcitx5-osk's lib files
install(FILES
        ${CMAKE_BINARY_DIR}/lib/systemd/system/fcitx5-osk-ja-key-helper.service
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/systemd/system
    COMPONENT Fcitx5Osk
)

# Install fcitx5-osk's config
install(FILES
        ${CMAKE_SOURCE_DIR}/pkg/share/dbus-1/system.d/xyz.enoki.fcitx5.osk.KeyHelper.conf
    DESTINATION ${DBUS_CONFIG_PARENT_DIR}/dbus-1/system.d
    COMPONENT Fcitx5Osk
)
install(FILES
        ${CMAKE_BINARY_DIR}/etc/xdg/fcitx5-osk-ja/themes/breeze-light.toml
        DESTINATION /etc/xdg/fcitx5-osk-ja/themes
    COMPONENT Fcitx5Osk
)

# US配列レイアウト（default_landscape_layout = "us-landscape" で切り替え）
install(FILES
        ${CMAKE_SOURCE_DIR}/assets/layouts/us-landscape.toml
    DESTINATION /etc/xdg/fcitx5-osk-ja/layouts
    COMPONENT Fcitx5Osk
)

# Install fcitx5-osk-kwin-launcher's executable
install(PROGRAMS
        ${FCITX5_OSK_KWIN_LAUNCHER_BIN}
    TYPE BIN
    COMPONENT Fcitx5OskKwinLauncher
)

# Install fcitx5-osk-kwin-launcher's data files
install(FILES
        ${CMAKE_BINARY_DIR}/share/applications/xyz.enoki.fcitx5.osk.KwinLauncher.desktop
    DESTINATION ${CMAKE_INSTALL_DATADIR}/applications
    COMPONENT Fcitx5OskKwinLauncher
)
install(FILES
        ${CMAKE_BINARY_DIR}/share/dbus-1/services/xyz.enoki.fcitx5.osk.KwinLauncher.service
    DESTINATION ${CMAKE_INSTALL_DATADIR}/dbus-1/services
    COMPONENT Fcitx5OskKwinLauncher
)
install(FILES
        ${CMAKE_SOURCE_DIR}/LICENSE
    DESTINATION ${CMAKE_INSTALL_DATADIR}/licenses/fcitx5-osk-ja-kwin-launcher
    COMPONENT Fcitx5OskKwinLauncher
)
