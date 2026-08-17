import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["indicator", "label"]

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
    this.labelTarget.textContent = "Refreshing…"
    this.setIndicator(72)

    // Turbo will replace the current index without adding a browser history entry.
    if (window.Turbo) {
      window.Turbo.visit(window.location.href, { action: "replace" })
    } else {
      window.location.reload()
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

    const offset = Math.max(-48, Math.min(distance - 48, 72))
    this.indicatorTarget.style.transform = `translateY(${offset}px)`
  }
}
