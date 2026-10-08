import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["native", "learning", "dialog", "continue", "microphoneStatus", "microphoneConfirmed", "birthday", "nativeGuidance", "learningGuidance", "ageGuidance"]

  connect() {
    this.microphoneGranted = false
    this.sync()
    if (this.hasContinueTarget && navigator.permissions) {
      navigator.permissions.query({ name: "microphone" }).then(permission => {
        if (!this.element.isConnected) return
        this.permission = permission
        this.permissionChanged = () => {
          if (permission.state !== "granted") {
            this.microphoneGranted = false
            this.sync()
          }
        }
        permission.addEventListener("change", this.permissionChanged)
      }).catch(() => {})
    }
  }

  disconnect() {
    this.permission?.removeEventListener("change", this.permissionChanged)
  }

  validate(event) {
    if (this.hasContinueTarget) {
      this.sync()
      if (this.continueTarget.disabled) event.preventDefault()
      return
    }
    if (this.nativeTarget.value && this.learningTarget.value) return
    event.preventDefault()
    this.dialogTarget.showModal()
  }

  closeDialog() {
    this.dialogTarget.close()
  }

  formatBirthday() {
    const digits = this.birthdayTarget.value.replace(/\D/g, "").slice(0, 8)
    this.birthdayTarget.value = [digits.slice(0, 4), digits.slice(4, 6), digits.slice(6, 8)].filter(Boolean).join("-")
    this.sync()
  }

  sync() {
    const nativeLanguage = this.nativeTarget.value
    for (const option of this.learningTarget.options) {
      option.disabled = option.value !== "" && option.value === nativeLanguage
    }
    if (nativeLanguage && this.learningTarget.value === nativeLanguage) this.learningTarget.value = ""
    if (!this.hasContinueTarget) return

    this.nativeGuidanceTarget.hidden = !!this.nativeTarget.value
    this.learningGuidanceTarget.hidden = !!this.learningTarget.value
    this.microphoneStatusTarget.textContent = this.microphoneGranted ? "Microphone access allowed" : "Microphone access is denied. Please enable microphone access."
    this.microphoneConfirmedTarget.value = this.microphoneGranted ? "1" : "0"

    const today = new Date()
    today.setHours(0, 0, 0, 0)
    const birthday = new Date(`${this.birthdayTarget.value}T00:00:00`)
    const adultBirthday = new Date(today)
    adultBirthday.setFullYear(today.getFullYear() - 18)
    const adult = !Number.isNaN(birthday.getTime()) && birthday <= adultBirthday
    this.ageGuidanceTarget.hidden = adult
    this.ageGuidanceTarget.textContent = !this.birthdayTarget.value ? "Please enter your date of birth." :
      Number.isNaN(birthday.getTime()) || birthday > today ? "Please enter a valid date of birth." : "You must be at least 18 years old."
    this.continueTarget.disabled = !(this.nativeTarget.value && this.learningTarget.value && this.microphoneGranted && adult)
  }

  async requestMicrophone() {
    this.microphoneGranted = false
    this.sync()
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true })
      for (const track of stream.getTracks()) track.stop()
      this.microphoneGranted = true
    } catch {
      this.microphoneGranted = false
    } finally {
      if (this.element.isConnected) this.sync()
    }
  }
}
