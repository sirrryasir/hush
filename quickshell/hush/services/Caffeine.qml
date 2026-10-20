pragma Singleton
import QtQuick
import Quickshell

// Stay awake: while `on`, every island window holds a Wayland idle inhibitor (IslandWindow), so
// hypridle keeps running but never locks or sleeps the session. The control center's `caffeine`
// tile flips it; the status ring shows a cup. Until off: a shell restart drops it.
Singleton { property bool on: false }
