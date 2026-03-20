import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

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
    const commanderSelect = document.querySelector("select[name='deck[commander_id]']")

    if (commanderSelect) {
      const option = Array.from(commanderSelect.options).find(
        (o) => o.text === commanderName
      )
      if (option) {
        commanderSelect.value = option.value
      }
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
