#!/usr/bin/env python3
"""Draw a web page as the wallpaper: one full-output layer-shell WebKit view per monitor."""

import sys

import gi

gi.require_version("Gdk", "3.0")
gi.require_version("Gtk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
gi.require_version("WebKit2", "4.1")
from gi.repository import Gdk, Gtk, GtkLayerShell, WebKit2  # noqa: E402

url = sys.argv[1]
display = Gdk.Display.get_default()

for i in range(display.get_n_monitors()):
    win = Gtk.Window()
    GtkLayerShell.init_for_window(win)
    GtkLayerShell.set_namespace(win, "web-wallpaper")
    # `bottom`, not `background`: above Noctalia's wallpaper surface regardless of
    # which mapped first, still below every window.
    GtkLayerShell.set_layer(win, GtkLayerShell.Layer.BOTTOM)
    GtkLayerShell.set_monitor(win, display.get_monitor(i))
    for edge in (
        GtkLayerShell.Edge.TOP,
        GtkLayerShell.Edge.BOTTOM,
        GtkLayerShell.Edge.LEFT,
        GtkLayerShell.Edge.RIGHT,
    ):
        GtkLayerShell.set_anchor(win, edge, True)
    GtkLayerShell.set_exclusive_zone(win, -1)  # full output, under the bar too
    view = WebKit2.WebView()
    view.load_uri(url)
    win.add(view)
    win.show_all()

# Hotplug: quit non-zero and let the unit's Restart= lay out the new monitor set.
display.connect("monitor-added", lambda *_: Gtk.main_quit())
display.connect("monitor-removed", lambda *_: Gtk.main_quit())
Gtk.main()
sys.exit(1)
