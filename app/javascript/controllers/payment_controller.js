import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggleButton", "closeButton", "form", "select"]

  connect() {
    // Setup click handlers for all toggle buttons
    this.toggleButtonTargets.forEach((button) => {
      button.addEventListener("click", (event) => this.openModal(event))
    })

    // Setup click handlers for all close buttons
    this.closeButtonTargets.forEach((button) => {
      button.addEventListener("click", (event) => this.closeModal(event))
    })

    // Setup change handlers for all selects
    this.selectTargets.forEach((select) => {
      select.addEventListener("change", (event) => this.hideError(event))
    })

    // Setup submit handlers for all forms
    this.formTargets.forEach((form) => {
      form.addEventListener("submit", (event) => this.validateForm(event))
    })
  }

  disconnect() {
    // Clean up event listeners
    this.toggleButtonTargets.forEach((button) => {
      button.removeEventListener("click", (event) => this.openModal(event))
    })
    this.closeButtonTargets.forEach((button) => {
      button.removeEventListener("click", (event) => this.closeModal(event))
    })
  }

  openModal(event) {
    const modalId = event.currentTarget.dataset.modalId
    const modal = document.getElementById(modalId)
    if (modal) {
      modal.classList.remove("hidden")
    }
    document.querySelectorAll('[data-dropdown-target="menu"]:not(.hidden)').forEach((menu) => {
      menu.classList.add("hidden")
    })
  }

  closeModal(event) {
    const modal = event.currentTarget.closest(".fixed")
    if (modal) {
      modal.classList.add("hidden")
    }
  }

  hideError(event) {
    const form = event.target.closest("form")
    if (form) {
      const errorMsg = form.querySelector("[data-payment-error]")
      if (errorMsg) {
        errorMsg.classList.add("hidden")
      }
    }
  }

  validateForm(event) {
    const form = event.target
    const selects = form.querySelectorAll("select")
    let isValid = true

    selects.forEach((select) => {
      if (!select.value) {
        isValid = false
      }
    })

    if (!isValid) {
      event.preventDefault()
      const errorMsg = form.querySelector("[data-payment-error]")
      const errorText = form.querySelector("[data-payment-error-text]")

      if (errorMsg && errorText) {
        errorText.textContent = "Por favor, preencha todos os campos obrigatórios."
        errorMsg.classList.remove("hidden")
      }
    }
  }
}
