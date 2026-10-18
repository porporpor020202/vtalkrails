import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["recorder", "recorderHome", "status", "recordButton", "micIcon", "stopIcon", "timer", "previewArea", "preview", "submitButton", "discardButton"]
  static values = { endpoint: String, token: String }

  connect() { this.generation = 0; this.sending = false }
  disconnect() { this.cleanup() }

  openHelp(event) {
    event.detail.slot.append(this.recorderTarget)
  }

  closeHelp() {
    if (this.recorder?.state === "recording") this.stop()
    else if (this.recordButtonTarget.disabled && !this.sending) {
      ++this.generation
      this.resetControls()
      this.statusTarget.textContent = ""
    }
    this.recorderHomeTarget.append(this.recorderTarget)
  }

  async toggleRecording() {
    if (this.recorder?.state === "recording") { this.stop(); return }
    if (!navigator.mediaDevices?.getUserMedia || !window.MediaRecorder) { this.showError("이 기기에서는 녹음을 지원하지 않아요. 최신 브라우저에서 열어주세요."); return }
    const generation = ++this.generation
    this.recordButtonTarget.disabled = true
    this.statusTarget.textContent = "마이크를 준비하고 있어요…"
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
      this.recorder.onerror = () => { this.cleanup(); if (this.element.isConnected) { this.resetControls(); this.showError("녹음이 중단됐어요. 다시 시도해주세요.") } }
      this.startedAt = performance.now()
      this.recorder.start(250)
      this.recordButtonTarget.disabled = false
      this.recordButtonTarget.classList.add("is-recording")
      this.recordButtonTarget.setAttribute("aria-label", "녹음 끝내기")
      this.micIconTarget.setAttribute("hidden", "")
      this.stopIconTarget.hidden = false
      this.timerTarget.hidden = false
      this.statusTarget.textContent = "녹음 중"
      this.interval = window.setInterval(() => this.tick(), 100)
    } catch (error) {
      if (generation !== this.generation) return
      this.releaseStream()
      this.recordButtonTarget.disabled = false
      this.showError(error.name === "NotAllowedError" ? "마이크 권한이 필요해요. 브라우저나 기기 설정에서 허용한 뒤 다시 눌러주세요." : "마이크를 켜지 못했어요. 연결을 확인하고 다시 시도해주세요.")
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
    if (!this.blob.size || this.durationMs < 1000) { this.blob = null; this.showError("한 문장을 1초 이상 녹음해주세요."); return }
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
    this.statusTarget.textContent = "전송 중…"
    const form = new FormData()
    const extension = this.blob.type.includes("mp4") ? "m4a" : this.blob.type.includes("ogg") ? "ogg" : "webm"
    form.append("question_token", this.tokenValue)
    form.append("daily_practice[audio]", this.blob, `daily-practice.${extension}`)
    form.append("daily_practice[duration_ms]", String(this.durationMs))
    try {
      const response = await fetch(this.endpointValue, { method: "POST", headers: { Accept: "application/json", "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || "" }, body: form, credentials: "same-origin" })
      if (response.redirected) { window.Turbo.visit(response.url); return }
      const payload = await response.json()
      if (response.status === 409 && payload.redirect_url) { window.Turbo.visit(payload.redirect_url); return }
      if (!response.ok) throw new Error(payload.error || "저장하지 못했어요. 다시 시도해주세요.")
      window.Turbo.visit(payload.redirect_url)
    } catch (error) {
      if (!this.element.isConnected) return
      this.showError(error.message || "연결을 확인하고 다시 시도해주세요.")
      this.sending = false
      this.submitButtonTarget.disabled = false
      this.discardButtonTarget.disabled = false
    }
  }

  showError(message) { this.statusTarget.setAttribute("role", "alert"); this.statusTarget.textContent = message }
  releaseStream() { this.stream?.getTracks().forEach(track => track.stop()); this.stream = null }
  revokePreview() { if (this.hasPreviewTarget) { this.previewTarget.pause(); this.previewTarget.removeAttribute("src") }; if (this.previewURL) URL.revokeObjectURL(this.previewURL); this.previewURL = null }
  resetControls() {
    this.recordButtonTarget.disabled = false
    this.recordButtonTarget.hidden = false
    this.recordButtonTarget.classList.remove("is-recording")
    this.recordButtonTarget.setAttribute("aria-label", "녹음 시작")
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
