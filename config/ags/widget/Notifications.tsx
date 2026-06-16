import app from "ags/gtk4/app"
import { createState, createComputed, createBinding, For } from "ags"
import { timeout } from "ags/time"
import { execAsync } from "ags/process"
import { Astal, Gtk, Gdk } from "ags/gtk4"
import AstalNotifd from "gi://AstalNotifd"

// freedesktop urgency: 0 low, 1 normal, 2 critical (use numbers to avoid enum-name risk)
const URGENCY_CRITICAL = 2

function relativeTime(t: number): string {
  if (!t) return ""
  const sec = t > 1e12 ? Math.floor(t / 1000) : t // tolerate ms
  const diff = Math.floor(Date.now() / 1000 - sec)
  if (diff < 60) return "now"
  if (diff < 3600) return `${Math.floor(diff / 60)}m`
  if (diff < 86400) return `${Math.floor(diff / 3600)}h`
  return `${Math.floor(diff / 86400)}d`
}

function getActions(n: AstalNotifd.Notification): { id: string; label: string }[] {
  try {
    const a = (n as any).get_actions ? (n as any).get_actions() : (n as any).actions
    return Array.isArray(a) ? a : []
  } catch (_) {
    return []
  }
}

// shared card, used in both the centre and the popups
function NotifCard({ n, popup = false }: { n: AstalNotifd.Notification; popup?: boolean }) {
  const actions = getActions(n)
  const critical = n.urgency === URGENCY_CRITICAL
  const img = (n as any).image || ""
  const icon = n.appIcon || ""
  const cls = `notif-card${critical ? " critical" : ""}${popup ? " popup" : ""}`

  return (
    <box class={cls} orientation={Gtk.Orientation.VERTICAL} spacing={4}>
      <box spacing={8}>
        {icon ? (
          <image class="notif-icon" iconName={icon} pixelSize={28} valign={Gtk.Align.START} />
        ) : img ? (
          <image class="notif-image" file={img} pixelSize={38} valign={Gtk.Align.START} />
        ) : (
          <box visible={false} />
        )}
        <box orientation={Gtk.Orientation.VERTICAL} hexpand spacing={2}>
          <box spacing={6}>
            <label class="notif-app" label={n.appName || "Notification"} xalign={0} hexpand ellipsize={3} />
            <label class="notif-time" label={relativeTime(n.time)} valign={Gtk.Align.CENTER} />
            <button
              class="notif-copy"
              valign={Gtk.Align.CENTER}
              tooltipText="Copy text"
              onClicked={() =>
                execAsync(["wl-copy", `${n.summary || ""}${n.body ? `\n${n.body}` : ""}`]).catch(console.error)
              }
            >
              <label label="󰅍" />
            </button>
            <button class="notif-dismiss" valign={Gtk.Align.CENTER} onClicked={() => n.dismiss()}>
              <label label="󰅖" />
            </button>
          </box>
          {n.summary ? (
            <label class="notif-summary" label={n.summary} xalign={0} wrap maxWidthChars={34} selectable />
          ) : (
            <box visible={false} />
          )}
          {n.body ? (
            <label class="notif-body" useMarkup label={n.body} xalign={0} wrap maxWidthChars={38} selectable />
          ) : (
            <box visible={false} />
          )}
        </box>
      </box>
      {actions.length ? (
        <box class="notif-actions" spacing={6} halign={Gtk.Align.START}>
          {actions.map((a) => (
            <button class="notif-action" onClicked={() => n.invoke(a.id)}>
              <label label={a.label} />
            </button>
          ))}
        </box>
      ) : (
        <box visible={false} />
      )}
    </box>
  )
}

// ---------- the bar island + centre popover ----------
export function NotifCenter() {
  const notifd = AstalNotifd.get_default()
  const notifs = createBinding(notifd, "notifications")
  const dnd = createBinding(notifd, "dontDisturb")

  const glyph = createComputed(() => {
    if (dnd()) return "󰂛"
    return notifs().length > 0 ? "󱅫" : "󰂚"
  })
  const count = notifs((n) => n.length)

  return (
    <menubutton class="island notif-island">
      <overlay>
        <label class="notif-glyph" label={glyph} hexpand halign={Gtk.Align.CENTER} />
        <label
          class="count-badge corner notif-badge"
          $type="overlay"
          label={count((c) => `${c}`)}
          visible={count((c) => c > 0)}
          halign={Gtk.Align.END}
          valign={Gtk.Align.START}
          xalign={0.5}
          yalign={0.5}
        />
      </overlay>
      <popover>
        <box class="popover notif-popover" orientation={Gtk.Orientation.VERTICAL} spacing={10}>
          <box class="popover-header" spacing={6}>
            <label class="popover-title" label={notifs((n) => `Notifications · ${n.length}`)} hexpand xalign={0} />
            <button
              class={dnd((d) => (d ? "dd-btn icon active" : "dd-btn icon"))}
              tooltipText="Do not disturb"
              onClicked={() => notifd.set_dont_disturb(!notifd.get_dont_disturb())}
            >
              <label label={dnd((d) => (d ? "󰂛" : "󰂚"))} />
            </button>
            <button class="dd-btn icon" tooltipText="Clear all" onClicked={() => notifs().forEach((n) => n.dismiss())}>
              <label label="󰩹" />
            </button>
          </box>

          <box class="notif-list" orientation={Gtk.Orientation.VERTICAL} spacing={6}>
            <label class="td-empty" label="No notifications" visible={notifs((n) => n.length === 0)} />
            <For each={notifs}>{(n: AstalNotifd.Notification) => <NotifCard n={n} />}</For>
          </box>
        </box>
      </popover>
    </menubutton>
  )
}

// ---------- on-screen popups (auto-dismiss ~5s) ----------
export function NotifPopups(gdkmonitor: Gdk.Monitor) {
  const notifd = AstalNotifd.get_default()
  const [popups, setPopups] = createState<AstalNotifd.Notification[]>([])

  notifd.connect("notified", (_src: any, id: number) => {
    const n = notifd.get_notification(id)
    if (!n) return
    setPopups([n, ...popups().filter((x) => x.id !== id)])
    timeout(5000, () => setPopups(popups().filter((x) => x.id !== id)))
  })
  notifd.connect("resolved", (_src: any, id: number) => {
    setPopups(popups().filter((x) => x.id !== id))
  })

  const { TOP, RIGHT } = Astal.WindowAnchor
  return (
    <window
      name="notif-popups"
      namespace="ags-notifications"
      gdkmonitor={gdkmonitor}
      layer={Astal.Layer.OVERLAY}
      anchor={TOP | RIGHT}
      exclusivity={Astal.Exclusivity.NORMAL}
      visible={popups((p) => p.length > 0)}
      application={app}
    >
      <box class="notif-popups" orientation={Gtk.Orientation.VERTICAL} spacing={8}>
        <For each={popups}>{(n: AstalNotifd.Notification) => <NotifCard n={n} popup />}</For>
      </box>
    </window>
  )
}
