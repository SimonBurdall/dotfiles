import AstalHyprland from "gi://AstalHyprland"
import { createBinding, createComputed } from "ags"
import { execAsync } from "ags/process"

const hypr = AstalHyprland.get_default()

// One fixed button per workspace 1-5 (persistent, like your Waybar).
// State is derived live: active (focused) / occupied (has windows) / empty.
function Ws({ id }: { id: number }) {
  const focused = createBinding(hypr, "focusedWorkspace")
  const workspaces = createBinding(hypr, "workspaces")

  const state = createComputed(() => {
    if (focused()?.get_id() === id) return "active"
    if (workspaces().some((w) => w.get_id() === id)) return "occupied"
    return "empty"
  })

  // Lua config provider: use the real dispatcher, same form as the keybinds
  // in hyprland.lua -> hl.dsp.focus({ workspace = N }).
  const go = () =>
    execAsync(["hyprctl", "dispatch", `hl.dsp.focus({ workspace = ${id} })`])

  return (
    <button class={state} onClicked={go}>
      <label label={`${id}`} />
    </button>
  )
}

export default function Workspaces() {
  return (
    <box class="island workspaces" spacing={0}>
      {[1, 2, 3, 4, 5].map((id) => (
        <Ws id={id} />
      ))}
    </box>
  )
}
