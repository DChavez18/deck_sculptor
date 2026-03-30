import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["up", "down"]

  thumbUp() {
    this.upTarget.classList.remove("bg-slate-700", "hover:bg-green-700", "text-slate-300", "hover:text-white")
    this.upTarget.classList.add("bg-green-600", "text-white")
    this.downTarget.classList.remove("bg-red-600")
    this.downTarget.classList.add("bg-slate-700", "text-slate-300")
  }

  thumbDown() {
    const card = this.element.closest("[id^='suggestion-']")
    if (card) card.remove()
  }
}
