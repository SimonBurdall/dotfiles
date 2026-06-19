import { createState, createComputed, For } from "ags"
import { timeout } from "ags/time"
import { execAsync } from "ags/process"
import { Gtk } from "ags/gtk4"
import GLib from "gi://GLib"

const API = "https://api.todoist.com/api/v1"
const TOKEN_PATH = "/home/si/.config/ags/todoist-token"
const REFRESH_SECS = 30

type Due = { date?: string; datetime?: string; string?: string; is_recurring?: boolean } | null
type Task = {
  id: string
  content: string
  priority?: number
  project_id?: string
  section_id?: string | null
  due?: Due
  labels?: string[]
}
type Section = { id: string; name: string; section_order?: number }

// ---- tabs: loaded from a JSON config the user can edit ----
const CONFIG_PATH = "/home/si/.config/ags/todoist.json"
const DEFAULT_TABS = ["__today__", "Inbox", "Long-Term Tasks", "Recurring Tasks", "Backlog"]
// nicer short labels; anything not listed falls back to the raw project name
const NICE_LABELS: Record<string, string> = {
  __today__: "Today",
  Inbox: "Inbox",
  "Long-Term Tasks": "Long-Term",
  "Recurring Tasks": "Recurring",
  Backlog: "Backlog",
}
function tabLabel(key: string): string {
  return NICE_LABELS[key] || key
}
function loadTabs(): { label: string; key: string }[] {
  let keys = DEFAULT_TABS
  try {
    const [, bytes] = GLib.file_get_contents(CONFIG_PATH)
    const cfg = JSON.parse(new TextDecoder().decode(bytes))
    if (Array.isArray(cfg.tabs) && cfg.tabs.length) keys = cfg.tabs
  } catch (e) {
    // missing or invalid -> write defaults so there's a file to edit
    try {
      GLib.file_set_contents(CONFIG_PATH, JSON.stringify({ tabs: DEFAULT_TABS }, null, 2))
    } catch (_) {}
  }
  return keys.map((k: string) => ({ label: tabLabel(k), key: k }))
}
const TABS = loadTabs()

// read the token file synchronously; returns "" if it's missing or empty
function readToken(): string {
  try {
    const [ok, bytes] = GLib.file_get_contents(TOKEN_PATH)
    if (!ok) return ""
    return new TextDecoder().decode(bytes).trim()
  } catch (_) {
    return ""
  }
}

let token = readToken()
async function getToken(): Promise<string> {
  if (!token) token = readToken()
  return token
}

async function apiGet(path: string): Promise<any[]> {
  const t = await getToken()
  const out = await execAsync([
    "curl", "-s", "--max-time", "6",
    "-H", `Authorization: Bearer ${t}`,
    `${API}${path}`,
  ])
  const data = JSON.parse(out)
  return Array.isArray(data) ? data : (data.results ?? [])
}

const projectIds: Record<string, string> = {}
const projectName: Record<string, string> = {}
const sectionName: Record<string, string> = {}
let backlogId = ""
let backlogName = "Backlog"

async function loadProjects() {
  const projects = await apiGet("/projects")
  for (const p of projects) {
    projectIds[p.name] = p.id
    projectName[p.id] = p.name
    // force the "Inbox" tab key onto the real inbox project, whatever it's called
    if (p.inbox_project) projectIds["Inbox"] = p.id
    // capture backlog case-insensitively for frog + add routing
    if (p.name.toLowerCase() === "backlog") {
      backlogId = p.id
      backlogName = p.name
      projectIds["Backlog"] = p.id
    }
  }
}
async function loadSections() {
  const secs = await apiGet("/sections")
  for (const s of secs) sectionName[s.id] = s.name
}

async function fetchToday(): Promise<Task[]> {
  return apiGet(`/tasks/filter?query=${encodeURIComponent("overdue | today")}`)
}
async function fetchProject(key: string): Promise<{ tasks: Task[]; sections: Section[] }> {
  if (!projectIds[key]) await loadProjects()
  const pid = projectIds[key]
  if (!pid) return { tasks: [], sections: [] }
  const [tasks, sections] = await Promise.all([
    apiGet(`/tasks?project_id=${pid}`),
    apiGet(`/sections?project_id=${pid}`),
  ])
  sections.sort((a: Section, b: Section) => (a.section_order ?? 0) - (b.section_order ?? 0))
  return { tasks, sections }
}

async function closeTask(id: string) {
  const t = await getToken()
  await execAsync([
    "curl", "-s", "--max-time", "6", "-X", "POST",
    "-H", `Authorization: Bearer ${t}`,
    `${API}/tasks/${id}/close`,
  ])
}
async function quickAdd(text: string) {
  const t = await getToken()
  await execAsync([
    "curl", "-s", "--max-time", "6", "-X", "POST",
    "-H", `Authorization: Bearer ${t}`,
    "--data-urlencode", `text=${text}`,
    `${API}/tasks/quick`,
  ])
}

async function updateTask(id: string, body: Record<string, any>) {
  const t = await getToken()
  await execAsync([
    "curl", "-s", "--max-time", "6", "-X", "POST",
    "-H", `Authorization: Bearer ${t}`,
    "-H", "Content-Type: application/json",
    "-d", JSON.stringify(body),
    `${API}/tasks/${id}`,
  ])
}

// rotate the frog: clear any existing frog, pick a random Backlog task,
// tag it #frog, due today, priority 4 (matches the Python script)
async function pickFrog() {
  if (!backlogId) await loadProjects()
  if (!backlogId) return
  const tasks = await apiGet(`/tasks?project_id=${backlogId}`)
  for (const t of tasks) {
    if ((t.labels ?? []).includes("frog")) {
      await updateTask(t.id, {
        labels: (t.labels ?? []).filter((l: string) => l !== "frog"),
        priority: 1,
        due_string: "no date",
      })
    }
  }
  const eligible = tasks.filter((t: any) => !t.is_completed)
  if (!eligible.length) return
  const frog = eligible[Math.floor(Math.random() * eligible.length)]
  const labels = [...(frog.labels ?? [])]
  if (!labels.includes("frog")) labels.push("frog")
  await updateTask(frog.id, {
    labels,
    due_date: new Date().toISOString().slice(0, 10),
    priority: 4,
  })
}

function escapeMarkup(s: string): string {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
}
// keep Todoist's bold (**x**) as Pango <b>, strip the rest
function mdToPango(s: string): string {
  let e = escapeMarkup(s)
  e = e.replace(/\[([^\]]+)\]\([^)]+\)/g, "$1")
  e = e.replace(/\*\*(.+?)\*\*/g, "<b>$1</b>")
  e = e.replace(/__(.+?)__/g, "<b>$1</b>")
  return e
}

function humanizeDate(iso: string): string {
  const hasTime = iso.includes("T")
  const d = new Date(iso)
  const today = new Date()
  today.setHours(0, 0, 0, 0)
  const day = new Date(d)
  day.setHours(0, 0, 0, 0)
  const diff = Math.round((day.getTime() - today.getTime()) / 86400000)
  let datePart: string
  if (diff === 0) datePart = "Today"
  else if (diff === 1) datePart = "Tomorrow"
  else if (diff === -1) datePart = "Yesterday"
  else if (diff > 1 && diff < 7) datePart = d.toLocaleDateString("en-GB", { weekday: "long" })
  else datePart = d.toLocaleDateString("en-GB", { day: "numeric", month: "short" })
  if (hasTime) {
    const time = d.toLocaleTimeString("en-GB", { hour: "numeric", minute: "2-digit" })
    return `${datePart} ${time}`
  }
  return datePart
}
function dueText(due: Due): string {
  if (!due) return ""
  const iso = due.datetime || due.date || ""
  const dateStr = iso ? humanizeDate(iso) : ""
  if (due.is_recurring && due.string) {
    return dateStr ? `󰑖 ${due.string} · ${dateStr}` : `󰑖 ${due.string}`
  }
  return dateStr || due.string || ""
}

function TaskRow({ task, onComplete, showSource = false }: { task: Task; onComplete: (id: string) => void; showSource?: boolean }) {
  const [done, setDone] = createState(false)
  const prio = task.priority ?? 1
  const labels = (task.labels ?? []).map((l) => `#${l}`).join(" ")
  const leftMeta = [dueText(task.due ?? null), labels].filter(Boolean).join("  ·  ")
  const proj = showSource && task.project_id ? projectName[task.project_id] || "" : ""
  const sec = showSource && task.section_id ? sectionName[task.section_id] || "" : ""
  const md = mdToPango(task.content)

  const complete = () => {
    setDone(true)
    timeout(150, () => onComplete(task.id))
  }
  const openWeb = () =>
    execAsync(["xdg-open", `https://app.todoist.com/app/task/${task.id}`]).catch(console.error)

  const rowClass = done((d) => (d ? "task-row done" : "task-row"))
  const contentMarkup = done((d) => (d ? `<s>${md}</s>` : md))

  return (
    <box class={rowClass} spacing={8}>
      <button class={`task-check p${prio}`} onClicked={complete} valign={Gtk.Align.START}>
        <label label="○" />
      </button>
      <button class="task-open" hexpand onClicked={openWeb}>
        <box orientation={Gtk.Orientation.VERTICAL} hexpand spacing={1}>
          <label class="task-content" useMarkup label={contentMarkup} xalign={0} wrap maxWidthChars={40} />
          <box spacing={8}>
            {leftMeta ? <label class="task-meta" label={leftMeta} xalign={0} hexpand /> : <box hexpand />}
            {/* source: ellipsised project / section, like the web */}
            <box class="task-source" spacing={3} halign={Gtk.Align.END} visible={!!(proj || sec)}>
              {proj ? <label class="src-proj" label={proj} ellipsize={3} maxWidthChars={11} /> : <box visible={false} />}
              {proj && sec ? <label class="src-sep" label="/" /> : <box visible={false} />}
              {sec ? <label class="src-sec" label={sec} ellipsize={3} maxWidthChars={16} /> : <box visible={false} />}
            </box>
          </box>
        </box>
      </button>
    </box>
  )
}

function SectionGroup({ name, tasks, onComplete }: { name: string | null; tasks: Task[]; onComplete: (id: string) => void }) {
  return (
    <box orientation={Gtk.Orientation.VERTICAL} spacing={2}>
      {name ? <label class="td-section" label={name} xalign={0} /> : <box visible={false} />}
      {tasks.map((task) => (
        <TaskRow task={task} onComplete={onComplete} />
      ))}
    </box>
  )
}

export function Todoist() {
  const [activeTab, setActiveTab] = createState("__today__")
  const [tasks, setTasks] = createState<Task[]>([])
  const [sections, setSections] = createState<Section[]>([])
  const [badge, setBadge] = createState(0)
  const [input, setInput] = createState("")
  const [loading, setLoading] = createState(false)
  const [frogBusy, setFrogBusy] = createState(false)
  const [refreshBusy, setRefreshBusy] = createState(false)
  // false when the token file is missing or empty -> show the notice instead of the list
  const [hasToken, setHasToken] = createState(token !== "")

  // only push new state when the data actually changed (avoids needless re-renders)
  let lastKey = ""
  let lastJson = ""

  async function refresh() {
    if (!hasToken()) return
    const key = activeTab()
    try {
      let t: Task[]
      let s: Section[] = []
      if (key === "__today__") {
        t = await fetchToday()
        setBadge(t.length)
      } else {
        const r = await fetchProject(key)
        t = r.tasks
        s = r.sections
      }
      const j = JSON.stringify(t) + JSON.stringify(s)
      if (key !== lastKey || j !== lastJson) {
        setTasks(t)
        setSections(s)
        lastKey = key
        lastJson = j
      }
    } catch (e) {
      console.error("todoist refresh", e)
    }
  }

  async function refreshBadge() {
    if (!hasToken()) return
    try {
      setBadge((await fetchToday()).length)
    } catch (e) {
      console.error("todoist badge", e)
    }
  }

  // force a fetch + UI update even if data looks unchanged (used after edits)
  function forceRefresh() {
    lastJson = ""
    refresh()
    refreshBadge()
  }

  // optimistic completion: drop the row from local state immediately so the list
  // collapses with no blank gap, then close on Todoist and reconcile.
  function completeTask(id: string) {
    setTasks(tasks().filter((t) => t.id !== id))
    setBadge(Math.max(0, badge() - 1))
    closeTask(id)
      .then(() => {
        lastJson = ""
        refresh()
      })
      .catch((e) => {
        console.error("todoist close", e)
        lastJson = ""
        refresh()
      })
  }

  // click feedback: spin + mute the glyph for ~600ms while the action runs
  function runRefresh() {
    setRefreshBusy(true)
    forceRefresh()
    timeout(600, () => setRefreshBusy(false))
  }
  function runFrog() {
    setFrogBusy(true)
    pickFrog().then(forceRefresh).catch(console.error)
    timeout(600, () => setFrogBusy(false))
  }

  function select(key: string) {
    setLoading(true)
    setActiveTab(key)
    // brief fade covers the fetch; keep it up ~100ms minimum so it reads as intentional
    refresh()
      .then(() => timeout(60, () => setLoading(false)))
      .catch(() => setLoading(false))
  }

  function submitAdd(text: string) {
    const c = text.trim()
    if (!c) return
    setInput("")
    // capture into Backlog, then jump to the Backlog tab to show it
    quickAdd(`${c} #${backlogName}`).then(() => select("Backlog")).catch(console.error)
  }

  async function init() {
    if (!hasToken()) return
    await Promise.all([loadProjects(), loadSections()])
    refresh()
  }
  init()

  // re-read the token (used by the Retry button when it was missing at startup)
  function retryToken() {
    token = readToken()
    if (token) {
      setHasToken(true)
      init()
    }
  }

  // reliable periodic refresh; UI only updates if something changed
  GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, REFRESH_SECS, () => {
    if (hasToken()) {
      refresh()
      if (activeTab() !== "__today__") refreshBadge()
    }
    return GLib.SOURCE_CONTINUE
  })

  const headerLabel = createComputed(() => {
    const tab = TABS.find((t) => t.key === activeTab())?.label ?? "Tasks"
    return `${tab} · ${tasks().length} open`
  })
  const isEmpty = tasks((t) => t.length === 0)
  const isToday = activeTab((a) => a === "__today__")

  const today = () => new Date().toISOString().slice(0, 10)
  const overdue = createComputed(() => {
    if (activeTab() !== "__today__") return []
    return tasks().filter((t) => t.due?.date && t.due.date < today())
  })
  const current = createComputed(() => {
    if (activeTab() !== "__today__") return []
    return tasks().filter((t) => !(t.due?.date && t.due.date < today()))
  })
  const overdueVisible = overdue((o) => o.length > 0)

  const groups = createComputed(() => {
    if (activeTab() === "__today__") return []
    const ts = tasks()
    const secs = sections()
    const byId: Record<string, Task[]> = {}
    const noSec: Task[] = []
    for (const t of ts) {
      if (t.section_id) (byId[t.section_id] ??= []).push(t)
      else noSec.push(t)
    }
    const out: { name: string | null; tasks: Task[] }[] = []
    if (noSec.length) out.push({ name: null, tasks: noSec })
    for (const s of secs) {
      if (byId[s.id]?.length) out.push({ name: s.name, tasks: byId[s.id] })
    }
    return out
  })

  return (
    <menubutton class="island td-island">
      <overlay>
        <label class="td-glyph" label={"\uf0ae"} hexpand halign={Gtk.Align.CENTER} />
        <label
          class="count-badge corner"
          $type="overlay"
          label={badge((c) => `${c}`)}
          visible={badge((c) => c > 0)}
          halign={Gtk.Align.END}
          valign={Gtk.Align.START}
          xalign={0.5}
          yalign={0.5}
        />
      </overlay>
      <popover>
        <box class="popover todoist-popover" orientation={Gtk.Orientation.VERTICAL} spacing={10}>
          {/* shown only when the token file is missing or empty */}
          <box class="td-no-token" orientation={Gtk.Orientation.VERTICAL} spacing={8} visible={hasToken((h) => !h)}>
            <label class="td-no-token-title" label={"\uf0ae  No Todoist token"} />
            <label
              class="td-no-token-hint"
              label="Add your API token to ~/.config/ags/todoist-token, then hit Retry."
              wrap
              xalign={0}
              maxWidthChars={32}
            />
            <button class="td-no-token-retry" halign={Gtk.Align.START} onClicked={retryToken}>
              <label label="Retry" />
            </button>
          </box>

          <box class="popover-header" spacing={6} visible={hasToken}>
            <label class="popover-title" label={headerLabel} hexpand xalign={0} />
            <button
              class={frogBusy((b) => (b ? "dd-btn icon frog-btn busy" : "dd-btn icon frog-btn"))}
              tooltipText="Pick a new frog"
              onClicked={runFrog}
            >
              <label label={"🐸"} />
            </button>
            <button class={refreshBusy((b) => (b ? "dd-btn icon busy" : "dd-btn icon"))} onClicked={runRefresh}>
              <label label="󰑐" />
            </button>
          </box>

          <box class="td-tabs" spacing={4} visible={hasToken}>
            {TABS.map((tab) => (
              <button
                class={activeTab((a) => (a === tab.key ? "td-tab active" : "td-tab"))}
                onClicked={() => select(tab.key)}
              >
                <label label={tab.label} />
              </button>
            ))}
          </box>

          <box
            class={loading((l) => (l ? "td-list loading" : "td-list"))}
            orientation={Gtk.Orientation.VERTICAL}
            spacing={2}
            visible={hasToken}
          >
            <label class="td-empty" label="Nothing here" visible={isEmpty} />

            <box orientation={Gtk.Orientation.VERTICAL} spacing={2} visible={overdueVisible}>
              <label class="td-section overdue" label="Overdue" xalign={0} />
              <For each={overdue}>
                {(task: Task) => <TaskRow task={task} onComplete={completeTask} showSource />}
              </For>
            </box>
            <box orientation={Gtk.Orientation.VERTICAL} spacing={2} visible={isToday}>
              <label class="td-section" label="Today" xalign={0} />
              <For each={current}>
                {(task: Task) => <TaskRow task={task} onComplete={completeTask} showSource />}
              </For>
            </box>

            <For each={groups}>
              {(g: { name: string | null; tasks: Task[] }) => (
                <SectionGroup name={g.name} tasks={g.tasks} onComplete={completeTask} />
              )}
            </For>
          </box>

          <box class="td-add" spacing={6} visible={hasToken}>
            <entry
              class="td-entry"
              hexpand
              placeholderText="Add to Backlog… (e.g. every Friday)"
              text={input}
              onNotifyText={(self) => setInput(self.get_text())}
              onActivate={(self) => submitAdd(self.get_text())}
            />
            <button class="td-add-btn" onClicked={() => submitAdd(input())}>
              <label label="+" />
            </button>
          </box>
        </box>
      </popover>
    </menubutton>
  )
}
