import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["text", "expand", "collapse"]

  expand(event) {
    event.stopPropagation()
    this.textTarget.classList.remove("line-clamp-3")
    this.expandTarget.classList.add("hidden")
    this.collapseTarget.classList.remove("hidden")
  }

  collapse(event) {
    event.stopPropagation()
    this.textTarget.classList.add("line-clamp-3")
    this.expandTarget.classList.remove("hidden")
    this.collapseTarget.classList.add("hidden")
  }
}
