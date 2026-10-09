import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select", "dialog"]

  validate(event) {
    if (this.selectTarget.value) return

    event.preventDefault()
    this.dialogTarget.showModal()
  }

  closeDialog() {
    this.dialogTarget.close()
  }
}
