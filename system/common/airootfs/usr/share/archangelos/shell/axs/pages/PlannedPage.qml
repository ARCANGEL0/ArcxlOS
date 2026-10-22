// Placeholder for a section that is still being rebuilt: says what it will hold, never fakes controls.
import QtQuick
import qs.axs
import qs.axs.ui

PageScaffold {
    id: page
    property var meta
    group: meta ? meta.group : ""
    title: meta ? meta.label : ""
    desc: meta ? meta.desc : ""

    Section {
        EmptyState {
            icon: page.meta ? page.meta.icon : "construction"
            title: "This section is being rebuilt"
            desc: "It arrives in a later build of ArchangelOS Settings. Nothing here changes your system yet."
        }
    }
}
