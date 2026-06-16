import { execAsync } from "ags/process"

// Route bar-side messages into the notification daemon (swaync), which also
// surfaces in the NotifCenter proxy. Fire-and-forget; never throws.

export function notifyError(summary: string, body = "") {
  execAsync(["notify-send", "-a", "ags-bar", "-u", "critical", "-i", "dialog-error", summary, body])
    .catch(console.error)
}

export function notifyInfo(summary: string, body = "") {
  execAsync(["notify-send", "-a", "ags-bar", "-i", "dialog-information", summary, body])
    .catch(console.error)
}
