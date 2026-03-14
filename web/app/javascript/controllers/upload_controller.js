import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["fileName", "progressSection", "progressBar", "progressPct"]

  fileChanged(event) {
    const file = event.target.files[0]
    if (file) {
      this.fileNameTarget.textContent = file.name
      this.fileNameTarget.classList.remove("hidden")
    }
  }

  uploadStarted() {
    this.progressSectionTarget.classList.remove("hidden")
    this.progressBarTarget.style.width = "0%"
    this.progressPctTarget.textContent = "0%"
  }

  uploadProgress(event) {
    const pct = Math.round(event.detail.progress)
    this.progressBarTarget.style.width = pct + "%"
    this.progressPctTarget.textContent = pct + "%"
  }

  uploadEnd() {
    this.progressPctTarget.textContent = "Queuing…"
  }
}
