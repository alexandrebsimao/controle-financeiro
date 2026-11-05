import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sidebar", "backdrop", "toggle"]

  connect() {
    this.sidebarOpen = false
  }

  toggle() {
    this.sidebarOpen ? this.close() : this.open()
  }

  open() {
    this.sidebarOpen = true
    this.sidebarTarget.classList.remove("-translate-x-full")
    this.backdropTarget.classList.remove("hidden")
    document.body.style.overflow = "hidden"
  }

  close() {
    this.sidebarOpen = false
    this.sidebarTarget.classList.add("-translate-x-full")
    this.backdropTarget.classList.add("hidden")
    document.body.style.overflow = "auto"
  }

  closeOnBackdrop(event) {
    if (event.target === this.backdropTarget) {
      this.close()
    }
  }

  closeOnKeydown(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }
}
