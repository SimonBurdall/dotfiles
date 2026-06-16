import { createState } from "ags"
import { execAsync } from "ags/process"
import { Gtk } from "ags/gtk4"
import GLib from "gi://GLib"

const POLL_MS = 2000
const HISTORY = 40
// terminal used for the btop button (change if you don't use kitty)
const BTOP_CMD = ["kitty", "-e", "btop"]

// rolling histories — plain arrays the sparklines read directly
const hist = {
  cpu: [] as number[],
  gpu: [] as number[],
  mem: [] as number[],
  down: [] as number[],
  up: [] as number[],
}
function push(arr: number[], v: number) {
  arr.push(v)
  if (arr.length > HISTORY) arr.shift()
}

// registered drawing areas, redrawn together each poll
const sparkAreas: any[] = []
// sparkline colour, pulled from pywal color4 so it matches the islands
let accentRgb: [number, number, number] = [217, 138, 90]

async function sh(cmd: string): Promise<string> {
  return execAsync(["sh", "-c", cmd])
}

// ---- readers ----
let prevCpu: { idle: number; total: number } | null = null
let prevNet: { rx: number; tx: number; t: number } | null = null
let netIface = ""

async function readCpu(): Promise<number> {
  const line = (await sh("head -1 /proc/stat")).trim()
  const p = line.split(/\s+/).slice(1).map(Number)
  const idle = p[3] + (p[4] || 0)
  const total = p.reduce((a, b) => a + b, 0)
  let pct = 0
  if (prevCpu) {
    const di = idle - prevCpu.idle
    const dt = total - prevCpu.total
    pct = dt > 0 ? (1 - di / dt) * 100 : 0
  }
  prevCpu = { idle, total }
  return Math.max(0, Math.min(100, pct))
}

async function readMem(): Promise<{ used: number; total: number; pct: number }> {
  const mi = await sh("cat /proc/meminfo")
  const g = (k: string) => Number(mi.match(new RegExp(k + ":\\s+(\\d+)"))?.[1] ?? 0)
  const total = g("MemTotal")
  const avail = g("MemAvailable")
  const used = total - avail
  return { used: used / 1048576, total: total / 1048576, pct: total ? (used / total) * 100 : 0 }
}

async function readGpu(): Promise<{ name: string; util: number; temp: number } | null> {
  try {
    const out = (
      await sh("nvidia-smi --query-gpu=name,utilization.gpu,temperature.gpu --format=csv,noheader,nounits")
    ).trim()
    if (!out) return null
    const [name, util, temp] = out.split(",").map((s) => s.trim())
    return { name, util: parseFloat(util) || 0, temp: parseFloat(temp) || 0 }
  } catch {
    return null
  }
}

async function readNet(): Promise<{ down: number; up: number }> {
  if (!netIface) {
    try {
      netIface = (await sh("ip route show default | awk '{print $5; exit}'")).trim()
    } catch {}
  }
  if (!netIface) return { down: 0, up: 0 }
  const line = (await sh(`grep '${netIface}:' /proc/net/dev`)).trim()
  if (!line) return { down: 0, up: 0 }
  const nums = line.split(":")[1].trim().split(/\s+/).map(Number)
  const rx = nums[0]
  const tx = nums[8]
  const now = Date.now() / 1000
  let down = 0
  let up = 0
  if (prevNet) {
    const dt = now - prevNet.t || 1
    down = (rx - prevNet.rx) / dt / 1048576
    up = (tx - prevNet.tx) / dt / 1048576
  }
  prevNet = { rx, tx, t: now }
  return { down: Math.max(0, down), up: Math.max(0, up) }
}

// ---- sparkline (DrawingArea + cairo) ----
function Sparkline({ get }: { get: () => number[] }) {
  return (
    <drawingarea
      class="spark"
      hexpand
      $={(self: any) => {
        try {
          self.set_content_height(30)
          sparkAreas.push(self)
          self.set_draw_func((_a: any, cr: any, w: number, h: number) => {
            try {
              const pts = get()
              if (pts.length < 2) return
              const max = Math.max(...pts, 0.001)
              const min = Math.min(...pts, 0)
              const range = max - min || 1
              const stepX = w / (pts.length - 1)
              const [r, g, b] = accentRgb
              cr.setLineWidth(1.5)
              cr.setSourceRGBA(r / 255, g / 255, b / 255, 0.95)
              pts.forEach((v, i) => {
                const x = i * stepX
                const y = h - 2 - ((v - min) / range) * (h - 4)
                if (i === 0) cr.moveTo(x, y)
                else cr.lineTo(x, y)
              })
              cr.stroke()
            } catch (e) {
              console.error("spark draw", e)
            }
          })
        } catch (e) {
          console.error("spark setup", e)
        }
      }}
    />
  )
}

function Metric({
  icon,
  name,
  info,
  pct,
  get,
}: {
  icon: string
  name: string
  info: any
  pct: any
  get: () => number[]
}) {
  return (
    <box class="metric" orientation={Gtk.Orientation.VERTICAL} spacing={6}>
      <box spacing={10}>
        <label class="metric-icon" label={icon} valign={Gtk.Align.START} />
        <box orientation={Gtk.Orientation.VERTICAL} hexpand spacing={1}>
          <label class="metric-name" label={name} xalign={0} />
          <label class="metric-info" label={info} xalign={0} />
        </box>
        <label
          class="metric-pct"
          label={pct((p: number) => `${p.toFixed(p < 10 ? 2 : 0)}%`)}
          valign={Gtk.Align.CENTER}
          xalign={1}
        />
      </box>
      <Sparkline get={get} />
    </box>
  )
}

function NetCol({ icon, rate, get }: { icon: string; rate: any; get: () => number[] }) {
  return (
    <box class="net-col" orientation={Gtk.Orientation.VERTICAL} spacing={6}>
      <box spacing={8}>
        <box class="net-icon">
          <label label={icon} />
        </box>
        <label
          class="net-rate"
          label={rate((r: number) => `${r.toFixed(1)} MB/s`)}
          valign={Gtk.Align.CENTER}
          hexpand
          xalign={0}
        />
      </box>
      <Sparkline get={get} />
    </box>
  )
}

export function SysMon() {
  const [cpu, setCpu] = createState(0)
  const [cpuInfo, setCpuInfo] = createState("…")
  const [gpu, setGpu] = createState(0)
  const [gpuInfo, setGpuInfo] = createState("")
  const [gpuPresent, setGpuPresent] = createState(false)
  const [mem, setMem] = createState(0)
  const [memInfo, setMemInfo] = createState("")
  const [iface, setIface] = createState("")
  const [down, setDown] = createState(0)
  const [up, setUp] = createState(0)
  const [live, setLive] = createState(false)

  // one-time static info
  sh("grep -m1 'model name' /proc/cpuinfo | cut -d: -f2")
    .then((m) =>
      sh("nproc")
        .then((n) => setCpuInfo(`${m.trim()} · ${n.trim()} threads`))
        .catch(() => setCpuInfo(m.trim())),
    )
    .catch(() => {})
  sh("sed -n '5p' ~/.cache/wal/colors")
    .then((h) => {
      const m = h.trim().match(/#?([0-9a-fA-F]{6})/)
      if (m)
        accentRgb = [
          parseInt(m[1].slice(0, 2), 16),
          parseInt(m[1].slice(2, 4), 16),
          parseInt(m[1].slice(4, 6), 16),
        ]
    })
    .catch(() => {})

  async function refresh() {
    try {
      const c = await readCpu()
      setCpu(c)
      push(hist.cpu, c)

      const m = await readMem()
      setMem(m.pct)
      setMemInfo(`${m.used.toFixed(1)} / ${m.total.toFixed(1)} GiB`)
      push(hist.mem, m.pct)

      const g = await readGpu()
      if (g) {
        setGpuPresent(true)
        setGpu(g.util)
        setGpuInfo(`${g.name.replace(/NVIDIA GeForce /, "")} · ${g.temp}°C`)
        push(hist.gpu, g.util)
      } else {
        setGpuPresent(false)
      }

      const n = await readNet()
      setDown(n.down)
      setUp(n.up)
      push(hist.down, n.down)
      push(hist.up, n.up)
      if (netIface) setIface(netIface)

      setLive(true)
      sparkAreas.forEach((a) => {
        try {
          a.queue_draw()
        } catch (_) {}
      })
    } catch (e) {
      console.error("sysmon refresh", e)
      setLive(false)
    }
  }

  refresh()
  GLib.timeout_add(GLib.PRIORITY_DEFAULT, POLL_MS, () => {
    refresh()
    return GLib.SOURCE_CONTINUE
  })

  return (
    <menubutton class="island sysmon-island">
      <label label={"\udb81\udfb1"} />
      <popover>
        <box class="popover sysmon-popover" orientation={Gtk.Orientation.VERTICAL} spacing={12}>
          <box class="popover-header">
            <label class="popover-title" label="System monitor" hexpand xalign={0} />
            <box class="sysmon-live" spacing={6} valign={Gtk.Align.CENTER}>
              <box class={live((l) => (l ? "live-dot on" : "live-dot"))} valign={Gtk.Align.CENTER} />
              <label class="live-label" label="live" />
            </box>
          </box>

          <Metric icon="󰻠" name="CPU" info={cpuInfo} pct={cpu} get={() => hist.cpu} />
          <box visible={gpuPresent} orientation={Gtk.Orientation.VERTICAL}>
            <Metric icon="󰢮" name="GPU" info={gpuInfo} pct={gpu} get={() => hist.gpu} />
          </box>
          <Metric icon="󰍛" name="Memory" info={memInfo} pct={mem} get={() => hist.mem} />

          <box class="dd-divider" />
          <box class="sysmon-net" orientation={Gtk.Orientation.VERTICAL} spacing={8}>
            <box>
              <label class="sysmon-section" label="NETWORK" hexpand xalign={0} />
              <label class="sysmon-iface" label={iface} />
            </box>
            <box spacing={12} homogeneous>
              <NetCol icon="󰇚" rate={down} get={() => hist.down} />
              <NetCol icon="󰕒" rate={up} get={() => hist.up} />
            </box>
          </box>

          <button class="dd-action" onClicked={() => execAsync(BTOP_CMD).catch(console.error)}>
            <box spacing={8} halign={Gtk.Align.CENTER}>
              <label label="󰆍" />
              <label label="Open btop" />
            </box>
          </button>
        </box>
      </popover>
    </menubutton>
  )
}
