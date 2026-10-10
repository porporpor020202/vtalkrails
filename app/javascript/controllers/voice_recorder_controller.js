import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "sheet",
    "timer",
    "recordingMessage",
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

  openSheet() {
    if (!navigator.mediaDevices?.getUserMedia || !window.MediaRecorder) {
      window.alert("Voice recording is not supported on this device.")
      return
    }

    this.sheetTarget.classList.remove("hidden")
  }

  closeSheet() {
    this.dispatch("closed")
    this.recordingGeneration += 1
    if (this.recorder?.state === "recording") this.recorder.stop()
    this.releaseMedia()
    this.sheetTarget.classList.add("hidden")
    document.body.classList.remove("overflow-hidden")
    this.reset()
  }

  async startRecording() {
    this.dispatch("recording")
    const generation = ++this.recordingGeneration
    this.recordingMessageTarget.removeAttribute("role")
    this.recordingMessageTarget.textContent = "Recording…"
    this.recordingMessageTarget.classList.add("hidden")
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        audio: {
          channelCount: 1,
          echoCancellation: false,
          noiseSuppression: false,
          autoGainControl: false
        }
      })
      if (generation !== this.recordingGeneration) {
        stream.getTracks().forEach(track => track.stop())
        return
      }
      this.stream = stream
      this.chunks = []
      const mimeType = this.preferredMimeType()
      const options = mimeType ? { mimeType, audioBitsPerSecond: 64000 } : { audioBitsPerSecond: 64000 }
      this.recorder = new MediaRecorder(this.stream, options)
      this.recorder.addEventListener("dataavailable", (event) => {
        if (generation === this.recordingGeneration && event.data.size > 0) this.chunks.push(event.data)
      })
      this.recorder.addEventListener("stop", () => {
        if (generation === this.recordingGeneration) this.finishRecording()
      })
      this.startedAt = performance.now()
      this.recorder.start(500)

      this.recordButtonTarget.classList.add("hidden")
      this.stopButtonTarget.classList.add("flex")
      this.stopButtonTarget.classList.remove("hidden")

      this.recordingMessageTarget.classList.remove("hidden")

      this.tick()
      this.timerInterval = window.setInterval(() => this.tick(), 100)

    } catch (error) {
      if (generation !== this.recordingGeneration) return
      this.recordingMessageTarget.textContent = error.name === "NotAllowedError"
        ? "Allow microphone access in your browser or device settings, then try again."
        : "The microphone could not be started."
      this.recordingMessageTarget.setAttribute("role", "alert")
      this.recordingMessageTarget.classList.remove("hidden")
      this.releaseStream()
    }
  }

  stopRecording() {
    if (this.recorder?.state === "recording") this.recorder.stop()
  }

  stopForHelper() {
    if (this.recorder?.state === "recording") {
      this.stopRecording()
    } else {
      // Invalidate microphone permission requests that are still pending.
      this.recordingGeneration += 1
    }
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
    this.recordingMessageTarget.textContent = "Sending your voice…"

    const formData = new FormData()
    formData.append("request_key", this.requestKey)
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
      if (response.status === 403 && payload.redirect_url) {
        window.Turbo.visit(payload.redirect_url)
        return
      }
      if (!response.ok) throw new Error(payload.error || "Unable to send this voice message.")

      this.releaseMedia()
      window.Turbo.visit(payload.redirect_url)
    } catch (error) {
      this.recordingMessageTarget.textContent = error.message
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
    this.requestKey = crypto.randomUUID()
    this.releaseStream()

    if (this.audioBlob.size === 0) {
      this.recordingMessageTarget.textContent = "No audio was recorded. Please try again."
      this.resetControls()
      return
    }

    this.previewURL = URL.createObjectURL(this.audioBlob)
    this.previewTarget.src = this.previewURL
    this.previewAreaTarget.classList.remove("hidden")
    this.stopButtonTarget.classList.add("hidden")
    this.stopButtonTarget.classList.remove("flex")
    this.recordingMessageTarget.classList.add("hidden")
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
    this.requestKey = null
    this.durationMs = 0
    this.recorder = null
    this.recordingMessageTarget.removeAttribute("role")
    this.recordingMessageTarget.classList.add("hidden")
    this.recordingMessageTarget.textContent = "Recording…"
    this.timerTarget.textContent = "00:00"
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
