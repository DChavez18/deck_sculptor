import { Controller } from "@hotwired/stimulus"

// Sorts card rows within each .category-body section client-side.
// Each row carries data-card-name and data-card-cmc attributes.
// A-Z: lexicographic by name; CMC: numeric ascending by mana value.
// Re-inserting sorted nodes via appendChild is a no-op for the last
// position and avoids DOM thrash compared to innerHTML replacement.
export default class extends Controller {
  static targets = ["nameButton", "cmcButton"]

  sortByName() {
    this.#sortCategories((a, b) =>
      a.dataset.cardName.localeCompare(b.dataset.cardName)
    )
    this.#setActive(this.nameButtonTarget)
  }

  sortByCmc() {
    this.#sortCategories((a, b) =>
      parseFloat(a.dataset.cardCmc) - parseFloat(b.dataset.cardCmc)
    )
    this.#setActive(this.cmcButtonTarget)
  }

  #sortCategories(compareFn) {
    this.element.querySelectorAll(".category-body").forEach(body => {
      Array.from(body.children)
        .sort(compareFn)
        .forEach(row => body.appendChild(row))
    })
  }

  #setActive(activeButton) {
    const buttons = [this.nameButtonTarget, this.cmcButtonTarget]
    buttons.forEach(btn => {
      const isActive = btn === activeButton
      btn.classList.toggle("bg-blue-600", isActive)
      btn.classList.toggle("text-white", isActive)
      btn.classList.toggle("bg-slate-700", !isActive)
      btn.classList.toggle("text-slate-300", !isActive)
    })
  }
}
