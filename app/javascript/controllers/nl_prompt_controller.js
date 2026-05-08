// Single responsibility: capture prompt input, show spinner on submit, handle clear.
// All DOM access via data-* targets (no querySelector by class).
// No JS test suite exists yet; written to be testable when one is added.

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "input", "spinner", "clearBtn", "submitBtn"]

  connect() {
    this._boundSubmitStart = this._onSubmitStart.bind(this)
    this._boundSubmitEnd   = this._onSubmitEnd.bind(this)
    this.formTarget.addEventListener("turbo:submit-start", this._boundSubmitStart)
    this.formTarget.addEventListener("turbo:submit-end",   this._boundSubmitEnd)
  }

  disconnect() {
    this.formTarget.removeEventListener("turbo:submit-start", this._boundSubmitStart)
    this.formTarget.removeEventListener("turbo:submit-end",   this._boundSubmitEnd)
  }

  clear() {
    this.inputTarget.value = ""
    this.clearBtnTarget.classList.add("hidden")
    this.formTarget.requestSubmit()
  }

  updateClearVisibility() {
    this.clearBtnTarget.classList.toggle("hidden", !this.inputTarget.value.trim())
  }

  _onSubmitStart() {
    this._setLoading(true)
  }

  _onSubmitEnd() {
    this._setLoading(false)
  }

  _setLoading(loading) {
    this.spinnerTarget.classList.toggle("hidden", !loading)
    this.submitBtnTarget.disabled = loading
    this.submitBtnTarget.textContent = loading ? "Searching…" : "Search"
    this.clearBtnTarget.classList.toggle("hidden", loading || !this.inputTarget.value.trim())
  }
}
