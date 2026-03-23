import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["fileName", "progressSection", "progressBar", "progressPct", "fileInput", "submitBtn"]

  fileChanged(event) {
    const file = event.target.files[0]
    if (!file) return

    const maxBytes = 500 * 1024 * 1024 // 500 MB
    if (file.size > maxBytes) {
      alert("File is too large. Maximum size is 500 MB.")
      event.target.value = ""
      return
    }

    this.fileNameTarget.textContent = file.name
    this.fileNameTarget.classList.remove("hidden")
  }

  submit(event) {
    event.preventDefault()

    const form = this.element
    const formData = new FormData(form)

    const xhr = new XMLHttpRequest()
    xhr.open("POST", form.action)
    xhr.setRequestHeader("X-CSRF-Token", document.querySelector("meta[name=csrf-token]").content)
    xhr.setRequestHeader("Accept", "text/html, application/xhtml+xml")

    xhr.upload.addEventListener("loadstart", () => {
      this.progressSectionTarget.classList.remove("hidden")
      this.progressBarTarget.style.width = "0%"
      this.progressPctTarget.textContent = "0%"
      if (this.hasSubmitBtnTarget) this.submitBtnTarget.disabled = true
    })

    xhr.upload.addEventListener("progress", (e) => {
      if (!e.lengthComputable) return
      const pct = Math.round((e.loaded / e.total) * 100)
      this.progressBarTarget.style.width = pct + "%"
      this.progressPctTarget.textContent = pct + "%"
    })

    xhr.upload.addEventListener("load", () => {
      this.progressPctTarget.textContent = "Queuing…"
    })

    xhr.addEventListener("load", () => {
      if (xhr.responseURL) window.location.href = xhr.responseURL
    })

    xhr.addEventListener("error", () => {
      alert("Upload failed. Please try again.")
      if (this.hasSubmitBtnTarget) this.submitBtnTarget.disabled = false
    })

    xhr.send(formData)
  }
}
