import QtQuick
import Caelestia.I18n

// Keyboard, mouse and trackpad: the input options people actually change
HyprlandPage {
    title: Tr.tr("Keyboard & trackpad")
    keyboardExtras: true
    only: ["input:kb_layout", "input:kb_variant", "input:kb_options", "input:repeat_rate", "input:repeat_delay", "input:numlock_by_default", "input:sensitivity", "input:accel_profile", "input:natural_scroll", "input:scroll_factor", "input:left_handed", "input:follow_mouse", "input:touchpad:natural_scroll", "input:touchpad:tap-to-click", "input:touchpad:disable_while_typing", "input:touchpad:clickfinger_behavior", "input:touchpad:scroll_factor", "input:touchpad:drag_lock", "gestures:workspace_swipe_distance", "gestures:workspace_swipe_invert", "cursor:hide_on_key_press", "cursor:inactive_timeout"]
}
