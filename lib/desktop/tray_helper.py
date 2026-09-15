#!/usr/bin/env python3
"""Tray icon helper for YouFree desktop app.
Communicates with Flutter via TCP on localhost.
Flutter runs the TCP server; this script connects as a client.
"""

import os
import json
import socket
import struct
import signal

import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, GLib


HOST = '127.0.0.1'
PORT = 21987
ICON_PATH = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    '..', '..', 'assets', 'youfree.png'
)


def send(action):
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(2)
        s.connect((HOST, PORT))
        payload = json.dumps({'action': action}).encode()
        s.sendall(struct.pack('>I', len(payload)) + payload)
        s.close()
    except Exception:
        pass


def on_click(*_):
    send('toggle')


def on_quit(*_):
    send('quit')
    GLib.timeout_add(500, Gtk.main_quit)


def on_popup_menu(icon, button, time):
    menu = Gtk.Menu()

    item_toggle = Gtk.MenuItem(label='Mostrar/Ocultar')
    item_toggle.connect('activate', on_click)
    menu.append(item_toggle)

    item_sep = Gtk.SeparatorMenuItem()
    menu.append(item_sep)

    item_quit = Gtk.MenuItem(label='Sair')
    item_quit.connect('activate', on_quit)
    menu.append(item_quit)

    menu.show_all()
    menu.popup(None, None, None, icon, button, time)


def main():
    icon = Gtk.StatusIcon()
    if os.path.exists(ICON_PATH):
        icon.set_from_file(ICON_PATH)
    else:
        icon.set_from_stock(Gtk.STOCK_MEDIA_PLAY)
    icon.set_tooltip_text('YouFree')
    icon.connect('activate', on_click)
    icon.connect('popup-menu', on_popup_menu)

    signal.signal(signal.SIGINT, signal.SIG_DFL)
    Gtk.main()


if __name__ == '__main__':
    main()
