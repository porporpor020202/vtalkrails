import { Controller } from "@hotwired/stimulus"
import { translate } from "helpers/translations"
import { nativeShare, nativeShareAvailable } from "helpers/native_share"
import { renderPracticeShareCard } from "helpers/practice_share_card"

export default class extends Controller {
  static targets = ["button", "status", "dialog", "cardImage", "loading", "sendButton", "download", "cardStatus"]
  static values = { endpoint: String, token: String, text: String, card: Object }

  connect() {
    if (this.hasDialogTarget) this.prepareCard().catch(() => {})
  }

  disconnect() {
    if (this.hasDialogTarget && this.dialogTarget.open) this.dialogTarget.close()
    if (this.previewURL) URL.revokeObjectURL(this.previewURL)
    this.previewURL = null
    this.preparation = null
    this.card = null
    this.file = null
  }

  async prepareCard() {
    if (!this.preparation) {
      this.preparation = renderPracticeShareCard(this.cardValue).then(card => {
        if (!this.element.isConnected) return
        this.card = card
        this.file = new File([card.blob], `say-one-thing-${this.cardValue.locale}.png`, { type: "image/png" })
        this.previewURL = URL.createObjectURL(card.blob)
        this.cardImageTarget.src = this.previewURL
        this.cardImageTarget.hidden = false
        this.downloadTarget.href = this.previewURL
        this.downloadTarget.download = this.file.name
        this.loadingTarget.hidden = true
        this.configureSharing()
        this.sendButtonTarget.disabled = false
      }).catch(error => { this.preparation = null; throw error })
    }
    return this.preparation
  }

  async open() {
    if (this.busy) return
    if (!this.dialogTarget.open) this.dialogTarget.showModal()
    try { await this.prepareCard(); if (this.element.isConnected) this.configureSharing() }
    catch { if (this.element.isConnected) this.loadingTarget.textContent = translate("card_error") }
  }

  configureSharing() {
    this.imageSharing = nativeShareAvailable() || !!(navigator.share && navigator.canShare?.({ files: [this.file] }))
    this.sendButtonTarget.textContent = translate(this.imageSharing ? "card_share" : "card_download")
    this.downloadTarget.hidden = nativeShareAvailable() || !this.imageSharing
    this.cardStatusTarget.textContent = this.imageSharing ? "" : translate("card_save_hint")
  }

  close() { if (!this.busy) this.dialogTarget.close() }
  cancelPreview(event) { event.preventDefault(); this.close() }
  dismissBackdrop(event) {
    if (event.target !== this.dialogTarget) return
    const box = this.dialogTarget.getBoundingClientRect()
    if (event.clientX < box.left || event.clientX > box.right || event.clientY < box.top || event.clientY > box.bottom) this.close()
  }

  async share() {
    if (this.busy || !this.card) return
    if (!this.imageSharing) {
      this.downloadTarget.click()
      this.cardStatusTarget.textContent = translate("card_saved")
      return
    }
    this.busy = true
    this.sendButtonTarget.disabled = true
    this.cardStatusTarget.textContent = ""
    try {
      // Both the File and native PNG are ready before this tap: keep OS user activation.
      const data = { title: `${this.cardValue.headline.replaceAll("\n", " ")} · Say One Thing`, text: this.textValue, url: "https://sayonething.net", imageDataUrl: this.card.dataURL }
      const native = nativeShare(data)
      if (native) await native
      else await navigator.share({ title: data.title, text: `${data.text}\n${data.url}`, files: [this.file] })
      if (!this.element.isConnected) return
      this.dialogTarget.close()
      this.statusTarget.textContent = translate("bonus_opening")
      const response = await fetch(this.endpointValue, {
        method: "POST", credentials: "same-origin",
        headers: { Accept: "application/json", "Content-Type": "application/json", "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || "" },
        body: JSON.stringify({ practice_token: this.tokenValue })
      })
      if (response.redirected) { window.Turbo.visit(response.url); return }
      const result = await response.json()
      if (!response.ok) {
        if (result.redirect_url) { window.Turbo.visit(result.redirect_url); return }
        throw new Error(result.error || translate("share_error"))
      }
      window.Turbo.visit(result.redirect_url)
    } catch (error) {
      if (this.element.isConnected && error.name !== "AbortError") {
        if (!this.dialogTarget.open) this.dialogTarget.showModal()
        this.cardStatusTarget.textContent = translate("share_error")
      }
    } finally {
      this.busy = false
      if (this.hasSendButtonTarget) this.sendButtonTarget.disabled = false
    }
  }
}
