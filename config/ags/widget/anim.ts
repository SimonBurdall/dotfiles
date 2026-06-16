import { createPoll } from "ags/time"

// Shared looping ellipsis for any "working…" state: . -> .. -> ...
// It's one cheap timer for the whole shell. Read it from inside a
// createComputed ONLY while busy, so at rest nothing re-renders.
const frames = [".", "..", "..."]

export const dots = createPoll(".", 450, (prev: string) => {
  const next = (frames.indexOf(prev) + 1) % frames.length
  return frames[next]
})

// Shared frame spinner for any "processing…" state (nerd font nf-extra-progress_spinner_1..6).
// Same one-timer pattern: read it from inside a createComputed ONLY while busy,
// so at rest it isn't subscribed and nothing animates.
const spinFrames = ["\uee06", "\uee07", "\uee08", "\uee09", "\uee0a", "\uee0b"]

export const spinner = createPoll("\uee06", 90, (prev: string) => {
  const next = (spinFrames.indexOf(prev) + 1) % spinFrames.length
  return spinFrames[next]
})
