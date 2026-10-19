import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["title", "hint", "continue"]
  select(event) {
    const messages = JSON.parse(document.getElementById("language-selection-translations").textContent)[event.target.value]
    this.titleTarget.textContent = messages.choose_language
    this.hintTarget.textContent = messages.choose_hint
    this.continueTarget.value = messages.continue
    this.continueTarget.disabled = false
  }
}
