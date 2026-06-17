import { execAsync } from "ags/process"

export function notifyError(summary: string, body = "") {
  execAsync(["notify-send", "-a", "ags-bar", "-u", "critical", "-i", "dialog-error", summary, body])
    .catch(console.error)
}

export function notifyInfo(summary: string, body = "") {
  execAsync(["notify-send", "-a", "ags-bar", "-i", "dialog-information", summary, body])
    .catch(console.error)
}
