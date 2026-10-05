import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["native", "learning"]

  connect() {
    this.sync()
  }

  validate(event) {
    if (this.nativeTarget.value && this.learningTarget.value) return

    event.preventDefault()
    window.alert("Please select both your native language and learning language.")
  }

  sync() {
    const nativeLanguage = this.nativeTarget.value

    for (const option of this.learningTarget.options) {
      option.disabled = option.value !== "" && option.value === nativeLanguage
    }

    if (nativeLanguage && this.learningTarget.value === nativeLanguage) {
      this.learningTarget.value = ""
    }
  }
}
