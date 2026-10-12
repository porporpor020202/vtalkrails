import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["step", "progress", "progressFill", "stepCount", "native", "age", "gender", "microphoneConfirmed", "microphoneStatus", "microphoneButton", "rules", "continue", "languageOption", "noResults", "ageError", "signOut", "form"]

  connect() {
    this.currentStep = 0
    this.microphoneConfirmedTarget.value = "0"
    this.rulesTarget.value = "0"
    this.showStep()
    if (navigator.permissions) {
      navigator.permissions.query({ name: "microphone" }).then(permission => {
        if (!this.element.isConnected) return
        this.permission = permission
        this.permissionChanged = () => {
          if (permission.state !== "granted") {
            this.microphoneConfirmedTarget.value = "0"
            this.microphoneStatusTarget.textContent = "Microphone access was not allowed. Enable it in your browser or device settings, then try again."
            if (this.currentStep > 3) { this.currentStep = 3; this.showStep() }
          }
        }
        permission.addEventListener("change", this.permissionChanged)
      }).catch(() => {})
    }
  }

  disconnect() { this.permission?.removeEventListener("change", this.permissionChanged) }

  back() {
    if (this.currentStep === 0) { this.signOutTarget.requestSubmit(); return }
    this.currentStep -= 1
    this.showStep()
  }

  next() { this.currentStep += 1; this.showStep() }

  showStep() {
    this.stepTargets.forEach((step, index) => { step.hidden = index !== this.currentStep })
    this.progressTarget.setAttribute("aria-valuenow", String(this.currentStep + 1))
    this.progressFillTarget.style.width = `${(this.currentStep + 1) * 20}%`
    this.stepCountTarget.textContent = `${this.currentStep + 1} / 5`
    this.continueTarget.disabled = this.microphoneConfirmedTarget.value !== "1"
    if (this.currentStep > 0) this.stepTargets[this.currentStep].querySelector("h1")?.setAttribute("tabindex", "-1")
    this.stepTargets[this.currentStep].querySelector("h1")?.focus({ preventScroll: true })
    this.element.closest("main").scrollTop = 0
  }

  chooseLanguage(event) { this.nativeTarget.value = event.currentTarget.dataset.value; this.next() }
  chooseAge(event) {
    this.ageTarget.value = event.currentTarget.dataset.value
    this.ageErrorTarget.hidden = this.ageTarget.value !== "under_18"
    if (this.ageErrorTarget.hidden) this.next()
  }
  chooseGender(event) { this.genderTarget.value = event.currentTarget.dataset.value; this.next() }

  search(event) {
    const query = event.target.value.trim().toLowerCase()
    this.languageOptionTargets.forEach(option => { option.hidden = !option.dataset.label.toLowerCase().includes(query) })
    this.noResultsTarget.hidden = this.languageOptionTargets.some(option => !option.hidden)
  }

  async requestMicrophone() {
    this.microphoneButtonTarget.disabled = true
    this.microphoneStatusTarget.textContent = "Waiting for microphone permission…"
    this.microphoneConfirmedTarget.value = "0"
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true })
      stream.getTracks().forEach(track => track.stop())
      if (!this.element.isConnected) return
      this.microphoneConfirmedTarget.value = "1"
      this.microphoneStatusTarget.textContent = "Microphone access allowed."
      if (this.currentStep === 3) this.next()
    } catch {
      if (this.element.isConnected) this.microphoneStatusTarget.textContent = "Microphone access was not allowed. Enable it in your browser or device settings, then try again."
    } finally {
      if (this.element.isConnected) this.microphoneButtonTarget.disabled = false
    }
  }

  validate(event) {
    if (this.currentStep !== 4 || !this.nativeTarget.value || !["18_24", "25_34", "35_44", "45_plus"].includes(this.ageTarget.value) || !this.genderTarget.value || this.microphoneConfirmedTarget.value !== "1") {
      event.preventDefault()
      return
    }
    this.rulesTarget.value = "1"
  }
}
