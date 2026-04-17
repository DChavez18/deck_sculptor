import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "toggleIcon", "submitButton"]

  toggle() {
    const hidden = this.panelTarget.classList.contains("hidden")
    this.panelTarget.classList.toggle("hidden", !hidden)
    this.toggleIconTarget.textContent = hidden ? "▲" : "▼"
  }

  submit(event) {
    this.submitButtonTarget.disabled = true
    this.submitButtonTarget.value = "Importing..."
  }

  submitEnd() {
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = false
      this.submitButtonTarget.value = "Import Cards"
    }
  }
}
