import { Controller } from "@hotwired/stimulus"

// UI prototype only: no microphone capture or translation request.
export default class extends Controller {
  static targets = ["prompt", "result"]

  open() {
    this.promptTarget.classList.remove("hidden")
    this.resultTarget.classList.add("hidden")
  }

  translate() {
    this.promptTarget.classList.add("hidden")
    this.resultTarget.classList.remove("hidden")
  }
}
