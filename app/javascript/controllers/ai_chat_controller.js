import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "history", "textarea", "sendButton", "inputWrapper", "toggleIcon"]

  toggle() {
    const panel = this.panelTarget
    const isHidden = panel.classList.contains("hidden")

    if (isHidden) {
      panel.classList.remove("hidden")
      this.toggleIconTarget.textContent = "▲"
      this._scrollToBottom()
    } else {
      panel.classList.add("hidden")
      this.toggleIconTarget.textContent = "▼"
    }
  }

  send(event) {
    event.preventDefault()

    const message = this.textareaTarget.value.trim()
    if (!message) return

    this._setThinking(true)

    const form = event.target
    const formData = new FormData(form)

    fetch(form.action, {
      method: "POST",
      headers: { "Accept": "text/vnd.turbo-stream.html", "X-CSRF-Token": this._csrfToken() },
      body: formData
    }).then(response => {
      return response.text()
    }).then(html => {
      // Let Turbo handle stream rendering
      const parser = new DOMParser()
      const doc = parser.parseFromString(html, "text/html")
      doc.querySelectorAll("turbo-stream").forEach(stream => {
        window.Turbo.renderStreamMessage(stream.outerHTML)
      })
      this._setThinking(false)
      this._scrollToBottom()
    }).catch(() => {
      this._setThinking(false)
    })
  }

  // Called by Turbo after stream replaces #chat-input — reset button state
  inputWrapperTargetConnected() {
    this._setThinking(false)
  }

  _setThinking(thinking) {
    if (!this.hasSendButtonTarget) return
    this.sendButtonTarget.disabled = thinking
    this.sendButtonTarget.textContent = thinking ? "Thinking…" : "Send"
  }

  _scrollToBottom() {
    if (!this.hasHistoryTarget) return
    this.historyTarget.scrollTop = this.historyTarget.scrollHeight
  }

  _csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || ""
  }
}
