pragma Singleton
import QtQml

// Island arbitration priorities. Higher wins; the Arbiter queues lower transients.
QtObject {
    readonly property int modal: 90         // launcher, wallpapers, settings
    readonly property int expanded: 80      // control center, media, notifications, calendar
    readonly property int critical: 70      // critical notification, sticky
    readonly property int notification: 60
    readonly property int osd: 50
    readonly property int hover: 40         // above activity: the glance face covers the media capsule, which waits
    readonly property int activity: 30
    readonly property int rest: 0
}
