import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["title", "hint", "continue", "login"]
  select(event) {
    const messages = JSON.parse(document.getElementById("language-selection-translations").textContent)[event.target.value]
    this.titleTarget.textContent = messages.choose_language
    this.hintTarget.textContent = messages.choose_hint
    if (this.hasLoginTarget) this.loginTarget.textContent = messages.existing_account_login
    this.continueTarget.value = messages.continue
    this.continueTarget.disabled = false
  }
}
