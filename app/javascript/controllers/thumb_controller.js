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
    this.downTarget.classList.remove("bg-slate-700", "hover:bg-red-700", "text-slate-300", "hover:text-white")
    this.downTarget.classList.add("bg-red-600", "text-white")
    this.upTarget.classList.remove("bg-green-600")
    this.upTarget.classList.add("bg-slate-700", "text-slate-300")
  }
}
