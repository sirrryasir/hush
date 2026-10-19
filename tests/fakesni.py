#!/usr/bin/env python3
"""A StatusNotifierItem ("Fake Tray App") on the session bus with a two-entry DBusMenu, for tests.
Registers with org.kde.StatusNotifierWatcher (retrying until one exists) and appends "activate",
"secondary", "contextmenu" or "menu <id> <event>" to $HUSH_FAKE_LOG. Runs until killed.
Needs dbus-python and PyGObject; exits 3 if they are missing."""
import os, sys
try:
    import dbus, dbus.service, dbus.mainloop.glib
    from gi.repository import GLib
except ImportError:
    sys.exit(3)

dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
bus = dbus.SessionBus()
LOG = os.environ.get("HUSH_FAKE_LOG", "/dev/null")
def log(line): open(LOG, "a").write(line + "\n")
SNI, MENU, PROPS = "org.kde.StatusNotifierItem", "com.canonical.dbusmenu", "org.freedesktop.DBus.Properties"

class Item(dbus.service.Object):
    props = {"Category": "ApplicationStatus", "Id": "hushfake", "Title": "Fake Tray App", "Status": "Active",
             "IconName": "utilities-terminal", "Menu": dbus.ObjectPath("/MenuBar"), "ItemIsMenu": False}
    @dbus.service.method(PROPS, in_signature="ss", out_signature="v")
    def Get(self, i, p): return self.props[p]
    @dbus.service.method(PROPS, in_signature="s", out_signature="a{sv}")
    def GetAll(self, i): return self.props
    @dbus.service.method(SNI, in_signature="ii")
    def Activate(self, x, y): log("activate")
    @dbus.service.method(SNI, in_signature="ii")
    def SecondaryActivate(self, x, y): log("secondary")
    @dbus.service.method(SNI, in_signature="ii")
    def ContextMenu(self, x, y): log("contextmenu")
    @dbus.service.method(SNI, in_signature="is")
    def Scroll(self, delta, orientation): pass

class Menu(dbus.service.Object):
    entries = [(1, "Show window"), (2, "Quit")]
    props = {"Version": dbus.UInt32(3), "Status": "normal", "TextDirection": "ltr", "IconThemePath": dbus.Array([], signature="s")}
    @dbus.service.method(PROPS, in_signature="ss", out_signature="v")
    def Get(self, i, p): return self.props[p]
    @dbus.service.method(PROPS, in_signature="s", out_signature="a{sv}")
    def GetAll(self, i): return self.props
    @dbus.service.method(MENU, in_signature="iias", out_signature="u(ia{sv}av)")
    def GetLayout(self, parent, depth, names):
        node = lambda i, p, kids: dbus.Struct((dbus.Int32(i), dbus.Dictionary(p, signature="sv"), dbus.Array(kids, signature="v")), signature="ia{sv}av")
        kids = [node(i, {"label": l}, []) for i, l in self.entries if parent == 0]
        return dbus.UInt32(1), node(parent, {"children-display": "submenu"} if parent == 0 else {}, kids)
    @dbus.service.method(MENU, in_signature="aias", out_signature="a(ia{sv})")
    def GetGroupProperties(self, ids, names): return [(i, {"label": l}) for i, l in self.entries if not ids or i in ids]
    @dbus.service.method(MENU, in_signature="isvu")
    def Event(self, id, kind, data, ts): log("menu %d %s" % (id, kind))
    @dbus.service.method(MENU, in_signature="a(isvu)", out_signature="ai")
    def EventGroup(self, events): [self.Event(*e) for e in events]; return []
    @dbus.service.method(MENU, in_signature="i", out_signature="b")
    def AboutToShow(self, id): return False
    @dbus.service.method(MENU, in_signature="ai", out_signature="aiai")
    def AboutToShowGroup(self, ids): return [], []

Item(bus, "/StatusNotifierItem"); Menu(bus, "/MenuBar")
def register():  # True keeps the GLib timer going until a watcher takes the item
    try:
        bus.get_object("org.kde.StatusNotifierWatcher", "/StatusNotifierWatcher").RegisterStatusNotifierItem(
            bus.get_unique_name(), dbus_interface="org.kde.StatusNotifierWatcher")
        return False
    except dbus.DBusException:
        return True
if register(): GLib.timeout_add(500, register)
GLib.MainLoop().run()
