import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "dropdown", "selectedDisplay", "error", "scryfallId", "cardName"]

  connect() {
    this._debounceTimer = null
    this._boundHideOnOutsideClick = this._hideOnOutsideClick.bind(this)
    document.addEventListener("click", this._boundHideOnOutsideClick)
  }

  disconnect() {
    document.removeEventListener("click", this._boundHideOnOutsideClick)
  }

  search() {
    clearTimeout(this._debounceTimer)
    this.scryfallIdTarget.value = ""
    this.cardNameTarget.value = ""
    this.selectedDisplayTarget.classList.add("hidden")
    this._debounceTimer = setTimeout(() => this._performSearch(), 300)
  }

  select(event) {
    const cardId = event.currentTarget.dataset.cardId
    const cardName = event.currentTarget.dataset.cardName

    this.scryfallIdTarget.value = cardId
    this.cardNameTarget.value = cardName
    this.inputTarget.value = cardName

    this.dropdownTarget.classList.add("hidden")
    this.dropdownTarget.innerHTML = ""

    this.selectedDisplayTarget.textContent = `Selected: ${cardName}`
    this.selectedDisplayTarget.classList.remove("hidden")

    this.errorTarget.classList.add("hidden")

    this.element.querySelector("form").requestSubmit()
  }

  validateAndSubmit(event) {
    if (!this.scryfallIdTarget.value) {
      event.preventDefault()
      this.errorTarget.classList.remove("hidden")
    }
  }

  _performSearch() {
    const query = this.inputTarget.value.trim()
    if (query.length < 2) {
      this.dropdownTarget.classList.add("hidden")
      return
    }

    fetch(`/cards/search?q=${encodeURIComponent(query)}`, {
      headers: {
        Accept: "text/html",
        "X-Requested-With": "XMLHttpRequest"
      }
    })
      .then((response) => response.text())
      .then((html) => {
        this.dropdownTarget.innerHTML = html
        this.dropdownTarget.classList.remove("hidden")
      })
  }

  _hideOnOutsideClick(event) {
    if (!this.element.contains(event.target)) {
      this.dropdownTarget.classList.add("hidden")
    }
  }
}
