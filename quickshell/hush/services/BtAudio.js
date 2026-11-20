.pragma library
// The Bluetooth address in a PipeWire bluez sink or source name ("bluez_output.F9_EB_29_D1_0D_19.1",
// "bluez_input.F9:EB:29:D1:0D:19") as "F9:EB:29:D1:0D:19", or "" for any other node.
function addr(name) {
    const m = /^bluez_(?:output|input)\.([0-9A-Fa-f]{2}(?:[_:][0-9A-Fa-f]{2}){5})(?:\.|$)/.exec(name || "")
    return m ? m[1].replace(/_/g, ":").toUpperCase() : ""
}
