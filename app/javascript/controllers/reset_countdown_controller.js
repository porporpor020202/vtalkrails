import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["clock", "ready"]
  static values = { at: String, now: String }

  connect() { this.start() }
  atValueChanged() { if (this.element.isConnected) this.start() }
  nowValueChanged() { if (this.element.isConnected) this.start() }
  start() {
    clearInterval(this.interval)
    this.startedAt = performance.now()
    this.remaining = new Date(this.atValue).getTime() - new Date(this.nowValue).getTime()
    this.tick()
    this.interval = setInterval(() => this.tick(), 1000)
  }
  tick() {
    if (!Number.isFinite(this.remaining)) return
    const seconds = Math.max(0, Math.ceil((this.remaining - (performance.now() - this.startedAt)) / 1000))
    const hours = Math.floor(seconds / 3600)
    const minutes = Math.floor(seconds % 3600 / 60)
    this.clockTarget.textContent = [hours, minutes, seconds % 60].map(value => String(value).padStart(2, "0")).join(":")
    this.clockTarget.hidden = seconds === 0
    this.readyTarget.hidden = seconds !== 0
    if (seconds === 0) clearInterval(this.interval)
  }
  disconnect() { clearInterval(this.interval) }
}
