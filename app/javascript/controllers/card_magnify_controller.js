import { Controller } from "@hotwired/stimulus"

// Provides magnify behavior for card thumbnails.
// Hover-capable devices (laptop): floating 300px preview follows cursor.
// Touch devices (mobile): tap thumbnail → full-screen modal, tap anywhere to dismiss.
// Behavior is decided via matchMedia "(hover: hover) and (pointer: fine)" — no UA sniffing.
export default class extends Controller {
  static values = { largeUrl: String }

  connect() {
    this.isHoverCapable = window.matchMedia(
      "(hover: hover) and (pointer: fine)"
    ).matches

    if (this.isHoverCapable) {
      this.element.addEventListener("mouseenter", this.showPreview)
      this.element.addEventListener("mouseleave", this.hidePreview)
      this.element.addEventListener("mousemove", this.movePreview)
    } else {
      this.element.addEventListener("click", this.openModal)
      this.element.style.cursor = "zoom-in"
    }
  }

  disconnect() {
    this.hidePreview()
    this.closeModal()
  }

  // -------- HOVER (laptop) --------

  showPreview = (event) => {
    if (this.previewEl) this.previewEl.remove()

    const img = document.createElement("img")
    img.src = this.largeUrlValue
    img.alt = "Card preview"
    img.style.position = "fixed"
    img.style.zIndex = "9999"
    img.style.width = "300px"
    img.style.borderRadius = "12px"
    img.style.boxShadow = "0 10px 30px rgba(0,0,0,0.5)"
    img.style.pointerEvents = "none"
    img.style.opacity = "0"
    img.style.transition = "opacity 120ms ease-out"

    document.body.appendChild(img)
    this.previewEl = img
    this.movePreview(event)

    requestAnimationFrame(() => {
      if (this.previewEl) this.previewEl.style.opacity = "1"
    })
  }

  movePreview = (event) => {
    if (!this.previewEl) return

    const padding   = 16
    const previewW  = 300
    const previewH  = 420
    const viewportW = window.innerWidth
    const viewportH = window.innerHeight

    let left = event.clientX + padding
    let top  = event.clientY - previewH / 2

    if (left + previewW > viewportW - padding) {
      left = event.clientX - previewW - padding
    }

    if (top < padding) top = padding
    if (top + previewH > viewportH - padding) {
      top = viewportH - previewH - padding
    }

    this.previewEl.style.left = `${left}px`
    this.previewEl.style.top  = `${top}px`
  }

  hidePreview = () => {
    if (this.previewEl) {
      this.previewEl.remove()
      this.previewEl = null
    }
  }

  // -------- TAP (mobile) --------

  openModal = (event) => {
    event.preventDefault()
    if (this.modalEl) this.closeModal()

    const overlay = document.createElement("div")
    overlay.style.position = "fixed"
    overlay.style.inset = "0"
    overlay.style.background = "rgba(0,0,0,0.85)"
    overlay.style.zIndex = "9999"
    overlay.style.display = "flex"
    overlay.style.alignItems = "center"
    overlay.style.justifyContent = "center"
    overlay.style.padding = "16px"
    overlay.style.cursor = "zoom-out"

    const img = document.createElement("img")
    img.src = this.largeUrlValue
    img.alt = "Card preview"
    img.style.maxWidth = "100%"
    img.style.maxHeight = "100%"
    img.style.borderRadius = "12px"
    img.style.boxShadow = "0 10px 30px rgba(0,0,0,0.5)"

    overlay.appendChild(img)
    overlay.addEventListener("click", this.closeModal)
    document.body.appendChild(overlay)
    document.body.style.overflow = "hidden"

    this.modalEl = overlay
  }

  closeModal = () => {
    if (this.modalEl) {
      this.modalEl.remove()
      this.modalEl = null
      document.body.style.overflow = ""
    }
  }
}
