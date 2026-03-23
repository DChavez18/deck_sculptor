import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "selectedDisplay"]

  connect() {
    this._debounceTimer = null
  }

  search() {
    clearTimeout(this._debounceTimer)
    this._debounceTimer = setTimeout(() => {
      this._submitSearch()
    }, 300)
  }

  select(event) {
    const commanderName = event.currentTarget.dataset.commanderName
    const commanderScryfallId = event.currentTarget.dataset.commanderId

    const hiddenInput = document.getElementById("deck_commander_scryfall_id")
    if (hiddenInput) {
      hiddenInput.value = commanderScryfallId
    }

    if (this.hasSelectedDisplayTarget) {
      this.selectedDisplayTarget.textContent = `Selected: ${commanderName}`
      this.selectedDisplayTarget.classList.remove("text-slate-500")
      this.selectedDisplayTarget.classList.add("text-blue-400")
    }
  }

  _submitSearch() {
    const query = this.inputTarget.value.trim()
    const url = `/commanders/search?q=${encodeURIComponent(query)}`

    fetch(url, {
      headers: {
        Accept: "text/vnd.turbo-stream.html, text/html",
        "X-Requested-With": "XMLHttpRequest"
      }
    })
      .then((response) => response.text())
      .then((html) => {
        const frame = document.querySelector("turbo-frame#commander_results")
        if (frame) {
          frame.innerHTML = html
        }
      })
  }
}
