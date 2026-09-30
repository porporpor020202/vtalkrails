import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["draft", "status", "output"]
  static values = { endpoint: String, source: Number }

  connect() {
    this.abortController = new AbortController()
    this.busy = false
  }

  disconnect() {
    this.abortController.abort()
  }

  interpret() { this.run("interpretation") }
  suggest() { this.run("suggestions") }
  translate() {
    const draft = this.draftTarget.value.trim()
    if (!draft) {
      this.statusTarget.textContent = "Write something in your native language first."
      return
    }
    this.run("translation", { draft })
  }

  async request(url, options = {}) {
    const response = await fetch(url, {
      credentials: "same-origin",
      signal: this.abortController.signal,
      ...options,
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || "",
        ...options.headers
      }
    })
    if (!response.ok) {
      const data = await response.json().catch(() => ({}))
      throw new Error(data.error || (response.status === 409 ?
        "The conversation has moved on. Reopen it to continue." : "AI help is unavailable. Please try again."))
    }
    return response.json()
  }

  async generate(kind, values = {}) {
    let data = await this.request(this.endpointValue, {
      method: "POST",
      body: JSON.stringify({ kind, source_message_id: this.sourceValue, ...values })
    })
    const deadline = Date.now() + 180000
    while (["pending", "processing"].includes(data.status)) {
      if (Date.now() > deadline) throw new Error("Still processing. Try again shortly to retrieve the result.")
      await new Promise(resolve => setTimeout(resolve, 1500))
      if (this.abortController.signal.aborted) throw new DOMException("Aborted", "AbortError")
      data = await this.request(data.url)
    }
    if (data.status !== "completed") throw new Error("AI could not complete this request. Please try again.")
    return data
  }

  async run(kind, values = {}) {
    if (this.busy) return
    this.busy = true
    this.statusTarget.textContent = "Preparing AI help… You can still record your reply."
    try {
      const data = await this.generate(kind, values)
      this.outputTarget.replaceChildren()
      if (kind === "interpretation") {
        this.paragraph(this.outputTarget, data.result.transcript, true)
        this.paragraph(this.outputTarget, data.result.meaning)
      } else if (kind === "suggestions") {
        data.result.replies.forEach((reply, index) => {
          const card = this.card()
          this.paragraph(card, reply.english, true)
          this.paragraph(card, reply.meaning)
          this.listenButton(card, data.id, index)
        })
      } else {
        const card = this.card()
        this.paragraph(card, data.result.english, true)
        this.paragraph(card, data.result.ipa)
        this.paragraph(card, data.result.pronunciation_guide)
        this.listenButton(card, data.id)
      }
      this.statusTarget.textContent = ""
    } catch (error) {
      if (error.name !== "AbortError") this.statusTarget.textContent = error.message
    } finally {
      this.busy = false
    }
  }

  card() {
    const card = document.createElement("div")
    card.className = "space-y-2 rounded-xl bg-white p-3 text-sm text-slate-700"
    this.outputTarget.append(card)
    return card
  }

  paragraph(container, text, bold = false) {
    const element = document.createElement("p")
    element.textContent = text
    if (bold) element.className = "font-semibold text-slate-950"
    container.append(element)
  }

  listenButton(container, parentId, index) {
    const button = document.createElement("button")
    button.type = "button"
    button.className = "text-xs font-bold text-indigo-600"
    button.textContent = "Listen · AI voice"
    button.addEventListener("click", async () => {
      button.disabled = true
      button.textContent = "Preparing pronunciation…"
      try {
        const data = await this.generate("pronunciation", { parent_id: parentId, reply_index: index })
        const audio = document.createElement("audio")
        audio.controls = true
        audio.preload = "none"
        audio.src = data.audio_url
        audio.className = "w-full"
        audio.setAttribute("aria-label", "AI-generated pronunciation")
        button.replaceWith(audio)
      } catch (error) {
        if (error.name !== "AbortError") {
          button.textContent = "Retry pronunciation"
          this.statusTarget.textContent = error.message
          button.disabled = false
        }
      }
    })
    container.append(button)
  }
}
