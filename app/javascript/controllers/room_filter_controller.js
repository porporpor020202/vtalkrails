import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  submit() {
    const url = new URL(this.element.action)
    url.search = new URLSearchParams(new FormData(this.element)).toString()
    window.history.replaceState(window.history.state, "", url)
    this.element.requestSubmit()
  }
}
