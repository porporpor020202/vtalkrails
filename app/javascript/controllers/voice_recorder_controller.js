import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "sheet",
    "timer",
    "status",
    "recordButton",
    "stopButton",
    "previewArea",
    "preview",
    "sendButton"
  ]

  static values = {
    endpoint: String,
    maxDuration: { type: Number, default: 30000 }
  }

  connect() {
    this.recordingGeneration = 0
    this.reset()
  }

  disconnect() {
    this.recordingGeneration += 1
    this.releaseMedia()
  }

  open() {
    if (!navigator.mediaDevices?.getUserMedia || !window.MediaRecorder) {
      window.alert("Voice recording is not supported on this device.")
      return
    }

    this.sheetTarget.classList.remove("hidden")
    document.body.classList.add("overflow-hidden")
  }

  close() {
    this.recordingGeneration += 1
    if (this.recorder?.state === "recording") this.recorder.stop()
    this.releaseMedia()
    this.sheetTarget.classList.add("hidden")
    document.body.classList.remove("overflow-hidden")
    this.reset()
  }

  async start() {
    try {
      this.stream = await navigator.mediaDevices.getUserMedia({
        audio: {
          channelCount: 1,
          echoCancellation: true,
          noiseSuppression: true
        }
      })
      this.chunks = []
      const mimeType = this.preferredMimeType()
      const options = mimeType ? { mimeType, audioBitsPerSecond: 64000 } : { audioBitsPerSecond: 64000 }
      this.recorder = new MediaRecorder(this.stream, options)
      const generation = ++this.recordingGeneration
      this.recorder.addEventListener("dataavailable", (event) => {
        if (generation === this.recordingGeneration && event.data.size > 0) this.chunks.push(event.data)
      })
      this.recorder.addEventListener("stop", () => {
        if (generation === this.recordingGeneration) this.finishRecording()
      })
      this.startedAt = performance.now()
      this.recorder.start(500)
      this.recordButtonTarget.classList.add("hidden")
      this.stopButtonTarget.classList.remove("hidden")
      this.stopButtonTarget.classList.add("flex")
      this.statusTarget.textContent = "Recording… tap stop when you are done."
      this.tick()
      this.timerInterval = window.setInterval(() => this.tick(), 100)
    } catch (error) {
      this.statusTarget.textContent = error.name === "NotAllowedError"
        ? "Microphone access is required to record."
        : "The microphone could not be started."
      this.releaseStream()
    }
  }

  stop() {
    if (this.recorder?.state === "recording") this.recorder.stop()
  }

  discard() {
    this.recordingGeneration += 1
    this.revokePreviewURL()
    this.reset()
  }

  async send() {
    if (!this.audioBlob) return

    this.sendButtonTarget.disabled = true
    this.sendButtonTarget.textContent = "Sending…"
    this.statusTarget.textContent = "Finding an active listener…"

    const formData = new FormData()
    formData.append("voice_message[audio]", this.audioBlob, `voice-message.${this.fileExtension(this.audioBlob.type)}`)
    formData.append("voice_message[duration_ms]", String(this.durationMs))

    try {
      const response = await fetch(this.endpointValue, {
        method: "POST",
        headers: {
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || ""
        },
        body: formData,
        credentials: "same-origin"
      })
      const payload = await response.json()
      if (!response.ok) throw new Error(payload.error || "Unable to send this voice message.")

      this.releaseMedia()
      window.Turbo.visit(payload.redirect_url)
    } catch (error) {
      this.statusTarget.textContent = error.message
      this.sendButtonTarget.disabled = false
      this.sendButtonTarget.textContent = "Try again"
    }
  }

  tick() {
    const elapsed = Math.min(performance.now() - this.startedAt, this.maxDurationValue)
    this.durationMs = Math.max(1, Math.round(elapsed))
    const seconds = Math.floor(elapsed / 1000)
    this.timerTarget.textContent = `00:${String(seconds).padStart(2, "0")}`
    if (elapsed >= this.maxDurationValue) this.stop()
  }

  finishRecording() {
    window.clearInterval(this.timerInterval)
    this.tick()
    const type = this.recorder?.mimeType || this.chunks[0]?.type || "audio/webm"
    this.audioBlob = new Blob(this.chunks, { type })
    this.releaseStream()

    if (this.audioBlob.size === 0) {
      this.statusTarget.textContent = "No audio was recorded. Please try again."
      this.resetControls()
      return
    }

    this.previewURL = URL.createObjectURL(this.audioBlob)
    this.previewTarget.src = this.previewURL
    this.previewAreaTarget.classList.remove("hidden")
    this.stopButtonTarget.classList.add("hidden")
    this.stopButtonTarget.classList.remove("flex")
    this.statusTarget.textContent = "Listen once, then send it."
  }

  preferredMimeType() {
    return [
      "audio/mp4",
      "audio/webm;codecs=opus",
      "audio/webm",
      "audio/ogg;codecs=opus"
    ].find((type) => MediaRecorder.isTypeSupported(type))
  }

  fileExtension(type) {
    if (type.includes("mp4")) return "m4a"
    if (type.includes("ogg")) return "ogg"
    return "webm"
  }

  releaseMedia() {
    window.clearInterval(this.timerInterval)
    this.releaseStream()
    this.revokePreviewURL()
  }

  releaseStream() {
    this.stream?.getTracks().forEach((track) => track.stop())
    this.stream = null
  }

  revokePreviewURL() {
    if (this.previewURL) URL.revokeObjectURL(this.previewURL)
    this.previewURL = null
  }

  reset() {
    this.chunks = []
    this.audioBlob = null
    this.durationMs = 0
    this.recorder = null
    this.timerTarget.textContent = "00:00"
    this.statusTarget.textContent = "Tap record when you are ready."
    this.previewTarget.removeAttribute("src")
    this.previewAreaTarget.classList.add("hidden")
    this.sendButtonTarget.disabled = false
    this.sendButtonTarget.textContent = "Send voice"
    this.resetControls()
  }

  resetControls() {
    this.recordButtonTarget.classList.remove("hidden")
    this.stopButtonTarget.classList.add("hidden")
    this.stopButtonTarget.classList.remove("flex")
  }
}
