import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "output"]

  connect() {
    this.render()
  }

  render() {
    const rawContent = this.hasSourceTarget 
      ? (this.sourceTarget.value || this.sourceTarget.textContent || "")
      : this.element.textContent

    if (!rawContent || !rawContent.trim()) return

    if (window.marked && typeof window.marked.parse === "function") {
      window.marked.setOptions({
        gfm: true,
        breaks: true
      })
      const parsedHtml = window.marked.parse(rawContent)
      if (this.hasOutputTarget) {
        this.outputTarget.innerHTML = parsedHtml
      } else {
        this.element.innerHTML = parsedHtml
      }
    } else {
      // Fallback básico se marked ainda estiver carregando
      const simpleHtml = this.basicMarkdown(rawContent)
      if (this.hasOutputTarget) {
        this.outputTarget.innerHTML = simpleHtml
      } else {
        this.element.innerHTML = simpleHtml
      }
    }
  }

  basicMarkdown(text) {
    return text
      .replace(/^### (.*$)/gim, '<h3 class="text-lg font-bold text-gray-800 mt-4 mb-2">$1</h3>')
      .replace(/^## (.*$)/gim, '<h2 class="text-xl font-bold text-indigo-700 mt-6 mb-3 border-b pb-1">$1</h2>')
      .replace(/^# (.*$)/gim, '<h1 class="text-2xl font-bold text-gray-900 mt-6 mb-4">$1</h1>')
      .replace(/\*\*(.*?)\*\*/gim, '<strong class="font-semibold text-gray-900">$1</strong>')
      .replace(/\*(.*?)\*/gim, '<em class="italic">$1</em>')
      .replace(/^\s*-\s+(.*$)/gim, '<li class="ml-4 list-disc text-gray-700">$1</li>')
      .replace(/\n$/gim, '<br />')
  }
}
