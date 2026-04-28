import { Controller } from "@hotwired/stimulus"

// Toggles a password input between type="password" and type="text",
// and swaps the eye / eye-slash icon visibility accordingly.
export default class extends Controller {
  static targets = [ "input", "showIcon", "hideIcon" ]

  connect() {
    this.showIconTarget.classList.remove("hidden")
    this.hideIconTarget.classList.add("hidden")
  }

  toggle(event) {
    event.preventDefault()
    const input    = this.inputTarget
    const isHidden = input.type === "password"

    input.type = isHidden ? "text" : "password"
    this.showIconTarget.classList.toggle("hidden", isHidden)
    this.hideIconTarget.classList.toggle("hidden", !isHidden)
  }
}
