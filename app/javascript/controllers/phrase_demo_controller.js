import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["prompt", "result", "instructions", "microphone", "status", "english", "listen", "playbackStatus", "playback"]
  static values = { endpoint: String, speechEndpoint: String }

  connect() {
    this.generation = 0
    this.busy = false
  }

  disconnect() {
    this.cancel()
    if (this.hasInstructionsTarget) this.instructionsTarget.close()
  }

  openInstructions() {
    this.instructionsTarget.showModal()
  }

  closeInstructions() {
    this.instructionsTarget.close()
  }

  closeInstructionsOnBackdrop(event) {
    if (event.target !== this.instructionsTarget) return

    const bounds = this.instructionsTarget.getBoundingClientRect()
    if (event.clientX < bounds.left || event.clientX > bounds.right ||
        event.clientY < bounds.top || event.clientY > bounds.bottom) {
      this.closeInstructions()
    }
  }

  open() {
    this.cancel()
    this.promptTarget.classList.remove("hidden")
    this.resultTarget.classList.add("hidden")
    this.englishTarget.textContent = ""
  }

  toggleRecording() {
    if (this.recorder?.state === "recording") {
      this.stopRecording()
    } else if (!this.busy) {
      this.startRecording()
    }
  }

  async listen() {
    if (this.speechRequest || (this.audioUrl && !this.playbackTarget.paused)) {
      this.stopSpeaking()
      return
    }
    if (this.audioUrl) {
      this.playbackTarget.currentTime = 0
      this.playAudio()
      return
    }
    if (!this.speechToken) return

    const generation = this.generation
    const request = new AbortController()
    this.speechRequest = request
    this.listenTarget.textContent = "■ Cancel"
    this.playbackStatusTarget.textContent = "Preparing audio…"
    const timeout = window.setTimeout(() => request.abort(), 60000)
    try {
      const response = await fetch(this.speechEndpointValue, {
        method: "POST", credentials: "same-origin", signal: request.signal,
        headers: { "Content-Type": "application/json", "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || "" },
        body: JSON.stringify({ speech_token: this.speechToken })
      })
      if (!response.ok) {
        const payload = await response.json().catch(() => ({}))
        throw new Error(payload.error || "Read aloud is unavailable. Please try again.")
      }
      const audio = await response.blob()
      if (generation !== this.generation || request.signal.aborted) return
      this.audioUrl = URL.createObjectURL(audio)
      this.playbackTarget.src = this.audioUrl
      this.playbackTarget.classList.remove("hidden")
      this.playbackStatusTarget.textContent = ""
      this.speechRequest = null
      this.playAudio()
    } catch (error) {
      if (generation === this.generation && this.speechRequest === request) {
        this.playbackStatusTarget.textContent = error.name === "AbortError"
          ? "Audio generation was cancelled. Tap Listen to try again."
          : error.message
      }
    } finally {
      window.clearTimeout(timeout)
      if (this.speechRequest === request) {
        this.speechRequest = null
        this.resetListen()
      }
    }
  }

  playAudio() {
    const generation = this.generation
    const audioUrl = this.audioUrl
    this.playbackTarget.play().then(() => {
      if (generation !== this.generation || audioUrl !== this.audioUrl || this.playbackTarget.paused) return
      this.listenTarget.textContent = "■ Stop"
      this.listenTarget.setAttribute("aria-label", "Stop reading aloud")
    }).catch(error => {
      if (generation !== this.generation || audioUrl !== this.audioUrl) return
      this.resetListen()
      this.playbackStatusTarget.textContent = error.name === "NotAllowedError"
        ? "Audio is ready. Tap Listen or the player to play."
        : "Could not play the audio. Please try again."
    })
  }

  playbackStarted() {
    this.listenTarget.textContent = "■ Stop"
    this.listenTarget.setAttribute("aria-label", "Stop reading aloud")
    this.playbackStatusTarget.textContent = ""
  }

  playbackFailed() {
    this.resetListen()
    this.playbackStatusTarget.textContent = "Could not play the audio. Please try again."
  }

  resetListen() {
    if (this.hasListenTarget) {
      this.listenTarget.textContent = "▶ Listen"
      this.listenTarget.setAttribute("aria-label", "Read English aloud")
    }
  }

  stopSpeaking() {
    this.speechRequest?.abort()
    this.speechRequest = null
    if (this.hasPlaybackTarget) this.playbackTarget.pause()
    this.resetListen()
    if (this.hasPlaybackStatusTarget) this.playbackStatusTarget.textContent = ""
  }

  async startRecording() {
    if (!navigator.mediaDevices?.getUserMedia || !window.MediaRecorder) {
      this.showError("Voice recording is not supported on this device.")
      return
    }

    const generation = ++this.generation
    this.busy = true
    this.microphoneTarget.disabled = true
    this.statusTarget.textContent = "Opening microphone…"

    try {
      // Stop a regular voice recording before taking over the microphone.
      this.dispatch("recording")
      const stream = await navigator.mediaDevices.getUserMedia({
        audio: { channelCount: 1, echoCancellation: true, noiseSuppression: true }
      })
      if (generation !== this.generation) {
        stream.getTracks().forEach(track => track.stop())
        return
      }
      this.stream = stream
      const mimeType = ["audio/mp4", "audio/webm;codecs=opus", "audio/webm", "audio/ogg;codecs=opus"]
        .find(type => MediaRecorder.isTypeSupported(type))
      this.recorder = new MediaRecorder(stream, mimeType ? { mimeType, audioBitsPerSecond: 64000 } : {})
      const chunks = []
      const recorder = this.recorder
      recorder.addEventListener("dataavailable", event => {
        if (event.data.size > 0) chunks.push(event.data)
      })
      recorder.addEventListener("stop", () => {
        if (generation !== this.generation) return
        const durationMs = Math.min(30000, Math.max(1, Math.round(performance.now() - this.startedAt)))
        const audio = new Blob(chunks, { type: recorder.mimeType || chunks[0]?.type || "audio/webm" })
        this.releaseStream()
        this.translate(audio, durationMs, generation)
      })
      recorder.addEventListener("error", () => {
        if (generation !== this.generation) return
        this.cancel()
        this.showError("The recording was interrupted. Please try again.")
      })
      this.startedAt = performance.now()
      recorder.start(250)
      this.microphoneTarget.disabled = false
      this.microphoneTarget.setAttribute("aria-label", "Stop and translate")
      this.microphoneTarget.textContent = "■"
      this.statusTarget.setAttribute("role", "status")
      this.statusTarget.textContent = "Listening… Tap again to translate."
      this.stopTimer = window.setTimeout(() => this.stopRecording(), 30000)
    } catch (error) {
      if (generation !== this.generation) return
      this.cancel()
      this.showError(error.name === "NotAllowedError"
        ? "Allow microphone access in your browser or device settings, then try again."
        : "The microphone could not be started. Please try again.")
    }
  }

  stopRecording() {
    window.clearTimeout(this.stopTimer)
    if (this.recorder?.state === "recording") {
      this.microphoneTarget.disabled = true
      this.recorder.stop()
    }
  }

  async translate(audio, durationMs, generation) {
    this.microphoneTarget.disabled = true
    this.microphoneTarget.textContent = "🎙"
    this.statusTarget.textContent = "Finding your English words…"
    if (!audio.size) {
      this.busy = false
      this.resetMicrophone()
      this.showError("No audio was recorded. Please try again.")
      return
    }

    const extension = audio.type.includes("mp4") ? "m4a" : audio.type.includes("ogg") ? "ogg" : "webm"
    const body = new FormData()
    body.append("audio", audio, `voice-helper.${extension}`)
    body.append("duration_ms", String(durationMs))
    const abortController = new AbortController()
    this.abortController = abortController
    const timeout = window.setTimeout(() => abortController.abort(), 100000)

    try {
      const response = await fetch(this.endpointValue, {
        method: "POST", body, credentials: "same-origin", signal: abortController.signal,
        headers: { Accept: "application/json", "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || "" }
      })
      const payload = await response.json().catch(() => ({}))
      if (generation !== this.generation) return
      if (!response.ok) throw new Error(payload.error || "Voice helper is unavailable. Please try again.")
      if (typeof payload.english !== "string" || !payload.english.trim()) {
        throw new Error("We could not understand your voice. Please record again.")
      }
      this.speechToken = payload.speech_token
      this.englishTarget.textContent = payload.english
      this.promptTarget.classList.add("hidden")
      this.resultTarget.classList.remove("hidden")
    } catch (error) {
      if (generation === this.generation) {
        this.showError(error.name === "AbortError"
          ? "This is taking too long. Please try again."
          : error.message)
      }
    } finally {
      window.clearTimeout(timeout)
      if (generation === this.generation) {
        this.busy = false
        this.resetMicrophone()
      }
    }
  }

  cancel() {
    this.stopSpeaking()
    this.speechToken = null
    if (this.audioUrl) URL.revokeObjectURL(this.audioUrl)
    this.audioUrl = null
    if (this.hasPlaybackTarget) {
      this.playbackTarget.removeAttribute("src")
      this.playbackTarget.load()
      this.playbackTarget.classList.add("hidden")
    }
    this.generation += 1
    window.clearTimeout(this.stopTimer)
    this.abortController?.abort()
    if (this.recorder?.state === "recording") this.recorder.stop()
    this.releaseStream()
    this.recorder = null
    this.busy = false
    if (this.hasMicrophoneTarget) this.resetMicrophone()
    if (this.hasStatusTarget) {
      this.statusTarget.setAttribute("role", "status")
      this.statusTarget.textContent = "Tap the mic to start. Tap again to translate."
    }
    if (this.hasInstructionsTarget) this.instructionsTarget.close()
  }

  releaseStream() {
    this.stream?.getTracks().forEach(track => track.stop())
    this.stream = null
  }

  resetMicrophone() {
    this.microphoneTarget.disabled = false
    this.microphoneTarget.textContent = "🎙"
    this.microphoneTarget.setAttribute("aria-label", "Start voice helper")
  }

  showError(message) {
    this.statusTarget.setAttribute("role", "alert")
    this.statusTarget.textContent = message
  }
}
