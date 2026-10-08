# Copyright (C) 2026 George Dobreff ("Witcher") and contributors
# SPDX-License-Identifier: GPL-3.0-only

qml_module(caelestia-config
    URI Caelestia.Config
    INCLUDE_PREFIX config
    SOURCES
        common.cpp
        rootnodes.cpp
        configattached.cpp
        appearanceconfig.cpp
        borderconfig.cpp
        font.cpp
        fontbuilder.cpp
        tokensattached.cpp
        anim.cpp
        enums.hpp
        backgroundconfig.hpp
        barconfig.hpp
        dashboardconfig.hpp
        generalconfig.hpp
        launcherconfig.hpp
        lockconfig.hpp
        nexusconfig.hpp
        notifsconfig.hpp
        osdconfig.hpp
        serviceconfig.hpp
        sessionconfig.hpp
        sidebarconfig.hpp
        userpaths.hpp
        utilitiesconfig.hpp
        tokens.hpp
    LIBRARIES
        Qt::Quick
        Qt::QuickControls2
    DEPENDENCIES
        Caelestia.Settings
)
target_link_libraries(caelestia-config PUBLIC
    Qt::Gui
    caelestia-util
    caelestia-core
    caelestia-settings
)
