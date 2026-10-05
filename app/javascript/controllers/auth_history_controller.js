import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  restore(event) {
    if (event.persisted) window.location.reload()
  }
}
