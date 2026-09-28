import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const zone = Intl.DateTimeFormat().resolvedOptions().timeZone
    if (zone) document.cookie = `time_zone=${encodeURIComponent(zone)}; Path=/; SameSite=Lax; Max-Age=2592000${location.protocol === "https:" ? "; Secure" : ""}`
  }
}
