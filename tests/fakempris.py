#!/usr/bin/env python3
"""A minimal playing MPRIS player on the session bus (org.mpris.MediaPlayer2.hushfake), for tests.
Runs until killed. Needs dbus-python and PyGObject; exits 3 if they are missing."""
import os, sys, time, zlib, struct
try:
    import dbus, dbus.service, dbus.mainloop.glib
    from gi.repository import GLib
except ImportError:
    sys.exit(3)

dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
bus = dbus.SessionBus()
name = dbus.service.BusName("org.mpris.MediaPlayer2." + os.environ.get("HUSH_FAKE_NAME", "hushfake"), bus)

def tinted_art(path, size=160):
    """A diagonal gradient PNG (orange to violet) so tinting and cropping are visible in screenshots."""
    rows = b""
    for y in range(size):
        rows += b"\0" + b"".join(bytes((255 - 120 * x // size, 140 - 60 * y // size + 40, 60 + 150 * (x + y) // (2 * size))) for x in range(size))
    def chunk(t, d): c = struct.pack(">I", len(d)) + t + d; return c + struct.pack(">I", zlib.crc32(t + d))
    open(path, "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0))
                           + chunk(b"IDAT", zlib.compress(rows)) + chunk(b"IEND", b""))
ART = os.environ.get("HUSH_FAKE_ART", "/tmp/hush-fakempris-art.png")
tinted_art(ART)
T0 = time.time()
POS = [30.0]  # seconds at T0
ROOT, PLAYER = "org.mpris.MediaPlayer2", "org.mpris.MediaPlayer2.Player"

class Fake(dbus.service.Object):
    props = {
        ROOT: {"CanQuit": True, "CanRaise": False, "HasTrackList": False, "Identity": "Hush fake",
               "SupportedUriSchemes": dbus.Array([], signature="s"), "SupportedMimeTypes": dbus.Array([], signature="s")},
        PLAYER: {"PlaybackStatus": "Playing", "CanControl": True, "CanPlay": True, "CanPause": True,
                 "CanGoNext": True, "CanGoPrevious": True, "CanSeek": True, "Position": dbus.Int64(30_000_000),
                 "Rate": 1.0, "MinimumRate": 1.0, "MaximumRate": 1.0, "Volume": 1.0,
                 "Metadata": dbus.Dictionary({"mpris:trackid": dbus.ObjectPath("/hush/fake/1"),
                     "mpris:length": dbus.Int64(120_000_000), "xesam:title": "Fake track", "xesam:artist": ["Fake"], "mpris:artUrl": "file://" + ART}, signature="sv")},
    }
    @dbus.service.method("org.freedesktop.DBus.Properties", in_signature="ss", out_signature="v")
    def Get(self, i, p): self.tick(); return self.props[i][p]
    @dbus.service.method("org.freedesktop.DBus.Properties", in_signature="s", out_signature="a{sv}")
    def GetAll(self, i): self.tick(); return self.props[i]
    def tick(self):
        pl = self.props[PLAYER]
        if pl["PlaybackStatus"] == "Playing": POS[0] += time.time() - self.last
        self.last = time.time()
        pl["Position"] = dbus.Int64(int(POS[0] * 1e6))
    last = time.time()
    @dbus.service.method(PLAYER, in_signature="ox")
    def SetPosition(self, track, pos): self.tick(); POS[0] = pos / 1e6; self.tick()
    @dbus.service.method(PLAYER, in_signature="x")
    def Seek(self, off): self.tick(); POS[0] += off / 1e6
    @dbus.service.method(PLAYER)
    def Next(self): pass
    @dbus.service.method(PLAYER)
    def Previous(self): pass
    @dbus.service.method(ROOT)
    def Quit(self): pass
    @dbus.service.method(PLAYER)
    def PlayPause(self): pass
    @dbus.service.method(PLAYER)
    def Play(self): pass
    @dbus.service.method(PLAYER)
    def Pause(self): pass

Fake(bus, "/org/mpris/MediaPlayer2")
GLib.MainLoop().run()
