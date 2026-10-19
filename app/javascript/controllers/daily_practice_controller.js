import { translate } from "helpers/translations"
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["hint", "translationPrompt", "status", "recordButton", "micIcon", "stopIcon", "timer", "previewArea", "preview", "submitButton", "discardButton"]
  static values = { endpoint: String, token: String }

  connect() { this.generation = 0; this.sending = false; this.syncTranslationGate() }
  disconnect() { this.cleanup() }

  syncTranslationGate() {
    this.translationReady = !!this.element.querySelector(".english-answer")?.textContent.trim()
    if (!this.hasRecordButtonTarget) return
    const recording = this.recorder?.state === "recording"
    this.recordButtonTarget.disabled = !this.translationReady && !recording
    this.recordButtonTarget.hidden = !!this.blob || (!this.translationReady && !recording)
    if (this.hasTranslationPromptTarget) this.translationPromptTarget.hidden = this.translationReady || recording || !!this.blob
    if (this.hasHintTarget) this.hintTarget.hidden = !this.translationReady || !!this.startedAt
  }

  async toggleRecording() {
    if (this.recorder?.state === "recording") { this.stop(); return }
    if (!this.translationReady) { this.syncTranslationGate(); if (!this.translationReady) return }
    if (!navigator.mediaDevices?.getUserMedia || !window.MediaRecorder) { this.showError(translate("unsupported")); return }
    const generation = ++this.generation
    this.recordButtonTarget.disabled = true
    this.statusTarget.textContent = translate("preparing")
    this.statusTarget.setAttribute("role", "status")
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true })
      if (!this.element.isConnected || generation !== this.generation) { stream.getTracks().forEach(track => track.stop()); return }
      this.stream = stream
      this.chunks = []
      const mimeType = ["audio/mp4", "audio/webm;codecs=opus", "audio/webm", "audio/ogg;codecs=opus"].find(type => MediaRecorder.isTypeSupported(type))
      this.recorder = new MediaRecorder(stream, mimeType ? { mimeType } : {})
      this.recorder.ondataavailable = event => { if (generation === this.generation && event.data.size) this.chunks.push(event.data) }
      this.recorder.onstop = () => { if (generation === this.generation && this.element.isConnected) this.finish() }
      this.recorder.onerror = () => { this.cleanup(); if (this.element.isConnected) { this.resetControls(); this.showError(translate("interrupted")) } }
      this.startedAt = performance.now()
      this.recorder.start(250)
      if (this.hasHintTarget) this.hintTarget.hidden = true
      this.recordButtonTarget.disabled = false
      this.recordButtonTarget.classList.add("is-recording")
      this.recordButtonTarget.setAttribute("aria-label", translate("record_stop"))
      this.micIconTarget.setAttribute("hidden", "")
      this.stopIconTarget.hidden = false
      this.timerTarget.hidden = false
      this.statusTarget.textContent = translate("recording")
      this.interval = window.setInterval(() => this.tick(), 100)
    } catch (error) {
      if (generation !== this.generation) return
      this.releaseStream()
      this.recordButtonTarget.disabled = false
      this.showError(error.name === "NotAllowedError" ? translate("permission") : translate("mic_error"))
    }
  }

  tick() {
    this.durationMs = Math.min(60000, Math.round(performance.now() - this.startedAt))
    const seconds = Math.floor(this.durationMs / 1000)
    this.timerTarget.textContent = `${String(Math.floor(seconds / 60)).padStart(2, "0")}:${String(seconds % 60).padStart(2, "0")}`
    if (this.durationMs >= 60000) this.stop()
  }

  stop() {
    if (this.recorder?.state !== "recording") return
    this.durationMs = Math.min(60000, Math.round(performance.now() - this.startedAt))
    window.clearInterval(this.interval)
    this.recorder.stop()
  }

  finish() {
    window.clearInterval(this.interval)
    const type = this.recorder.mimeType || this.chunks[0]?.type || "audio/webm"
    this.blob = new Blob(this.chunks, { type })
    this.releaseStream()
    this.resetControls()
    if (!this.blob.size || this.durationMs < 1000) { this.blob = null; this.showError(translate("too_short")); return }
    this.previewURL = URL.createObjectURL(this.blob)
    this.previewTarget.dataset.durationMs = String(this.durationMs)
    this.previewTarget.src = this.previewURL
    this.previewAreaTarget.hidden = false
    this.recordButtonTarget.hidden = true
    this.timerTarget.hidden = true
    this.statusTarget.textContent = ""
  }

  discard() {
    if (this.sending) return
    this.revokePreview()
    this.blob = null
    this.previewAreaTarget.hidden = true
    this.resetControls()
    this.statusTarget.textContent = ""
  }

  async submit() {
    if (!this.blob || this.sending) return
    this.sending = true
    this.submitButtonTarget.disabled = true
    this.discardButtonTarget.disabled = true
    this.statusTarget.textContent = translate("sending")
    const form = new FormData()
    const extension = this.blob.type.includes("mp4") ? "m4a" : this.blob.type.includes("ogg") ? "ogg" : "webm"
    form.append("question_token", this.tokenValue)
    form.append("daily_practice[audio]", this.blob, `daily-practice.${extension}`)
    form.append("daily_practice[duration_ms]", String(this.durationMs))
    try {
      const response = await fetch(this.endpointValue, { method: "POST", headers: { Accept: "application/json", "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || "" }, body: form, credentials: "same-origin" })
      if (response.redirected) { window.Turbo.visit(response.url); return }
      const payload = await response.json()
      if ([401, 402, 409].includes(response.status) && payload.redirect_url) { window.Turbo.visit(payload.redirect_url); return }
      if (!response.ok) throw new Error(payload.error || translate("save_error"))
      window.Turbo.visit(payload.redirect_url)
    } catch (error) {
      if (!this.element.isConnected) return
      this.showError(error instanceof TypeError ? translate("connection") : error.message || translate("connection"))
      this.sending = false
      this.submitButtonTarget.disabled = false
      this.discardButtonTarget.disabled = false
    }
  }

  showError(message) { this.statusTarget.setAttribute("role", "alert"); this.statusTarget.textContent = message }
  releaseStream() { this.stream?.getTracks().forEach(track => track.stop()); this.stream = null }
  revokePreview() { if (this.hasPreviewTarget) { this.previewTarget.pause(); this.previewTarget.removeAttribute("src") }; if (this.previewURL) URL.revokeObjectURL(this.previewURL); this.previewURL = null }
  resetControls() {
    this.recordButtonTarget.disabled = !this.translationReady
    this.recordButtonTarget.hidden = !this.translationReady
    this.recordButtonTarget.classList.remove("is-recording")
    this.recordButtonTarget.setAttribute("aria-label", translate("record_start"))
    this.micIconTarget.removeAttribute("hidden")
    this.stopIconTarget.hidden = true
    this.timerTarget.hidden = true
    this.timerTarget.textContent = "00:00"
  }
  cleanup() {
    ++this.generation
    window.clearInterval(this.interval)
    if (this.recorder?.state === "recording") this.recorder.stop()
    this.releaseStream()
    this.revokePreview()
  }
}
