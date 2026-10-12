import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["audio", "button", "play", "pause"]

  disconnect() {
    this.audioTarget.pause()
  }

  async toggle() {
    if (this.audioTarget.paused) {
      try {
        await this.audioTarget.play()
      } catch {
        this.buttonTarget.setAttribute("aria-label", "Try playing recording again")
      }
    } else {
      this.audioTarget.pause()
    }
  }

  update() {
    const playing = !this.audioTarget.paused
    this.playTarget.classList.toggle("hidden", playing)
    this.pauseTarget.classList.toggle("hidden", !playing)
    this.buttonTarget.setAttribute("aria-label", playing ? "Pause recording" : "Play recording")
  }
}
