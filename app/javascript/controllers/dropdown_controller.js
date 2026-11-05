import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "menu", "submenuButton", "submenu"]
  static values = { fixed: Boolean }

  toggle(event) {
    if (event) {
      event.stopPropagation()
    }
    if (!this.hasMenuTarget) return

    const isOpening = this.menuTarget.classList.contains("hidden")

    // Close all other open dropdown menus on the page
    document.querySelectorAll('[data-dropdown-target="menu"]:not(.hidden)').forEach((menu) => {
      if (menu !== this.menuTarget) {
        menu.classList.add("hidden")
      }
    })

    if (isOpening) {
      if (this.fixedValue || this.menuTarget.classList.contains("action-menu-dropdown")) {
        const buttonRect = this.hasButtonTarget ? this.buttonTarget.getBoundingClientRect() : null
        this.menuTarget.style.visibility = "hidden"
        this.menuTarget.classList.remove("hidden")
        this.positionFixedMenu(buttonRect)
        this.menuTarget.style.visibility = ""
      } else {
        this.menuTarget.classList.remove("hidden")
      }
    } else {
      this.hideMenu()
    }
  }

  positionFixedMenu(precomputedButtonRect = null) {
    if (!this.hasButtonTarget || !this.hasMenuTarget) return

    const buttonRect = precomputedButtonRect || this.buttonTarget.getBoundingClientRect()
    const menu = this.menuTarget

    // If button scrolled completely out of view, close the menu
    const viewportWidth = document.documentElement.clientWidth || window.innerWidth
    const viewportHeight = document.documentElement.clientHeight || window.innerHeight
    if (buttonRect.bottom < 0 || buttonRect.top > viewportHeight) {
      this.hideMenu()
      return
    }

    menu.style.position = "fixed"
    menu.style.zIndex = "9999"
    menu.style.margin = "0"
    menu.style.right = "auto"
    menu.style.bottom = "auto"

    const menuWidth = menu.offsetWidth || 184
    const menuHeight = menu.offsetHeight || 160

    // Align right edge of menu with right edge of the button
    let left = Math.round(buttonRect.right - menuWidth)
    if (left < 8) left = 8
    if (left + menuWidth > viewportWidth - 8) {
      left = viewportWidth - menuWidth - 8
    }

    // Open downwards with a 6px gap, or upwards if near bottom of viewport
    const spaceBelow = viewportHeight - buttonRect.bottom
    let top
    if (spaceBelow < menuHeight + 12 && buttonRect.top > menuHeight + 12) {
      top = Math.round(buttonRect.top - menuHeight - 6)
    } else {
      top = Math.round(buttonRect.bottom + 6)
    }

    menu.style.left = `${left}px`
    menu.style.top = `${top}px`
  }

  toggleSubmenu(event) {
    if (event) {
      event.stopPropagation()
    }
    const button = event.currentTarget
    const submenu = button.nextElementSibling
    if (submenu) {
      submenu.classList.toggle("hidden")
    }
  }

  hideMenu() {
    if (this.hasMenuTarget) {
      this.menuTarget.classList.add("hidden")
      this.submenuTargets.forEach((submenu) => {
        submenu.classList.add("hidden")
      })
    }
  }

  close(event) {
    if (this.hasMenuTarget && !this.element.contains(event.target)) {
      this.hideMenu()
    }
  }

  closeOnEscape(event) {
    if (event.key === "Escape") {
      this.hideMenu()
    }
  }

  repositionOnScroll() {
    if (this.hasMenuTarget && !this.menuTarget.classList.contains("hidden")) {
      if (this.fixedValue || this.menuTarget.classList.contains("action-menu-dropdown")) {
        this.positionFixedMenu()
      }
    }
  }

  connect() {
    this.closeHandler = this.close.bind(this)
    this.escapeHandler = this.closeOnEscape.bind(this)
    this.scrollHandler = this.repositionOnScroll.bind(this)
    document.addEventListener("click", this.closeHandler)
    document.addEventListener("keydown", this.escapeHandler)
    window.addEventListener("scroll", this.scrollHandler, true)
    window.addEventListener("resize", this.scrollHandler)
  }

  disconnect() {
    document.removeEventListener("click", this.closeHandler)
    document.removeEventListener("keydown", this.escapeHandler)
    window.removeEventListener("scroll", this.scrollHandler, true)
    window.removeEventListener("resize", this.scrollHandler)
  }
}
