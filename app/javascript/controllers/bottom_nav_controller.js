import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="bottom-nav"
export default class extends Controller {
  static targets = [ "link" ]

  connect() {
    this.updateActiveTab()
    this.onFrameLoad = this.updateActiveTab.bind(this)
    this.onTurboLoad = this.updateActiveTab.bind(this)
    document.addEventListener("turbo:frame-render", this.onFrameLoad)
    document.addEventListener("turbo:load", this.onTurboLoad)
  }

  disconnect() {
    document.removeEventListener("turbo:frame-render", this.onFrameLoad)
    document.removeEventListener("turbo:load", this.onTurboLoad)
  }

  updateActiveTab() {
    // The root route renders the Rooms index too.
    const currentPath = window.location.pathname === "/" ? "/rooms" : window.location.pathname
    this.linkTargets.forEach(link => {
      const linkUrl = new URL(link.href, window.location.origin)
      const linkPath = linkUrl.pathname

      const sayPage = currentPath === "/rooms" || currentPath.startsWith("/rooms/")
      const isActive = link.dataset.bottomNavTab
        ? sayPage
        : currentPath === linkPath || currentPath === "/profile"

      if (isActive) {
        link.setAttribute("aria-current", "page")
        link.classList.add("text-indigo-600")
        link.classList.remove("text-slate-400")
      } else {
        link.removeAttribute("aria-current")
        link.classList.remove("text-indigo-600")
        link.classList.add("text-slate-400")
      }
    })
  }
}
