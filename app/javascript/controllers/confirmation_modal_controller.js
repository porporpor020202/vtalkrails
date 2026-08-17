import { Controller } from "@hotwired/stimulus"

// Keeps destructive-action confirmation inside the web UI. This avoids
// relying on window.confirm(), which is not consistently presented by native
// WebViews.
export default class extends Controller {
  static targets = ["dialog", "form", "confirmButton"]

  connect() {
    this.confirmed = false
    this.onKeydown = this.handleKeydown.bind(this)
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKeydown)
  }

  submit(event) {
    if (this.confirmed) {
      this.confirmed = false
      return
    }

    event.preventDefault()
    this.open()
  }

  open() {
    this.dialogTarget.hidden = false
    this.dialogTarget.setAttribute("aria-hidden", "false")
    document.addEventListener("keydown", this.onKeydown)
    this.confirmButtonTarget.focus()
  }

  close() {
    this.dialogTarget.hidden = true
    this.dialogTarget.setAttribute("aria-hidden", "true")
    document.removeEventListener("keydown", this.onKeydown)
  }

  cancel() {
    this.close()
  }

  confirm() {
    this.confirmed = true
    this.close()
    this.formTarget.requestSubmit()
  }

  closeOnBackdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }

  stopPropagation(event) {
    event.stopPropagation()
  }

  handleKeydown(event) {
    if (event.key === "Escape") this.close()
  }
}
