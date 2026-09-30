import { Controller } from "@hotwired/stimulus"

let paddleLoader
function loadPaddle() {
  if (window.Paddle) return Promise.resolve()
  if (!paddleLoader) paddleLoader = new Promise((resolve, reject) => {
    const script = document.createElement("script")
    script.src = "https://cdn.paddle.com/paddle/v2/paddle.js"
    script.onload = resolve
    script.onerror = () => { paddleLoader = null; reject(new Error("Could not load checkout. Please try again.")) }
    document.head.append(script)
  })
  return paddleLoader
}

export default class extends Controller {
  static targets = ["price", "subscribe", "status", "webReady"]
  static values = { provider: String, product: String, basePlan: String, account: String, active: Boolean, paddleToken: String, sandbox: Boolean }

  connect() {
    this.abortController = new AbortController()
    this.onNative = event => this.nativeResult(event.detail)
    window.addEventListener("vip:store", this.onNative)
    if (this.providerValue === "paddle") {
      if (this.hasSubscribeTarget && this.hasWebReadyTarget) this.subscribeTarget.disabled = false
      if (new URLSearchParams(location.search).has("_ptxn")) this.resumeCheckout()
    } else {
      this.command("load")
    }
  }

  disconnect() {
    this.abortController.abort()
    window.removeEventListener("vip:store", this.onNative)
  }

  async api(path, body) {
    const response = await fetch(path, {
      method: body ? "POST" : "GET", credentials: "same-origin", signal: this.abortController.signal,
      headers: { Accept: "application/json", "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || "" },
      body: body ? JSON.stringify(body) : undefined
    })
    const data = await response.json()
    if (!response.ok) throw new Error(data.error || "Could not verify your subscription. Please try Restore purchases.")
    return data
  }

  async initializePaddle() {
    await loadPaddle()
    if (this.sandboxValue) window.Paddle.Environment.set("sandbox")
    const callback = event => {
      if (event.name === "checkout.completed") this.waitForVip()
    }
    if (window.Paddle.Initialized) window.Paddle.Update({ eventCallback: callback })
    else window.Paddle.Initialize({ token: this.paddleTokenValue, eventCallback: callback })
  }

  async resumeCheckout() {
    try { await this.initializePaddle() } catch (error) { this.statusTarget.textContent = error.message }
  }

  async subscribe() {
    if (this.providerValue !== "paddle") {
      try {
        const state = await this.api("/vip/status")
        if (state.vip) { location.reload(); return }
        this.command("purchase")
      } catch (error) {
        if (error.name !== "AbortError") this.statusTarget.textContent = error.message
      }
      return
    }
    this.subscribeTarget.disabled = true
    try {
      const data = await this.api("/vip/checkout", {})
      await this.initializePaddle()
      window.Paddle.Checkout.open({ transactionId: data.transaction_id,
        settings: { displayMode: "overlay", allowLogout: false, locale: "en" } })
    } catch (error) {
      if (error.name !== "AbortError") this.statusTarget.textContent = error.message
    } finally {
      if (this.hasSubscribeTarget) this.subscribeTarget.disabled = false
    }
  }

  restore() { this.command("restore") }

  command(action, extra = {}) {
    const body = { action, product_id: this.productValue, base_plan_id: this.basePlanValue,
      account_token: this.accountValue, ...extra }
    if (window.webkit?.messageHandlers?.vipBilling) window.webkit.messageHandlers.vipBilling.postMessage(body)
    else if (window.VipBilling) window.VipBilling.postMessage(JSON.stringify(body))
    else this.statusTarget.textContent = "Update the app to use subscriptions."
  }

  async nativeResult(data) {
    if (!data || data.account_token !== this.accountValue) return
    if (data.type === "price") {
      if (this.hasPriceTarget) this.priceTarget.textContent = data.price + " / month"
      if (this.hasSubscribeTarget) this.subscribeTarget.disabled = false
    } else if (data.type === "purchase") {
      try {
        this.statusTarget.textContent = "Verifying your subscription…"
        const result = await this.api("/vip/verify", { provider: this.providerValue, purchase_reference: data.reference })
        this.command("finish", { reference: data.reference })
        if (result.vip && !this.activeValue) location.reload()
        else if (result.vip) this.statusTarget.textContent = "VIP is active."
        else this.statusTarget.textContent = "No active VIP subscription was found."
      } catch (error) {
        if (error.name !== "AbortError") this.statusTarget.textContent = error.message
      }
    } else this.statusTarget.textContent = data.message || ""
  }

  async waitForVip() {
    this.statusTarget.textContent = "Payment received. Confirming VIP…"
    try {
      for (let i = 0; i < 30; i++) {
        const data = await this.api("/vip/status")
        if (data.vip) { location.href = "/vip"; return }
        await new Promise(resolve => setTimeout(resolve, 2000))
        if (this.abortController.signal.aborted) return
      }
      this.statusTarget.textContent = "Your payment is still being verified. Reopen VIP shortly; do not purchase again."
    } catch (error) {
      if (error.name !== "AbortError") this.statusTarget.textContent = error.message
    }
  }
}
