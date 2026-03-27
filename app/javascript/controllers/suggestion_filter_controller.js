import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["pill", "card", "search"]

  connect() {
    this._activeFilter = "all"
  }

  filter(event) {
    this._activeFilter = event.currentTarget.dataset.filter
    this._updatePills()
    this._applyFilters()
  }

  search() {
    this._applyFilters()
  }

  _updatePills() {
    this.pillTargets.forEach((pill) => {
      const active = pill.dataset.filter === this._activeFilter
      pill.classList.toggle("bg-blue-600", active)
      pill.classList.toggle("text-white", active)
      pill.classList.toggle("bg-slate-700", !active)
      pill.classList.toggle("text-slate-300", !active)
    })
  }

  _applyFilters() {
    const query = this.hasSearchTarget ? this.searchTarget.value.trim().toLowerCase() : ""

    this.cardTargets.forEach((card) => {
      const tags = (card.dataset.filterTags || "").split(" ")
      const name = (card.dataset.cardName || "").toLowerCase()

      const filterMatch = this._activeFilter === "all" || tags.includes(this._activeFilter)
      const searchMatch = !query || name.includes(query)

      card.classList.toggle("hidden", !(filterMatch && searchMatch))
    })
  }
}
