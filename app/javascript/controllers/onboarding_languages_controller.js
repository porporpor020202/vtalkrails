import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["native", "learning"]

  connect() {
    this.sync()
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
