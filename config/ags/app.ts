import app from "ags/gtk4/app"
import style from "./style.scss"
import Bar from "./widget/Bar"
import { NotifPopups } from "./widget/Notifications"
import { PowerMenu, togglePowerMenu } from "./widget/PowerMenu"   // <- add

app.start({
  css: style,
  requestHandler(request, res) {
    const cmd = Array.isArray(request) ? request[0] : String(request)
    if (cmd === "powermenu") { togglePowerMenu(); res("ok") }
    else res("")
  },
  main() {
    const monitors = app.get_monitors()
    monitors.map(Bar)
    monitors.map(NotifPopups)
    PowerMenu(monitors[0])                                        // <- add (one instance)
  },
})
