import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "mother", "learning", "submit" ]

  connect() {
    this.update()
  }

  update() {
    const mother = this.motherTarget.value
    if (mother && this.learningTarget.value === mother) this.learningTarget.value = ""
    for (const option of this.learningTarget.options) {
      option.disabled = Boolean(mother && option.value === mother)
    }
    this.submitTarget.disabled = !mother || !this.learningTarget.value
  }
}
