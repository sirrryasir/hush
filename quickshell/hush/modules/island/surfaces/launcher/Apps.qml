import QtQuick
import Quickshell

// Desktop applications. DesktopEntries.applications already drops Hidden/NoDisplay entries;
// the noDisplay check stays as a guard.
QtObject {
    function items() {
        const out = []
        for (const e of DesktopEntries.applications.values) {
            if (e.noDisplay) continue
            out.push({
                kind: "app", remember: true,
                icon: e.icon, name: e.name,
                // Description line under the name: the entry's Comment, else its GenericName.
                desc: e.comment || e.genericName || "",
                hint: "",
                keywords: [e.genericName, e.id].concat(e.keywords || []).join(" "),
                run: () => e.execute()
            })
        }
        return out
    }
}
