import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["inner"]

  flip() {
    this.innerTarget.classList.toggle("is-flipped")
  }

  stopPropagation(event) {
    event.stopPropagation()
  }
}
