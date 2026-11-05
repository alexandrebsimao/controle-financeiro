import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "tabButton"]

  showTab(event) {
    event.preventDefault()
    
    const tabName = event.currentTarget.dataset.tab
    if (!tabName) return
    
    // Hide all tabs (both by targets and by id fallback)
    if (this.hasTabTargets && this.tabTargets.length > 0) {
      this.tabTargets.forEach(tab => {
        tab.classList.add("hidden")
      })
    } else {
      // Fallback: hide any container matching known tab patterns
      document.querySelectorAll(`[id^='tab-']`).forEach(tab => {
        tab.classList.add("hidden")
      })
    }
    
    // Show selected tab
    const selectedTab = document.getElementById(tabName)
    if (selectedTab) {
      selectedTab.classList.remove("hidden")
      
      // Force Chart.js canvases inside the newly revealed tab to calculate correct dimensions
      setTimeout(() => {
        window.dispatchEvent(new Event("resize"))
      }, 50)
    }
    
    // Update active button styling
    if (this.hasTabButtonTargets) {
      this.tabButtonTargets.forEach(button => {
        button.classList.remove("text-brand-700", "border-brand-600", "bg-brand-50", "bg-brand-50/50", "text-blue-600", "border-blue-600", "font-bold")
        button.classList.add("text-slate-500", "hover:text-slate-700", "hover:border-slate-300", "border-transparent", "font-semibold")
      })
    }
    
    event.currentTarget.classList.add("text-brand-700", "border-brand-600", "bg-brand-50/50", "font-bold")
    event.currentTarget.classList.remove("text-slate-500", "hover:text-slate-700", "border-transparent", "font-semibold")
  }
}
