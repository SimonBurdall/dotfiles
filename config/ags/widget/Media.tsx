import { createState, createComputed } from "ags"
import { Gtk } from "ags/gtk4"
import GLib from "gi://GLib"
import AstalMpris from "gi://AstalMpris"

const QUOTES_PATH = "/home/si/.config/ags/quotes.json"
const ROTATE_SECS = 1800 // 30 minutes

type Quote = { text: string; author?: string }
const DEFAULT_QUOTES: Quote[] = [
  { text: "The unexamined life is not worth living.", author: "Socrates" },
  { text: "Simplicity is the ultimate sophistication.", author: "Leonardo da Vinci" },
  { text: "Talk is cheap. Show me the code.", author: "Linus Torvalds" },
  { text: "Premature optimization is the root of all evil.", author: "Donald Knuth" },
  { text: "Make it work, make it right, make it fast.", author: "Kent Beck" },
]

function loadQuotes(): Quote[] {
  try {
    const [, bytes] = GLib.file_get_contents(QUOTES_PATH)
    const cfg = JSON.parse(new TextDecoder().decode(bytes))
    if (Array.isArray(cfg.quotes) && cfg.quotes.length) return cfg.quotes
  } catch {
    // missing/invalid -> seed a default file the user can edit
    try {
      GLib.file_set_contents(QUOTES_PATH, JSON.stringify({ quotes: DEFAULT_QUOTES }, null, 2))
    } catch (_) {}
  }
  return DEFAULT_QUOTES
}

function fmtTime(sec: number): string {
  if (!isFinite(sec) || sec < 0) sec = 0
  const m = Math.floor(sec / 60)
  const s = Math.floor(sec % 60)
  return `${m}:${s.toString().padStart(2, "0")}`
}

// accent colour (pywal color4) for the Cairo-drawn progress bar
let accentRgb: [number, number, number] = [217, 138, 90]
try {
  const [, b] = GLib.file_get_contents("/home/si/.cache/wal/colors")
  const lines = new TextDecoder().decode(b).split("\n")
  const hex = (lines[4] || "").trim().match(/#?([0-9a-fA-F]{6})/) // color4 = line 5
  if (hex)
    accentRgb = [
      parseInt(hex[1].slice(0, 2), 16),
      parseInt(hex[1].slice(2, 4), 16),
      parseInt(hex[1].slice(4, 6), 16),
    ]
} catch (_) {}

// drawing areas to redraw on each poll
const mediaAreas: any[] = []

// wave-bar equalizer: animates only while something is playing
const barAreas: any[] = []
let barPhase = 0
let mediaPlaying = false

// map the active player to one of the playerctl.sh glyphs
function sourceGlyph(p: any): string {
  const id = `${p?.identity || ""} ${p?.entry || ""} ${p?.busName || ""}`.toLowerCase()
  if (id.includes("spotify")) return "󰓇"
  if (id.includes("vlc")) return "󰕼"
  if (/firefox|chrome|chromium|edge|brave|browser|epiphany|librewolf|webkit/.test(id)) return "󰖟"
  if (id.includes("podcast")) return "󰦔"
  return "󰝚"
}

function roundRect(cr: any, x: number, y: number, w: number, h: number, r: number) {
  if (w < 2 * r) r = w / 2
  cr.newSubPath()
  cr.arc(x + w - r, y + r, r, -Math.PI / 2, 0)
  cr.arc(x + w - r, y + h - r, r, 0, Math.PI / 2)
  cr.arc(x + r, y + h - r, r, Math.PI / 2, Math.PI)
  cr.arc(x + r, y + r, r, Math.PI, 1.5 * Math.PI)
  cr.closePath()
}

function MediaProgress({ frac }: { frac: () => number }) {
  return (
    <drawingarea
      class="media-progress"
      hexpand
      $={(self: any) => {
        try {
          self.set_content_height(14)
          mediaAreas.push(self)
          self.set_draw_func((_a: any, cr: any, w: number, h: number) => {
            try {
              const f = Math.max(0, Math.min(1, frac()))
              const barH = 5
              const y = (h - barH) / 2
              const [r, g, b] = accentRgb
              // track
              roundRect(cr, 0, y, w, barH, barH / 2)
              cr.setSourceRGBA(r / 255, g / 255, b / 255, 0.18)
              cr.fill()
              // fill
              const fw = Math.max(barH, w * f)
              roundRect(cr, 0, y, fw, barH, barH / 2)
              cr.setSourceRGBA(r / 255, g / 255, b / 255, 1)
              cr.fill()
              // knob
              const kx = Math.max(barH / 2, Math.min(w - 4, w * f))
              cr.arc(kx, h / 2, 4, 0, 2 * Math.PI)
              cr.setSourceRGBA(1, 1, 1, 1)
              cr.fill()
            } catch (e) {
              console.error("progress draw", e)
            }
          })
        } catch (e) {
          console.error("progress setup", e)
        }
      }}
    />
  )
}

function MediaBars({ w = 20, h = 16 }: { w?: number; h?: number } = {}) {
  return (
    <drawingarea
      class="media-bars"
      valign={Gtk.Align.CENTER}
      $={(self: any) => {
        try {
          self.set_content_width(w)
          self.set_content_height(h)
          barAreas.push(self)
          self.set_draw_func((_a: any, cr: any, ww: number, hh: number) => {
            try {
              const [r, g, b] = accentRgb
              const n = 4
              const bw = 3
              const gap = (ww - n * bw) / (n + 1)
              for (let i = 0; i < n; i++) {
                const lvl = mediaPlaying ? 0.35 + 0.65 * Math.abs(Math.sin(barPhase + i * 0.9)) : 0.22
                const bh = Math.max(2, lvl * (hh - 2))
                const x = gap + i * (bw + gap)
                cr.setSourceRGBA(r / 255, g / 255, b / 255, 1)
                roundRect(cr, x, hh - bh, bw, bh, bw / 2)
                cr.fill()
              }
            } catch (e) {
              console.error("bars draw", e)
            }
          })
        } catch (e) {
          console.error("bars setup", e)
        }
      }}
    />
  )
}

type MediaData = {
  title: string
  artist: string
  cover: string
  position: number
  length: number
  playing: boolean
  canNext: boolean
  canPrev: boolean
  source: string
  canRaise: boolean
}

export function Media() {
  const mpris = AstalMpris.get_default()
  const quotes = loadQuotes()
  const [data, setData] = createState<MediaData | null>(null)
  const [quote, setQuote] = createState<Quote>(quotes[Math.floor(Math.random() * quotes.length)])

  let current: any = null
  let lastBus: string | null = null

  // Astal normally reports seconds; guard against microseconds just in case
  const norm = (v: number) => (v > 100000 ? v / 1e6 : v)

  function tick() {
    try {
      const PLAYING = AstalMpris.PlaybackStatus.PLAYING
      const PAUSED = AstalMpris.PlaybackStatus.PAUSED
      const ps = mpris.get_players()
      let p: any =
        ps.find((x: any) => {
          try {
            return x.playbackStatus === PLAYING && !!(x.title && x.title.length)
          } catch {
            return false
          }
        }) || null
      if (p) {
        lastBus = p.busName || null
      } else {
        // nothing playing: only keep showing the track we were last playing, and
        // only while its player still exists. A closed source leaves the list, and
        // stray hovered/lingering players aren't lastBus, so both fall back to idle.
        p =
          ps.find((x: any) => {
            try {
              return (
                !!x.busName &&
                x.busName === lastBus &&
                x.playbackStatus === PAUSED &&
                !!(x.title && x.title.length)
              )
            } catch {
              return false
            }
          }) || null
        if (!p) lastBus = null
      }
      current = p
      if (!p) {
        mediaPlaying = false
        setData(null)
        return
      }
      let pos = 0
      try {
        pos = p.get_position()
      } catch (_) {
        pos = 0
      }
      const playing = p.playbackStatus === AstalMpris.PlaybackStatus.PLAYING
      mediaPlaying = playing
      setData({
        title: p.title || "Unknown",
        artist: p.artist || "",
        cover: p.coverArt || "",
        position: norm(pos),
        length: norm(p.length || 0),
        playing,
        canNext: !!p.canGoNext,
        canPrev: !!p.canGoPrevious,
        source: sourceGlyph(p),
        canRaise: !!p.canRaise,
      })
    } catch (e) {
      console.error("media tick", e)
      mediaPlaying = false
      setData(null)
    }
    mediaAreas.forEach((a) => {
      try {
        a.queue_draw()
      } catch (_) {}
    })
  }
  tick()
  GLib.timeout_add(GLib.PRIORITY_DEFAULT, 1000, () => {
    tick()
    return GLib.SOURCE_CONTINUE
  })

  // ~9fps equalizer animation, only redraws while playing
  GLib.timeout_add(GLib.PRIORITY_DEFAULT, 110, () => {
    if (mediaPlaying) {
      barPhase += 0.35
      barAreas.forEach((a) => {
        try {
          a.queue_draw()
        } catch (_) {}
      })
    }
    return GLib.SOURCE_CONTINUE
  })

  // rotate quote every 30 min (sequential)
  let qi = quotes.indexOf(quote())
  function nextQuote() {
    qi = (qi + 1) % quotes.length
    setQuote(quotes[qi])
  }
  GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, ROTATE_SECS, () => {
    nextQuote()
    return GLib.SOURCE_CONTINUE
  })

  const pill = createComputed(() => {
    const d = data()
    if (d) {
      const lead = d.playing ? "" : `${d.source} `
      return `${lead}${d.artist ? d.artist + " — " : ""}${d.title}`
    }
    return `󱀢 ${quote().text}`
  })

  const hasMedia = data((d) => d !== null)
  const noMedia = data((d) => d === null)
  const hasCover = data((d) => !!(d && d.cover))
  const noCover = data((d) => !(d && d.cover))
  const fraction = data((d) => (d && d.length > 0 ? Math.min(1, d.position / d.length) : 0))
  const posText = data((d) => (d ? fmtTime(d.position) : "0:00"))
  const lenText = data((d) => (d ? fmtTime(d.length) : "0:00"))
  const title = data((d) => d?.title || "")
  const artist = data((d) => d?.artist || "")
  const cover = data((d) => d?.cover || "")
  const playGlyph = data((d) => (d?.playing ? "󰏤" : "󰐊"))
  const qText = quote((q) => q.text)
  const qAuthor = quote((q) => (q.author ? `— ${q.author}` : ""))

  return (
    <menubutton class="island media-island">
      <box spacing={6}>
        <label class="media-src" label={data((d) => d?.source || "")} visible={data((d) => !!d?.playing)} />
        <box class="media-pill-eq" valign={Gtk.Align.CENTER} visible={data((d) => !!d?.playing)}>
          <MediaBars w={18} h={13} />
        </box>
        <label label={pill} maxWidthChars={42} ellipsize={3} />
      </box>
      <popover>
        <box class="popover media-popover" orientation={Gtk.Orientation.VERTICAL} spacing={10}>
          {/* now playing */}
          <box visible={hasMedia} spacing={10}>
            <button class="media-art-btn" valign={Gtk.Align.CENTER} tooltipText="Open source" onClicked={() => current?.raise()}>
              <box class="media-art">
                <image visible={hasCover} class="media-cover" file={cover} pixelSize={116} />
                <box visible={noCover} class="media-art-ph">
                  <label label="󰋩" halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER} hexpand vexpand />
                </box>
              </box>
            </button>
            <box orientation={Gtk.Orientation.VERTICAL} hexpand spacing={4} valign={Gtk.Align.CENTER}>
              <button class="media-title-btn" hexpand tooltipText="Open source" onClicked={() => current?.raise()}>
                <label class="media-title" label={title} xalign={0} wrap maxWidthChars={22} hexpand />
              </button>
              <label class="media-artist" label={artist} xalign={0} wrap maxWidthChars={26} />
              <MediaProgress frac={() => (data()?.length ? data()!.position / data()!.length : 0)} />
              <box>
                <label class="media-time" label={posText} hexpand xalign={0} />
                <label class="media-time" label={lenText} xalign={1} />
              </box>
              <box class="media-controls" spacing={10} halign={Gtk.Align.CENTER}>
                <button
                  class="media-btn"
                  sensitive={data((d) => !!d?.canPrev)}
                  onClicked={() => current?.previous()}
                >
                  <label label="󰒮" />
                </button>
                <button class="media-btn play" onClicked={() => current?.play_pause()}>
                  <label label={playGlyph} />
                </button>
                <button
                  class="media-btn"
                  sensitive={data((d) => !!d?.canNext)}
                  onClicked={() => current?.next()}
                >
                  <label label="󰒭" />
                </button>
              </box>
            </box>
          </box>

          {/* idle quote */}
          <box
            visible={noMedia}
            class="media-quote"
            orientation={Gtk.Orientation.VERTICAL}
            spacing={6}
          >
            <label class="quote-mark" label="󱀢" />
            <label
              class="quote-text"
              label={qText}
              wrap
              justify={Gtk.Justification.CENTER}
              xalign={0.5}
              maxWidthChars={34}
            />
            <label class="quote-author" label={qAuthor} />
            <button
              class="dd-btn icon quote-next"
              halign={Gtk.Align.CENTER}
              valign={Gtk.Align.CENTER}
              tooltipText="Next quote"
              onClicked={nextQuote}
            >
              <label halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER} label="󰑐" />
            </button>
          </box>
        </box>
      </popover>
    </menubutton>
  )
}
