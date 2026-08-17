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
    const currentPath = window.location.pathname
    this.linkTargets.forEach(link => {
      const linkUrl = new URL(link.href, window.location.origin)
      const linkPath = linkUrl.pathname

      // Check exact match or prefix match for sub-resources
      const isActive = currentPath === linkPath || (linkPath !== '/' && currentPath.startsWith(linkPath))
      
      if (isActive) {
        link.setAttribute("aria-current", "page")
        link.classList.add("text-indigo-600", "dark:text-indigo-400", "font-semibold")
        link.classList.remove("text-slate-500", "dark:text-slate-400")
      } else {
        link.removeAttribute("aria-current")
        link.classList.remove("text-indigo-600", "dark:text-indigo-400", "font-semibold")
        link.classList.add("text-slate-500", "dark:text-slate-400")
      }
    })
  }
}
