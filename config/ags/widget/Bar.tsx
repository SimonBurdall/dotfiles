import app from "ags/gtk4/app"
import { Astal, Gtk, Gdk } from "ags/gtk4"
import { execAsync } from "ags/process"
import Workspaces from "./Workspaces"
import { Todoist } from "./Todoist"
import { NotifCenter } from "./Notifications"
import { SysMon } from "./SysMon"
import {
  Volume,
  Bluetooth,
  Battery,
} from "./Modules"
import { Media } from "./Media"
import { Network } from "./Network"
import { Calendar } from "./Calendar"
import { togglePowerMenu } from "./PowerMenu"

// GTK4 buttons keep the default arrow on hover and there's no CSS cursor property,
// so set the "pointer" hand on every button by walking the tree.
function applyHand(w: Gtk.Widget | null) {
  if (!w) return
  if (w instanceof Gtk.Button || w instanceof Gtk.MenuButton) {
    try {
      w.set_cursor_from_name("pointer")
    } catch (_) {}
  }
  let child = w.get_first_child()
  while (child) {
    applyHand(child)
    child = child.get_next_sibling()
  }
}

// popover contents (task rows, AP rows, device rows, app streams) are built from
// async data and rebuilt on every poll, so re-apply each time a popover opens.
function handCursors(root: Gtk.Widget | null) {
  if (!root) return
  applyHand(root)
  if (root instanceof Gtk.MenuButton) {
    const pop = root.get_popover()
    if (pop) {
      applyHand(pop)
      try {
        pop.connect("map", () => applyHand(pop))
      } catch (_) {}
    }
  }
  let child = root.get_first_child()
  while (child) {
    handCursors(child)
    child = child.get_next_sibling()
  }
}

export default function Bar(gdkmonitor: Gdk.Monitor) {
  const { TOP, LEFT, RIGHT } = Astal.WindowAnchor

  return (
    <window
      visible
      name="bar"
      class="Bar"
      gdkmonitor={gdkmonitor}
      exclusivity={Astal.Exclusivity.EXCLUSIVE}
      anchor={TOP | LEFT | RIGHT}
      application={app}
    >
      <centerbox class="bar-inner" halign={Gtk.Align.CENTER} $={(self) => handCursors(self)}>
        {/* ---------- LEFT ---------- */}
        <box $type="start" spacing={0}>
          <button
            class="island-button"
            valign={Gtk.Align.CENTER}
            onClicked={() =>
              execAsync(["/home/si/.config/rofi/launch.sh"])
            }
          >
            <label label="󰍉" />
          </button>
          <Workspaces />
          <Todoist />
          <NotifCenter />
          <SysMon />
        </box>

        {/* ---------- CENTER ---------- */}
        <box $type="center" spacing={0}>
          <Media />
        </box>

        {/* ---------- RIGHT ---------- */}
        <box $type="end" spacing={0}>
          <Volume />
          <Bluetooth />
          <Network />
          <Battery />
          <Calendar />
          <button
            class="island-button"
            valign={Gtk.Align.CENTER}
            onClicked={() => togglePowerMenu()}
          >
            <label label="󰐥" />
          </button>
        </box>
      </centerbox>
    </window>
  )
}
