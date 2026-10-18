import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]
  static values = { endpoint: String, token: String }

  open() { this.dialogTarget.showModal(); this.dispatch("open", { detail: { slot: this.dialogTarget.querySelector("[data-recording-slot]") } }); this.loadExample() }
  close() { this.dialogTarget.close() }
  closed() { this.dispatch("close") }
  backdrop(event) { if (event.target === this.dialogTarget) this.close() }
  restoreExample() {
    const input = this.dialogTarget.querySelector("textarea")
    if (input && this.example) input.placeholder = `예: ${this.example}`
  }
  async loadExample() {
    if (this.example || this.loadingExample) return
    this.loadingExample = true
    try {
      const form = new FormData()
      form.append("mode", "example")
      form.append("question_token", this.tokenValue)
      const response = await fetch(this.endpointValue, { method: "POST", headers: { Accept: "application/json", "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || "" }, body: form, credentials: "same-origin" })
      if (!response.ok || !this.element.isConnected) return
      const result = await response.json()
      if (typeof result.example === "string" && result.example.trim()) { this.example = result.example; this.restoreExample() }
    } catch { /* Keep the plain placeholder when examples are unavailable. */ }
    finally { this.loadingExample = false }
  }
  disconnect() { if (this.dialogTarget.open) this.dialogTarget.close() }
}
