import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "audio", "playIcon", "pauseIcon",
    "scrubber", "fill", "currentTime", "duration",
    "stemBtn", "volume"
  ]
  static values = {
    trackId: Number,
    stem: { type: String, default: "vocals" }
  }

  connect() {
    this.audioTarget.addEventListener("timeupdate",     this.#onTimeUpdate.bind(this))
    this.audioTarget.addEventListener("loadedmetadata", this.#onMetadata.bind(this))
    this.audioTarget.addEventListener("play",           this.#onPlay.bind(this))
    this.audioTarget.addEventListener("pause",          this.#onPause.bind(this))
    this.audioTarget.addEventListener("ended",          this.#onPause.bind(this))
    this.#loadStem(this.stemValue)
  }

  disconnect() {
    this.audioTarget.pause()
    this.audioTarget.src = ""
  }

  selectStem({ params: { stem } }) {
    if (stem === this.stemValue) return
    const wasPlaying = !this.audioTarget.paused
    this.stemValue = stem
    this.stemBtnTargets.forEach(btn => {
      const active = btn.dataset.audioPlayerStemParam === stem
      btn.dataset.active = active ? "true" : "false"
    })
    this.#loadStem(stem, wasPlaying)
  }

  togglePlay() {
    if (this.audioTarget.paused) {
      this.audioTarget.play().catch(() => {})
    } else {
      this.audioTarget.pause()
    }
  }

  seek(event) {
    const rect  = this.scrubberTarget.getBoundingClientRect()
    const pct   = Math.max(0, Math.min(1, (event.clientX - rect.left) / rect.width))
    const dur   = this.audioTarget.duration
    if (dur && isFinite(dur)) this.audioTarget.currentTime = pct * dur
  }

  setVolume(event) {
    this.audioTarget.volume = parseFloat(event.target.value)
  }

  downloadCurrent() {
    window.location = `/tracks/${this.trackIdValue}/download_stem?stem=${this.stemValue}`
  }

  // private

  #loadStem(stem, autoplay = false) {
    this.audioTarget.src = `/tracks/${this.trackIdValue}/stream_stem?stem=${stem}`
    this.audioTarget.load()
    this.fillTarget.style.width = "0%"
    this.currentTimeTarget.textContent = "0:00"
    this.durationTarget.textContent    = "--:--"
    if (autoplay) this.audioTarget.play().catch(() => {})
  }

  #onPlay() {
    this.playIconTarget.classList.add("hidden")
    this.pauseIconTarget.classList.remove("hidden")
  }

  #onPause() {
    this.playIconTarget.classList.remove("hidden")
    this.pauseIconTarget.classList.add("hidden")
  }

  #onTimeUpdate() {
    const t = this.audioTarget.currentTime
    const d = this.audioTarget.duration
    if (d && isFinite(d)) this.fillTarget.style.width = `${(t / d) * 100}%`
    this.currentTimeTarget.textContent = this.#fmt(t)
  }

  #onMetadata() {
    this.durationTarget.textContent = this.#fmt(this.audioTarget.duration)
  }

  #fmt(s) {
    if (!s || isNaN(s)) return "0:00"
    return `${Math.floor(s / 60)}:${String(Math.floor(s % 60)).padStart(2, "0")}`
  }
}
