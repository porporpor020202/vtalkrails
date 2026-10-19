import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "medium", "campaign", "content", "url", "status"]
  static values = { base: String }
  connect() { this.update() }

  update() {
    const url = new URL(this.baseValue)
    for (const key of ["source", "medium", "campaign", "content"]) {
      const value = this[`${key}Target`].value.trim()
      if (value) url.searchParams.set(`utm_${key}`, value)
    }
    this.urlTarget.value = url.toString()
    this.statusTarget.textContent = ""
  }

  async copy() {
    try {
      await navigator.clipboard.writeText(this.urlTarget.value)
      this.statusTarget.textContent = "복사했어요. 홍보 글에 붙여넣으세요."
    } catch {
      this.urlTarget.select()
      this.statusTarget.textContent = "링크를 선택했어요. 복사해서 사용하세요."
    }
  }
}
