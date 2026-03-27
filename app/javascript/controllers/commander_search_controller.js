import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "selectedDisplay", "preview", "searchArea"]

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
    const btn = event.currentTarget
    const commanderName = btn.dataset.commanderName
    const commanderScryfallId = btn.dataset.commanderId
    const commanderType = btn.dataset.commanderType || ""
    const cardImage = btn.dataset.cardImage || ""
    const dbId = btn.dataset.commanderDbId || ""

    const hiddenInput = document.getElementById("deck_commander_scryfall_id")
    if (hiddenInput) {
      hiddenInput.value = commanderScryfallId
    }

    if (this.hasSearchAreaTarget) {
      this.searchAreaTarget.classList.add("hidden")
    }

    if (this.hasPreviewTarget) {
      const profileHref = dbId ? `/commanders/${dbId}` : null

      let imageHtml = ""
      if (cardImage) {
        const imgTag = `<img src="${cardImage}" alt="${commanderName}" class="rounded-xl shadow-2xl shadow-blue-900/30 border border-slate-700 w-full max-w-xs">`
        imageHtml = profileHref
          ? `<a href="${profileHref}">${imgTag}</a>`
          : imgTag
      }

      this.previewTarget.innerHTML = `
        <div class="space-y-3">
          ${imageHtml}
          <div>
            <p class="text-white font-semibold">${commanderName}</p>
            <p class="text-slate-400 text-xs">${commanderType}</p>
          </div>
          <button type="button" data-action="commander-search#clear"
            class="text-slate-400 hover:text-white text-sm underline underline-offset-2">
            Change commander
          </button>
        </div>
      `
      this.previewTarget.classList.remove("hidden")
    }
  }

  clear() {
    const hiddenInput = document.getElementById("deck_commander_scryfall_id")
    if (hiddenInput) {
      hiddenInput.value = ""
    }

    if (this.hasPreviewTarget) {
      this.previewTarget.innerHTML = ""
      this.previewTarget.classList.add("hidden")
    }

    if (this.hasSearchAreaTarget) {
      this.searchAreaTarget.classList.remove("hidden")
    }

    if (this.hasInputTarget) {
      this.inputTarget.value = ""
      this.inputTarget.focus()
    }

    const frame = document.querySelector("turbo-frame#commander_results")
    if (frame) {
      frame.innerHTML = '<p class="text-slate-500 text-sm mt-3">Type a name to search commanders.</p>'
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
