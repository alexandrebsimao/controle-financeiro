import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["typeSelect", "destinationField", "categoryField"]

  connect() {
    this.updateFieldVisibility()
    if (this.hasTypeSelectTarget) {
      this.typeSelectTarget.addEventListener("change", () => this.updateFieldVisibility())
    }
  }

  updateFieldVisibility() {
    if (!this.hasTypeSelectTarget) return

    const isTransfer = this.typeSelectTarget.value === "transfer"
    
    if (this.hasDestinationFieldTarget) {
      this.destinationFieldTarget.style.display = isTransfer ? "block" : "none"
    }
    
    if (this.hasCategoryFieldTarget) {
      this.categoryFieldTarget.style.display = isTransfer ? "none" : "block"
    }
  }
}
