import { translate } from "helpers/translations"
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["audio", "button", "play", "stop", "error", "gauge", "ring"]
  async toggle() {
    this.errorTarget.hidden = true
    if (!this.audioTarget.paused) { this.audioTarget.pause(); this.audioTarget.currentTime = 0; this.update(); return }
    try { await this.audioTarget.play() } catch { this.error() }
  }
  update() {
    const playing = !this.audioTarget.paused && !this.audioTarget.ended
    this.playTarget.toggleAttribute("hidden", playing)
    this.stopTarget.toggleAttribute("hidden", !playing)
    this.buttonTarget.setAttribute("aria-label", playing ? translate("stop_play") : translate("play"))
    cancelAnimationFrame(this.animation)
    this.progress()
    if (playing) this.animate()
  }
  progress() {
    const audio = this.audioTarget
    const duration = Number.isFinite(audio.duration) && audio.duration > 0 ? audio.duration : Number(audio.dataset.durationMs) / 1000
    const percent = audio.ended ? 100 : duration > 0 ? Math.min(100, Math.max(0, audio.currentTime / duration * 100)) : 0
    this.ringTarget.setAttribute("stroke-dashoffset", String(100 - percent))
    this.gaugeTarget.setAttribute("aria-valuenow", String(Math.round(percent)))
  }
  animate() {
    this.progress()
    if (!this.audioTarget.paused && !this.audioTarget.ended) this.animation = requestAnimationFrame(() => this.animate())
  }
  error() { this.errorTarget.textContent = translate("play_error"); this.errorTarget.hidden = false; this.update() }
  disconnect() { cancelAnimationFrame(this.animation); this.audioTarget.pause() }
}
