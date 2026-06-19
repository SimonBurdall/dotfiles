import { createState, createComputed, createBinding, For } from "ags"
import { Gtk } from "ags/gtk4"
import { execAsync } from "ags/process"
import { notifyError } from "../lib/notify"
import { spinner } from "./anim"
import AstalNetwork from "gi://AstalNetwork"
import Nm from "gi://NM"

function wifiGlyph(s: number): string {
  if (s >= 75) return "󰤨"
  if (s >= 50) return "󰤥"
  if (s >= 25) return "󰤢"
  if (s > 0) return "󰤟"
  return "󰤯"
}

const errText = (e: any) => String(e?.message ?? e ?? "").slice(0, 160)

export function Network() {
  const network = AstalNetwork.get_default()
  const wifi = network.get_wifi()
  const wired = network.get_wired()
  const hasWifi = !!wifi
  const hasWired = !!wired

  const primary = createBinding(network, "primary")
  const strength = hasWifi ? createBinding(wifi!, "strength") : () => 0
  const enabled = hasWifi ? createBinding(wifi!, "enabled") : () => false
  const scanning = hasWifi ? createBinding(wifi!, "scanning") : () => false
  const accessPoints = hasWifi ? createBinding(wifi!, "accessPoints") : () => []
  const activeAp = hasWifi ? createBinding(wifi!, "activeAccessPoint") : () => null
  // bind to device state, not the derived `internet`/`activeAccessPoint`, which can
  // go stale and never refresh. `state` is a core NM property that reliably notifies.
  const wiredState = hasWired ? createBinding(wired!, "state") : () => 0
  const wifiState = hasWifi ? createBinding(wifi!, "state") : () => 0

  const [selected, setSelected] = createState("") // ssid whose block is open
  const [pw, setPw] = createState("")
  const [working, setWorking] = createState("") // ssid currently connecting
  const [showHidden, setShowHidden] = createState(false)
  const [hiddenSsid, setHiddenSsid] = createState("")
  const [hiddenPw, setHiddenPw] = createState("")

  const wiredUp = createComputed(() => wiredState() === Nm.DeviceState.ACTIVATED)
  const wifiUp = createComputed(() => wifiState() === Nm.DeviceState.ACTIVATED)

  const islandGlyph = createComputed(() => {
    const p = primary()
    if (p === AstalNetwork.Primary.WIRED) return "󰈀"
    if (p === AstalNetwork.Primary.WIFI && hasWifi) return wifiGlyph(strength())
    return "󰤮"
  })

  // only report an active SSID when the wifi device is actually associated;
  // otherwise activeAccessPoint can linger on the last network after disconnect.
  const activeSsid = createComputed(() => {
    if (wifiState() !== Nm.DeviceState.ACTIVATED) return ""
    return (activeAp() as any)?.ssid ?? ""
  })

  // strongest AP per SSID, sorted by signal
  const aps = createComputed(() => {
    const list = accessPoints() as any[]
    const seen = new Map<string, any>()
    for (const ap of list) {
      const ssid = ap.ssid
      if (!ssid) continue
      const ex = seen.get(ssid)
      if (!ex || ap.strength > ex.strength) seen.set(ssid, ap)
    }
    return [...seen.values()].sort((a, b) => b.strength - a.strength).slice(0, 12)
  })

  function toggleSelect(ssid: string) {
    if (selected() === ssid) setSelected("")
    else {
      setSelected(ssid)
      setPw("")
    }
  }

  function doConnect(ssid: string, password: string, hidden = false) {
    if (!ssid) return
    setWorking(ssid)
    const args = ["nmcli", "device", "wifi", "connect", ssid]
    if (password) args.push("password", password)
    if (hidden) args.push("hidden", "yes")
    execAsync(args)
      .then(() => {
        setWorking("")
        setSelected("")
        setPw("")
        setShowHidden(false)
        setHiddenSsid("")
        setHiddenPw("")
      })
      .catch((e: any) => {
        setWorking("")
        const raw = errText(e)
        const msg = /secret|psk|password|wireless-security/i.test(raw)
          ? "Password required or incorrect"
          : raw
        notifyError("Wi-Fi", `${ssid}: ${msg}`)
      })
  }

  function disconnect(ssid: string) {
    execAsync(["nmcli", "connection", "down", "id", ssid]).catch((e: any) =>
      notifyError("Wi-Fi", `Disconnect ${ssid}: ${errText(e)}`),
    )
  }

  function forget(ssid: string) {
    execAsync(["nmcli", "connection", "delete", "id", ssid])
      .then(() => setSelected(""))
      .catch((e: any) => notifyError("Wi-Fi", `Forget ${ssid}: ${errText(e)}`))
  }

  function ApRow(ap: any) {
    const ssid = ap.ssid as string
    const isSel = selected((s) => s === ssid)
    const isActive = activeSsid((s) => s === ssid)
    const connectIcon = createComputed(() => (working() === ssid && ssid ? spinner() : "󰁝"))

    return (
      <box
        class={selected((s) => (s === ssid ? "net-ap selected" : "net-ap"))}
        orientation={Gtk.Orientation.VERTICAL}
        spacing={4}
      >
        <button
          class={activeSsid((s) => (s === ssid ? "net-row active" : "net-row"))}
          onClicked={() => toggleSelect(ssid)}
        >
          <box spacing={10}>
            <label class="net-strength" label={wifiGlyph(ap.strength)} />
            <label class="net-ssid" label={ssid} xalign={0} hexpand ellipsize={3} maxWidthChars={18} />
            <label class="net-active" label={isActive((a) => (a ? "󰄬" : ""))} />
          </box>
        </button>

        <box visible={isSel} orientation={Gtk.Orientation.VERTICAL} spacing={6}>
          <box class="net-pw" spacing={6}>
            <entry
              class="net-pw-entry"
              hexpand
              visibility={false}
              placeholderText="Password (blank if saved)"
              text={pw}
              onNotifyText={(self) => setPw(self.get_text())}
              onActivate={() => doConnect(ssid, pw())}
            />
            <button class="dd-btn icon" tooltipText="Connect" onClicked={() => doConnect(ssid, pw())}>
              <label label={connectIcon} />
            </button>
          </box>
          {/* homogeneous + hexpand -> visible buttons split the row evenly.
              Disconnect only shows on the active network, so Forget/Cancel are 50/50. */}
          <box class="net-ap-actions" homogeneous spacing={6}>
            <button class="net-mini" hexpand visible={isActive} onClicked={() => disconnect(ssid)}>
              <label label="Disconnect" />
            </button>
            <button class="net-mini" hexpand onClicked={() => forget(ssid)}>
              <label label="Forget" />
            </button>
            <button class="net-mini" hexpand onClicked={() => setSelected("")}>
              <label label="Cancel" />
            </button>
          </box>
        </box>
      </box>
    )
  }

  const hiddenIcon = createComputed(() =>
    working() !== "" && working() === hiddenSsid() ? spinner() : "󰁝",
  )

  return (
    <menubutton class="island net-island">
      <label label={islandGlyph} />
      <popover>
        <box class="popover net-popover" orientation={Gtk.Orientation.VERTICAL} spacing={8} widthRequest={300}>
          <box class="popover-header">
            <label class="popover-title" label="Network" hexpand xalign={0} />
          </box>

          {hasWired ? (
            <box orientation={Gtk.Orientation.VERTICAL} spacing={4}>
              <label class="section-label" label="Wired" xalign={0} hexpand />
              <box class="net-row" spacing={10}>
                <label class="net-strength" label="󰈀" />
                <label class="net-ssid" label="Ethernet" xalign={0} hexpand />
                <label
                  class="net-wired-state"
                  label={wiredUp((up) => (up ? "Connected" : "Disconnected"))}
                />
              </box>
            </box>
          ) : (
            <box visible={false} />
          )}

          <box class="dd-divider" visible={hasWired && hasWifi} />

          {hasWifi ? (
            <box orientation={Gtk.Orientation.VERTICAL} spacing={6}>
              <box spacing={6}>
                <label class="section-label" label="Wi-Fi" xalign={0} hexpand valign={Gtk.Align.CENTER} />
                <button
                  class={scanning((s) => (s ? "dd-btn icon scanning" : "dd-btn icon"))}
                  valign={Gtk.Align.CENTER}
                  tooltipText="Rescan"
                  onClicked={() => wifi!.scan()}
                >
                  <label halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER} label="󰑐" />
                </button>
                <button
                  class={enabled((e) => (e ? "dd-btn icon active" : "dd-btn icon"))}
                  valign={Gtk.Align.CENTER}
                  tooltipText="Toggle Wi-Fi"
                  onClicked={() => wifi!.set_enabled(!enabled())}
                >
                  <label halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER} label={enabled((e) => (e ? "󰖩" : "󰖪"))} />
                </button>
              </box>

              <box class="net-list" orientation={Gtk.Orientation.VERTICAL} spacing={3} visible={enabled}>
                <For each={aps}>{(ap: any) => ApRow(ap)}</For>
              </box>
              <label class="td-empty" label="Wi-Fi is off" visible={enabled((e) => !e)} />
              <label
                class="td-empty"
                label="No networks in range"
                visible={createComputed(() => enabled() && aps().length === 0)}
              />

              <button class="dd-action" visible={enabled} onClicked={() => setShowHidden(!showHidden())}>
                <box spacing={8} halign={Gtk.Align.CENTER}>
                  <label label="󰛵" />
                  <label label={showHidden((h) => (h ? "Cancel hidden network" : "Join hidden network"))} />
                </box>
              </button>

              <box class="net-ap selected" orientation={Gtk.Orientation.VERTICAL} spacing={6} visible={showHidden}>
                <entry
                  class="net-pw-entry"
                  hexpand
                  placeholderText="Network name (SSID)"
                  text={hiddenSsid}
                  onNotifyText={(self) => setHiddenSsid(self.get_text())}
                />
                <box spacing={6}>
                  <entry
                    class="net-pw-entry"
                    hexpand
                    visibility={false}
                    placeholderText="Password"
                    text={hiddenPw}
                    onNotifyText={(self) => setHiddenPw(self.get_text())}
                    onActivate={() => doConnect(hiddenSsid(), hiddenPw(), true)}
                  />
                  <button class="dd-btn icon" tooltipText="Join" onClicked={() => doConnect(hiddenSsid(), hiddenPw(), true)}>
                    <label label={hiddenIcon} />
                  </button>
                </box>
              </box>
            </box>
          ) : (
            <box visible={false} />
          )}
        </box>
      </popover>
    </menubutton>
  )
}
