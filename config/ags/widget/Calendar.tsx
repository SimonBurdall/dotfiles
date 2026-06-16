import { createState, createComputed, For } from "ags"
import { createPoll } from "ags/time"
import { Gtk } from "ags/gtk4"

const MONTHS = [
  "January", "February", "March", "April", "May", "June",
  "July", "August", "September", "October", "November", "December",
]
const WEEKDAYS = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

// weeks of the month, Monday-first, null-padded to full weeks
function buildMonth(year: number, month: number): (number | null)[][] {
  const firstWeekday = (new Date(year, month, 1).getDay() + 6) % 7 // Mon=0
  const daysInMonth = new Date(year, month + 1, 0).getDate()
  const cells: (number | null)[] = []
  for (let i = 0; i < firstWeekday; i++) cells.push(null)
  for (let d = 1; d <= daysInMonth; d++) cells.push(d)
  while (cells.length % 7 !== 0) cells.push(null)
  const weeks: (number | null)[][] = []
  for (let i = 0; i < cells.length; i += 7) weeks.push(cells.slice(i, i + 7))
  return weeks
}

export function Calendar() {
  const clock = createPoll("", 1000, "date +'󰥔 <b>%H:%M</b>  %d/%m/%Y'")
  const now = new Date()
  const [year, setYear] = createState(now.getFullYear())
  const [month, setMonth] = createState(now.getMonth())

  function prev() {
    const m = month() - 1
    if (m < 0) {
      setMonth(11)
      setYear(year() - 1)
    } else setMonth(m)
  }
  function next() {
    const m = month() + 1
    if (m > 11) {
      setMonth(0)
      setYear(year() + 1)
    } else setMonth(m)
  }
  function jump() {
    const n = new Date()
    setYear(n.getFullYear())
    setMonth(n.getMonth())
  }

  const title = createComputed(() => `${MONTHS[month()]} ${year()}`)
  const weeks = createComputed(() => buildMonth(year(), month()))

  function isToday(day: number): boolean {
    const n = new Date()
    return year() === n.getFullYear() && month() === n.getMonth() && day === n.getDate()
  }

  return (
    <menubutton class="island cal-island">
      <label useMarkup label={clock} />
      <popover>
        <box class="popover cal-popover" orientation={Gtk.Orientation.VERTICAL} spacing={6}>
          <box class="cal-header">
            <button class="dd-btn icon" valign={Gtk.Align.CENTER} onClicked={prev}>
              <label halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER} label="󰅁" />
            </button>
            <label class="cal-title" label={title} hexpand halign={Gtk.Align.CENTER} />
            <button class="dd-btn icon" valign={Gtk.Align.CENTER} onClicked={next}>
              <label halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER} label="󰅂" />
            </button>
          </box>

          <box class="cal-weekdays" homogeneous>
            {WEEKDAYS.map((d) => (
              <label class="cal-wd" label={d} />
            ))}
          </box>

          <box class="cal-grid" orientation={Gtk.Orientation.VERTICAL} spacing={4}>
            <For each={weeks}>
              {(week: (number | null)[]) => (
                <box homogeneous spacing={4}>
                  {week.map((cell) =>
                    cell === null ? (
                      <box class="cal-cell" />
                    ) : (
                      <box class="cal-cell">
                        <label
                          class={isToday(cell) ? "cal-day today" : "cal-day"}
                          label={`${cell}`}
                          halign={Gtk.Align.CENTER}
                        />
                      </box>
                    ),
                  )}
                </box>
              )}
            </For>
          </box>

          <button class="dd-action" onClicked={jump}>
            <box spacing={8} halign={Gtk.Align.CENTER}>
              <label label="󰥔" />
              <label label="Jump to today" />
            </box>
          </button>
        </box>
      </popover>
    </menubutton>
  )
}
