import app from "ags/gtk4/app"
import { createState } from "ags"
import { execAsync } from "ags/process"
import { Astal, Gtk, Gdk } from "ags/gtk4"

// shared open/close state (the bar's power button toggles this)
export const [powerVisible, setPowerVisible] = createState(false)
export function togglePowerMenu() {
  setPowerVisible(!powerVisible())
}

type Action = { key: string; label: string; icon: string; cmd: string[] }

// NOTE: verify `lock` and `logout` for your setup (see message).
const ACTIONS: Action[] = [
  { key: "l", label: "Lock", icon: "󰌾", cmd: ["hyprlock"] },
  { key: "e", label: "Logout", icon: "󰗽", cmd: ["hyprctl", "dispatch", "hl.dsp.exit()"] },
  { key: "r", label: "Reboot", icon: "󰜉", cmd: ["systemctl", "reboot"] },
  { key: "p", label: "Shutdown", icon: "󰐥", cmd: ["systemctl", "poweroff"] },
]

export function PowerMenu(gdkmonitor: Gdk.Monitor) {
  const [sel, setSel] = createState(0)

  function run(i: number) {
    setPowerVisible(false)
    execAsync(ACTIONS[i].cmd).catch(console.error)
  }

  function handleKey(keyval: number): boolean {
    switch (keyval) {
      case Gdk.KEY_Escape:
        setPowerVisible(false)
        return true
      case Gdk.KEY_l:
        run(0)
        return true
      case Gdk.KEY_e:
        run(1)
        return true
      case Gdk.KEY_r:
        run(2)
        return true
      case Gdk.KEY_p:
        run(3)
        return true
      case Gdk.KEY_Return:
      case Gdk.KEY_KP_Enter:
        run(sel())
        return true
      case Gdk.KEY_Left: {
        const s = sel()
        if (s % 2 === 1) setSel(s - 1)
        return true
      }
      case Gdk.KEY_Right: {
        const s = sel()
        if (s % 2 === 0) setSel(s + 1)
        return true
      }
      case Gdk.KEY_Up: {
        const s = sel()
        if (s >= 2) setSel(s - 2)
        return true
      }
      case Gdk.KEY_Down: {
        const s = sel()
        if (s < 2) setSel(s + 2)
        return true
      }
      default:
        return false
    }
  }

  function Card(i: number) {
    const a = ACTIONS[i]
    return (
      <button
        class={sel((s) => (s === i ? "power-card selected" : "power-card"))}
        onClicked={() => run(i)}
      >
        <overlay>
          <box orientation={Gtk.Orientation.VERTICAL} spacing={10} halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER}>
            <label class="power-icon" label={a.icon} />
            <label class="power-label" label={a.label} />
          </box>
          <label class="power-key" label={a.key} $type="overlay" halign={Gtk.Align.END} valign={Gtk.Align.START} />
        </overlay>
      </button>
    )
  }

  const { TOP, BOTTOM, LEFT, RIGHT } = Astal.WindowAnchor

  return (
    <window
      name="powermenu"
      class="PowerMenu"
      namespace="ags-powermenu"
      gdkmonitor={gdkmonitor}
      layer={Astal.Layer.OVERLAY}
      anchor={TOP | BOTTOM | LEFT | RIGHT}
      exclusivity={Astal.Exclusivity.IGNORE}
      keymode={Astal.Keymode.EXCLUSIVE}
      visible={powerVisible}
      application={app}
      $={(self: any) => {
        try {
          const kc = new Gtk.EventControllerKey()
          kc.connect("key-pressed", (_c: any, keyval: number) => handleKey(keyval))
          self.add_controller(kc)
        } catch (e) {
          console.error("powermenu keys", e)
        }
      }}
    >
      <box
        class="power-root"
        orientation={Gtk.Orientation.VERTICAL}
        spacing={18}
        halign={Gtk.Align.CENTER}
        valign={Gtk.Align.CENTER}
        hexpand
        vexpand
      >
        <box spacing={16}>
          {Card(0)}
          {Card(1)}
        </box>
        <box spacing={16}>
          {Card(2)}
          {Card(3)}
        </box>
        <label
          class="power-footer"
          label={sel((s) => `Esc to dismiss · ${ACTIONS[s].label}`)}
        />
      </box>
    </window>
  )
}
