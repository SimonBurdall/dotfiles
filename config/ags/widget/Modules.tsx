import { createBinding, createComputed, createState, For } from "ags"
import { execAsync } from "ags/process"
import { timeout, createPoll } from "ags/time"
import { Gtk } from "ags/gtk4"
import { dots, spinner } from "./anim"
import { notifyError } from "../lib/notify"
import AstalWp from "gi://AstalWp"
import AstalNetwork from "gi://AstalNetwork"
import AstalBluetooth from "gi://AstalBluetooth"
import AstalBattery from "gi://AstalBattery"
import AstalNotifd from "gi://AstalNotifd"
import AstalMpris from "gi://AstalMpris"

// shared low-frequency tick so bluetooth rows reflect external (bluetoothctl)
// changes that Astal's notify signals may miss. Only ticks while subscribed.
const btTick = createPoll(0, 1500, (p: number) => (p + 1) % 1000000)

// ---------- one per-application volume row ----------
function AppStream({ stream }: { stream: AstalWp.Stream }) {
  const vol = createBinding(stream, "volume")
  const pct = createComputed(() => `${Math.round(vol() * 100)}%`)
  const name = stream.get_description() || stream.get_name() || "Application"
  const icon = stream.get_icon() || "audio-x-generic"

  return (
    <box class="vol-row" spacing={10}>
      <image class="vol-row-icon" iconName={icon} pixelSize={20} />
      <label class="vol-row-name" label={name} xalign={0} widthChars={8} maxWidthChars={8} ellipsize={3} />
      <slider class="vol-slider" hexpand min={0} max={1} step={0.01} value={vol}
        onChangeValue={(self) => stream.set_volume(self.value)} />
      <label class="vol-row-pct" label={pct} />
    </box>
  )
}

// ---------- VOLUME (astalwp) ----------
export function Volume() {
  const wp = AstalWp.get_default()
  const speaker = wp.get_default_speaker()
  const volume = createBinding(speaker, "volume")
  const mute = createBinding(speaker, "mute")

  const barLabel = createComputed(() => {
    const v = Math.round(volume() * 100)
    if (mute()) return "󰝟"
    const icon = v < 33 ? "󰕿" : v < 66 ? "󰖀" : "󰕾"
    return icon
  })

  const pct = createComputed(() => `${Math.round(volume() * 100)}%`)

  const audio = wp.get_audio()
  const streamsAcc = createBinding(audio, "streams")
  const streams = streamsAcc((s) => s ?? [])
  const hasStreams = streamsAcc((s) => (s?.length ?? 0) > 0)

  return (
    <menubutton class="island vol-island">
      <label label={barLabel} />
      <popover>
        <box class="popover vol-popover" orientation={Gtk.Orientation.VERTICAL} spacing={10}>
          <box class="popover-header">
            <label class="popover-title" label="Volume" hexpand xalign={0} />
            <button
              class={mute((m) => (m ? "dd-btn icon active" : "dd-btn icon"))}
              valign={Gtk.Align.CENTER}
              tooltipText="Toggle mute"
              onClicked={() => speaker.set_mute(!speaker.get_mute())}
            >
              <label halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER} label={mute((m) => (m ? "󰝟" : "󰕾"))} />
            </button>
          </box>

          <box class="vol-row" spacing={10}>
            <label class="vol-row-icon" label={mute((m) => (m ? "󰝟" : "󰕾"))} />
            <label class="vol-row-name" label="System" xalign={0} widthChars={8} maxWidthChars={8} ellipsize={3} />
            <slider class="vol-slider" hexpand min={0} max={1} step={0.01} value={volume}
              onChangeValue={(self) => speaker.set_volume(self.value)} />
            <label class="vol-row-pct" label={pct} />
          </box>

          <box class="dd-divider" visible={hasStreams} />
          <box class="app-section" visible={hasStreams} orientation={Gtk.Orientation.VERTICAL} spacing={4}>
            <label class="section-label" label="OUTPUT · APPLICATIONS" xalign={0} />
            <For each={streams}>
              {(stream: AstalWp.Stream) => <AppStream stream={stream} />}
            </For>
          </box>

          <button class="dd-action" onClicked={() => execAsync(["pavucontrol"]).catch(console.error)}>
            <box spacing={8} halign={Gtk.Align.CENTER}>
              <label label="󰕾" />
              <label label="Open mixer" />
            </box>
          </button>
        </box>
      </popover>
    </menubutton>
  )
}

// ---------- NETWORK (astalnetwork) ----------
export function Network() {
  const net = AstalNetwork.get_default()
  const primary = createBinding(net, "primary")

  const label = createComputed(() => {
    const p = primary()
    if (p === AstalNetwork.Primary.WIRED) return "󰈀"
    if (p === AstalNetwork.Primary.WIFI) return "󰖩"
    return "󰖪"
  })

  return (
    <button class="island" onClicked={() => execAsync(["nm-connection-editor"])}>
      <label label={label} />
    </button>
  )
}

// ---------- one bluetooth device row (prototype style) ----------
function BtDevice({
  device,
  adapter,
  paired,
}: {
  device: AstalBluetooth.Device
  adapter: AstalBluetooth.Adapter | null
  paired: boolean
}) {
  const connecting = createBinding(device, "connecting")
  const battery = createBinding(device, "batteryPercentage")
  const name = device.get_alias() || device.get_name() || "Device"
  const icon = device.get_icon() || "bluetooth"
  const [forgetting, setForgetting] = createState(false)
  const [working, setWorking] = createState(false)

  const addr = () =>
    typeof (device as any).get_address === "function"
      ? device.get_address()
      : (device as any).address

  const primary = () => {
    const a = addr()

    if (paired) {
      if (device.get_connected()) {
        try {
          device.disconnect_device(() => {})
        } catch (e) {}
        return
      }
      // connect: bluetoothctl is more reliable for audio devices
      setWorking(true)
      if (a)
        execAsync(["bluetoothctl", "connect", a])
          .catch(() => notifyError("Bluetooth", `Connection failed: ${name}`))
          .finally(() => setWorking(false))
      else {
        try {
          device.connect_device(() => {})
        } catch (e) {}
        setWorking(false)
      }
      return
    }

    // unpaired: pair -> trust -> connect via bluetoothctl (it registers an agent for "just works")
    if (!a) {
      try {
        device.pair()
      } catch (e) {
        notifyError("Bluetooth", `Pairing failed: ${name}`)
      }
      return
    }
    setWorking(true)
    // ConnectionAttemptFailed is usually an active scan fighting the pairing link,
    // so stop discovery first, then retry pair a few times before giving up.
    const cmd =
      `bluetoothctl scan off >/dev/null 2>&1; sleep 0.4; ` +
      `for i in 1 2 3; do o=$(bluetoothctl pair ${a} 2>&1) && ok=1 && break; sleep 1.2; done; ` +
      `if [ "$ok" = 1 ]; then ` +
      `  bluetoothctl trust ${a} >/dev/null 2>&1; bluetoothctl connect ${a} 2>&1; ` +
      `else echo "$o" >&2; exit 1; fi`
    execAsync(["bash", "-c", cmd])
      .catch((e) =>
        notifyError("Bluetooth", `Pairing failed: ${name}\n${String((e as any)?.message ?? e ?? "").slice(0, 200)}`),
      )
      .finally(() => setWorking(false))
  }
  const forget = () => {
    if (!adapter) {
      notifyError("Bluetooth", `No adapter to forget ${name}`)
      return
    }
    setForgetting(true)
    const a = addr()
    const astalRemove = () => {
      try {
        adapter.remove_device(device)
      } catch (e) {
        setForgetting(false)
        notifyError("Bluetooth", `Couldn't forget ${name}`)
      }
    }
    // bluetoothctl is more reliable than the Astal call for stubborn devices;
    // on success bluez emits device-removed and the row drops out on its own.
    if (a) execAsync(["bluetoothctl", "remove", a]).catch(astalRemove)
    else astalRemove()
  }

  // animated spinner glyph while forgetting, otherwise the ✕
  const forgetIcon = createComputed(() => (forgetting() ? spinner() : "󰅖"))

  const rowClass = createComputed(() => {
    btTick()
    return device.get_connected() ? "bt-row connected" : "bt-row"
  })

  // subtitle: status while busy, otherwise the MAC (+ pair hint for unpaired)
  const subtitle = createComputed(() => {
    btTick()
    if (working()) return spinner()
    if (connecting()) return dots()
    if (device.get_connected()) return "Connected"
    const a = addr()
    if (!paired) return a ? `${a}  ·  tap to pair` : "Tap to pair"
    return a || ""
  })
  const subVisible = createComputed(() => subtitle().length > 0)

  // battery: -1 means none. Normalise whether it arrives as 0-1 or 0-100.
  const batteryText = createComputed(() => {
    const raw = battery()
    if (raw < 0) return ""
    const p = raw <= 1 ? Math.round(raw * 100) : Math.round(raw)
    return `${p}%`
  })
  const batteryVisible = createComputed(() => battery() >= 0)

  return (
    <box class={rowClass} spacing={2}>
      <button class="bt-row-main" hexpand onClicked={primary}>
        <box spacing={12}>
          <image class="bt-icon" iconName={icon} pixelSize={24} valign={Gtk.Align.CENTER} />
          <box orientation={Gtk.Orientation.VERTICAL} hexpand valign={Gtk.Align.CENTER}>
            <label class="bt-name" label={name} xalign={0} />
            <label class="bt-sub" label={subtitle} xalign={0} visible={subVisible} />
          </box>
          <box class="bt-battery" spacing={4} visible={batteryVisible} valign={Gtk.Align.CENTER}>
            <label class="bt-batt-glyph" label="󰁹" />
            <label class="bt-batt-pct" label={batteryText} />
          </box>
        </box>
      </button>
      {paired ? (
        <button class="bt-forget" tooltipText="Forget device" valign={Gtk.Align.CENTER} onClicked={forget}>
          <label label={forgetIcon} />
        </button>
      ) : (
        <box visible={false} />
      )}
    </box>
  )
}

// ---------- BLUETOOTH (astalbluetooth) ----------
export function Bluetooth() {
  const bt = AstalBluetooth.get_default()
  const powered = createBinding(bt, "isPowered")
  const connected = createBinding(bt, "isConnected")
  const adapter = bt.get_adapter()
  const discovering = adapter ? createBinding(adapter, "discovering") : createComputed(() => false)

  const barLabel = createComputed(() => {
    if (!powered()) return "󰂲"
    if (connected()) return "󰂱"
    return "󰂯"
  })

  const devicesAcc = createBinding(bt, "devices")
  const pairedDevices = createComputed(() => {
    btTick()
    return devicesAcc().filter((dev) => dev.get_paired() || dev.get_connected())
  })
  const availableDevices = createComputed(() => {
    btTick()
    return devicesAcc().filter(
      (dev) => !dev.get_paired() && !dev.get_connected() && !!(dev.get_name() || dev.get_alias()),
    )
  })

  function toggleScan() {
    const ad = bt.get_adapter()
    if (!ad) {
      notifyError("Bluetooth", "No Bluetooth adapter found")
      return
    }
    if (!powered()) {
      notifyError("Bluetooth", "Turn Bluetooth on before scanning")
      return
    }
    if (ad.get_discovering()) {
      ad.stop_discovery()
    } else {
      ad.start_discovery()
      // auto-stop after 30s to save power
      timeout(30000, () => {
        try {
          ad.stop_discovery()
        } catch (e) {}
      })
    }
  }

  return (
    <menubutton class="island">
      <label label={barLabel} />
      <popover>
        <box class="popover bt-popover" orientation={Gtk.Orientation.VERTICAL} spacing={8}>
          <box class="popover-header" spacing={6}>
            <label class="popover-title" label="Bluetooth" hexpand xalign={0} />
            <button
              class={discovering((d) => (d ? "dd-btn icon scanning" : "dd-btn icon"))}
              tooltipText="Scan for devices"
              onClicked={toggleScan}
            >
              <label label="󰑐" />
            </button>
            <button class={powered((p) => (p ? "dd-btn icon active" : "dd-btn icon"))} tooltipText="Toggle Bluetooth" onClicked={() => bt.toggle()}>
              <label label={powered((p) => (p ? "󰂯" : "󰂲"))} />
            </button>
          </box>

          <label class="section-label" label="Paired" xalign={0} hexpand visible={pairedDevices((d) => d.length > 0)} />
          <box orientation={Gtk.Orientation.VERTICAL} spacing={2}>
            <For each={pairedDevices}>
              {(device: AstalBluetooth.Device) => <BtDevice device={device} adapter={adapter} paired />}
            </For>
          </box>
          <label
            class="td-empty"
            label="No paired devices"
            visible={pairedDevices((d) => d.length === 0)}
          />

          <box
            class="dd-divider"
            visible={createComputed(() => pairedDevices().length > 0 && availableDevices().length > 0)}
          />
          <label class="section-label" label="Available" xalign={0} hexpand visible={availableDevices((d) => d.length > 0)} />
          <box orientation={Gtk.Orientation.VERTICAL} spacing={2}>
            <For each={availableDevices}>
              {(device: AstalBluetooth.Device) => (
                <BtDevice device={device} adapter={adapter} paired={false} />
              )}
            </For>
          </box>
          <label
            class="td-empty"
            label="Scanning…"
            visible={createComputed(() => discovering() && availableDevices().length === 0)}
          />

          <button class="dd-action" onClicked={() => execAsync(["blueman-manager"]).catch(console.error)}>
            <box spacing={8} halign={Gtk.Align.CENTER}>
              <label label="󰂯" />
              <label label="Open Bluetooth settings" />
            </box>
          </button>
        </box>
      </popover>
    </menubutton>
  )
}

// ---------- BATTERY (astalbattery) — self-hides on desktop ----------
export function Battery() {
  const bat = AstalBattery.get_default()
  if (!bat) return <box visible={false} />

  const present = createBinding(bat, "isPresent")
  const percentage = createBinding(bat, "percentage")
  const charging = createBinding(bat, "charging")

  const label = createComputed(() => {
    const p = Math.round(percentage() * 100)
    const icons = ["󰁺", "󰁼", "󰁾", "󰂀", "󰂂"]
    const icon = icons[Math.min(4, Math.floor(p / 20))]
    return `${charging() ? "󰂄" : icon} ${p}%`
  })

  return (
    <box class="island" visible={present}>
      <label label={label} />
    </box>
  )
}

// ---------- NOTIFICATIONS (astalnotifd) ----------
export function Notifications() {
  const notifd = AstalNotifd.get_default()
  const notifs = createBinding(notifd, "notifications")
  const dnd = createBinding(notifd, "dontDisturb")

  const label = createComputed(() => {
    if (dnd()) return "󰂛"
    const count = notifs().length
    return count > 0 ? `󱅫 ${count}` : "󰂚"
  })

  return (
    <button class="island" onClicked={() => execAsync(["swaync-client", "-t", "-sw"])}>
      <label label={label} />
    </button>
  )
}

// ---------- MEDIA (astalmpris) — centre module ----------
export function Media() {
  const mpris = AstalMpris.get_default()
  const players = createBinding(mpris, "players")

  const label = createComputed(() => {
    const ps = players()
    if (ps.length === 0) return "󰝚 Nothing playing"
    const p = ps[0]
    const title = p.title || ""
    const artist = p.artist || ""
    return artist ? `󰝚 ${artist} — ${title}` : `󰝚 ${title}`
  })

  return (
    <box class="island">
      <label label={label} maxWidthChars={48} ellipsize={3} />
    </box>
  )
}
