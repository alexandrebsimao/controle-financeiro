import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "toggleButton", "closeButton", "form", "errorMessage", "bankAccountSelect"]

  connect() {
    // Setup event listeners only for targets that exist
    if (this.hasToggleButtonTarget) {
      this.toggleButtonTargets.forEach((button) => {
        button.addEventListener("click", this.open.bind(this))
      })
    }

    if (this.hasCloseButtonTarget) {
      this.closeButtonTargets.forEach((button) => {
        button.addEventListener("click", this.close.bind(this))
      })
    }

    if (this.hasBankAccountSelectTarget) {
      this.bankAccountSelectTargets.forEach((select) => {
        select.addEventListener("change", this.hideErrorOnChange.bind(this))
      })
    }

    if (this.hasFormTarget) {
      this.formTargets.forEach((form) => {
        form.addEventListener("submit", this.validatePaymentForm.bind(this))
      })
    }

    // Close modal when clicking outside
    this.closeHandler = this.closeOnOutsideClick.bind(this)
    document.addEventListener("click", this.closeHandler)
  }

  disconnect() {
    document.removeEventListener("click", this.closeHandler)
  }

  open(event) {
    if (event) {
      event.preventDefault()
      event.stopPropagation()
    }
    const modalId = event.currentTarget.getAttribute("data-modal-id")
    const modal = document.getElementById(modalId)
    if (modal) {
      modal.classList.remove("hidden")
    }
  }

  close(event) {
    if (event) {
      event.preventDefault()
      event.stopPropagation()
    }
    const modal = event.currentTarget.closest(".fixed")
    if (modal) {
      modal.classList.add("hidden")
    }
  }

  closeOnOutsideClick(event) {
    const modals = document.querySelectorAll(".fixed[role='dialog']")
    modals.forEach((modal) => {
      if (
        event.target === modal &&
        !modal.classList.contains("hidden")
      ) {
        modal.classList.add("hidden")
      }
    })
  }

  hideErrorOnChange(event) {
    const select = event.target
    const form = select.closest("form")
    if (form) {
      const errorMessage = form.querySelector("[data-modal-error]")
      if (errorMessage) {
        errorMessage.classList.add("hidden")
      }
    }
  }

  validatePaymentForm(event) {
    const form = event.target
    const select = form.querySelector("select")
    
    if (select && !select.value) {
      event.preventDefault()
      const errorMessage = form.querySelector("[data-modal-error]")
      const errorText = form.querySelector("[data-modal-error-text]")
      if (errorMessage && errorText) {
        errorText.textContent = "Por favor, selecione uma conta bancária."
        errorMessage.classList.remove("hidden")
      }
    }
  }
}

