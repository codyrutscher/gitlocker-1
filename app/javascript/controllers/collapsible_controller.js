import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "expandIcon", "collapseIcon"]

  toggle() {
    this.contentTarget.classList.toggle("hidden")
    this.expandIconTarget.classList.toggle("hidden")
    this.collapseIconTarget.classList.toggle("hidden")
  }
} 