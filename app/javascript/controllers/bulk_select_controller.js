import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["selectAll", "checkbox", "toolbar", "count", "unpaidCount", "markPaidForm", "destroyForm", "formInputs"]

  connect() {
    this.refreshState()
  }

  toggleAll(event) {
    const checked = event.currentTarget.checked
    this.selectAllTargets.forEach((cb) => {
      cb.checked = checked
      cb.indeterminate = false
    })
    this.checkboxTargets.forEach((cb) => {
      cb.checked = checked
      this.highlightRow(cb, checked)
    })
    this.refreshState()
  }

  toggleItem(event) {
    const target = event.currentTarget
    const value = target.value
    const checked = target.checked

    // Keep desktop and mobile checkboxes for the same transaction ID in sync
    this.checkboxTargets.forEach((cb) => {
      if (cb.value === value) {
        cb.checked = checked
        this.highlightRow(cb, checked)
      }
    })

    this.refreshState()
  }

  clear() {
    this.selectAllTargets.forEach((cb) => {
      cb.checked = false
      cb.indeterminate = false
    })
    this.checkboxTargets.forEach((cb) => {
      cb.checked = false
      this.highlightRow(cb, false)
    })
    this.refreshState()
  }

  highlightRow(checkbox, checked) {
    const row = checkbox.closest("tr") || checkbox.closest("[data-bulk-row]")
    if (row) {
      row.classList.toggle("bg-indigo-50/50", checked)
    }
  }

  refreshState() {
    const allIds = new Set()
    const selectedIds = new Set()
    const unpaidSelectedIds = new Set()

    this.checkboxTargets.forEach((cb) => {
      allIds.add(cb.value)
      if (cb.checked) {
        selectedIds.add(cb.value)
        if (cb.dataset.paid === "false") {
          unpaidSelectedIds.add(cb.value)
        }
      }
    })

    const totalCount = allIds.size
    const selectedCount = selectedIds.size
    const unpaidCount = unpaidSelectedIds.size

    // Update selectAll checkbox states
    this.selectAllTargets.forEach((cb) => {
      if (totalCount === 0 || selectedCount === 0) {
        cb.checked = false
        cb.indeterminate = false
      } else if (selectedCount === totalCount) {
        cb.checked = true
        cb.indeterminate = false
      } else {
        cb.checked = false
        cb.indeterminate = true
      }
    })

    // Update count badges
    this.countTargets.forEach((el) => {
      el.textContent = selectedCount
    })

    this.unpaidCountTargets.forEach((el) => {
      el.textContent = unpaidCount
    })

    // Show/hide bulk action toolbar
    this.toolbarTargets.forEach((toolbar) => {
      toolbar.classList.toggle("hidden", selectedCount === 0)
    })

    // Sync hidden inputs in bulk forms
    this.formInputsTargets.forEach((container) => {
      container.innerHTML = ""
      selectedIds.forEach((id) => {
        const input = document.createElement("input")
        input.type = "hidden"
        input.name = "transaction_ids[]"
        input.value = id
        container.appendChild(input)
      })
    })
  }
}
