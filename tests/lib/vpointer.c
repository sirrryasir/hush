// Pointer buttons and the wheel through zwlr_virtual_pointer_v1, for the test sandbox (tests/sandbox.sh).
// The pointer itself is placed with hl.dsp.cursor.move; this client only presses and scrolls, on the
// compositor named by WAYLAND_DISPLAY. Built by tests/lib/input.sh on first use.
//   vpointer click <left|right|middle>     press and release
//   vpointer wheel <steps>                 vertical wheel, positive = down
//   vpointer hold seat                     keep a pointer plugged in (a seat without one sends no
//                                          pointer events, so hover would never reach a client)
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <wayland-client.h>
#include "wlr-virtual-pointer-unstable-v1-client-protocol.h"

static struct wl_seat *seat;
static struct zwlr_virtual_pointer_manager_v1 *manager;

static void global(void *data, struct wl_registry *reg, uint32_t name, const char *iface, uint32_t version) {
    (void)data;
    if (!strcmp(iface, wl_seat_interface.name) && !seat)
        seat = wl_registry_bind(reg, name, &wl_seat_interface, 1);
    else if (!strcmp(iface, zwlr_virtual_pointer_manager_v1_interface.name))
        manager = wl_registry_bind(reg, name, &zwlr_virtual_pointer_manager_v1_interface, version < 2 ? version : 2);
}
static void global_remove(void *data, struct wl_registry *reg, uint32_t name) { (void)data; (void)reg; (void)name; }
static const struct wl_registry_listener listener = { global, global_remove };

static uint32_t now_ms(void) {
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return (uint32_t)(t.tv_sec * 1000 + t.tv_nsec / 1000000);
}

int main(int argc, char **argv) {
    if (argc != 3) { fprintf(stderr, "usage: vpointer click left|right|middle | wheel <steps>\n"); return 2; }
    struct wl_display *dpy = wl_display_connect(NULL);
    if (!dpy) { fprintf(stderr, "vpointer: cannot connect to WAYLAND_DISPLAY\n"); return 1; }
    struct wl_registry *reg = wl_display_get_registry(dpy);
    wl_registry_add_listener(reg, &listener, NULL);
    wl_display_roundtrip(dpy);
    if (!manager) { fprintf(stderr, "vpointer: compositor lacks zwlr_virtual_pointer_manager_v1\n"); return 1; }
    struct zwlr_virtual_pointer_v1 *p = zwlr_virtual_pointer_manager_v1_create_virtual_pointer(manager, seat);
    wl_display_roundtrip(dpy);
    if (!strcmp(argv[1], "click")) {
        uint32_t b = !strcmp(argv[2], "right") ? 0x111 : !strcmp(argv[2], "middle") ? 0x112 : 0x110; // BTN_*
        zwlr_virtual_pointer_v1_button(p, now_ms(), b, WL_POINTER_BUTTON_STATE_PRESSED);
        zwlr_virtual_pointer_v1_frame(p);
        wl_display_roundtrip(dpy);
        usleep(30000);
        zwlr_virtual_pointer_v1_button(p, now_ms(), b, WL_POINTER_BUTTON_STATE_RELEASED);
        zwlr_virtual_pointer_v1_frame(p);
    } else if (!strcmp(argv[1], "wheel")) {
        int steps = atoi(argv[2]);
        zwlr_virtual_pointer_v1_axis_source(p, WL_POINTER_AXIS_SOURCE_WHEEL);
        zwlr_virtual_pointer_v1_axis_discrete(p, now_ms(), WL_POINTER_AXIS_VERTICAL_SCROLL, wl_fixed_from_int(15 * steps), steps);
        zwlr_virtual_pointer_v1_frame(p);
    } else if (!strcmp(argv[1], "hold")) {
        while (wl_display_dispatch(dpy) != -1) {}
        return 0;
    } else { fprintf(stderr, "vpointer: unknown action %s\n", argv[1]); return 2; }
    wl_display_roundtrip(dpy);
    zwlr_virtual_pointer_v1_destroy(p);
    wl_display_roundtrip(dpy);
    wl_display_disconnect(dpy);
    return 0;
}
