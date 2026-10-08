import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["indicator", "label", "button", "frame"]

  connect() {
    this.startY = null
    this.pullDistance = 0
    this.isRefreshing = false
    this.scrollContainer = this.element.closest("main") || document.scrollingElement

    this.onTouchStart = this.handleTouchStart.bind(this)
    this.onTouchMove = this.handleTouchMove.bind(this)
    this.onTouchEnd = this.handleTouchEnd.bind(this)

    this.element.addEventListener("touchstart", this.onTouchStart, { passive: true })
    this.element.addEventListener("touchmove", this.onTouchMove, { passive: false })
    this.element.addEventListener("touchend", this.onTouchEnd, { passive: true })
    this.element.addEventListener("touchcancel", this.onTouchEnd, { passive: true })
    this.setIndicator(0)
  }

  disconnect() {
    this.element.removeEventListener("touchstart", this.onTouchStart)
    this.element.removeEventListener("touchmove", this.onTouchMove)
    this.element.removeEventListener("touchend", this.onTouchEnd)
    this.element.removeEventListener("touchcancel", this.onTouchEnd)
  }

  handleTouchStart(event) {
    if (!this.hasIndicatorTarget) return
    if (this.isRefreshing || event.touches.length !== 1 || !this.isAtTop()) return

    const target = event.target instanceof Element ? event.target : null
    if (target?.closest("a, button, input, textarea, select, audio")) return

    this.startY = event.touches[0].clientY
    this.pullDistance = 0
  }

  handleTouchMove(event) {
    if (this.startY === null || this.isRefreshing || event.touches.length !== 1) return

    const distance = event.touches[0].clientY - this.startY
    if (distance <= 0 || !this.isAtTop()) {
      this.resetGesture()
      return
    }

    event.preventDefault()
    this.pullDistance = Math.min(distance * 0.55, 110)
    this.setIndicator(this.pullDistance)
    this.labelTarget.textContent = this.pullDistance >= 72 ? "Release to refresh" : "Pull to refresh"
  }

  handleTouchEnd() {
    if (this.startY === null) return

    const shouldRefresh = this.pullDistance >= 72
    this.resetGesture()
    if (shouldRefresh) this.refresh()
  }

  async refresh() {
    if (this.isRefreshing) return

    this.isRefreshing = true
    if (this.hasLabelTarget) {
      this.labelTarget.textContent = "Refreshing…"
      this.setIndicator(72)
    }
    if (this.hasButtonTarget) {
      this.buttonTarget.disabled = true
      this.buttonTarget.textContent = "Refreshing…"
    }

    try {
      // Reload only the room list so the selected language and recorder stay intact.
      if (this.frameTarget.src === window.location.href) {
        await this.frameTarget.reload()
      } else {
        this.frameTarget.src = window.location.href
        await this.frameTarget.loaded
      }
    } finally {
      this.isRefreshing = false
      if (this.hasLabelTarget) this.labelTarget.textContent = "Pull to refresh"
      if (this.hasButtonTarget) {
        this.buttonTarget.disabled = false
        this.buttonTarget.textContent = "Refresh"
      }
      this.setIndicator(0)
    }
  }

  isAtTop() {
    return (this.scrollContainer?.scrollTop || 0) <= 0
  }

  resetGesture() {
    this.startY = null
    this.pullDistance = 0
    if (!this.isRefreshing) this.setIndicator(0)
  }

  setIndicator(distance) {
    if (!this.hasIndicatorTarget) return

    const offset = Math.max(0, Math.min(distance, 72))
    this.indicatorTarget.style.transform = `translateY(${offset}px)`
  }
}
