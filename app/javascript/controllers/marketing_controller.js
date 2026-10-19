import { Controller } from "@hotwired/stimulus"
import { trackMarketingEvent } from "helpers/marketing_events"

export default class extends Controller {
  resume() {
    if (document.visibilityState === "visible") trackMarketingEvent("app_open")
  }
}
