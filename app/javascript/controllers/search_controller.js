// app/javascript/controllers/search_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  query() {
    const query = this.inputTarget.value;
    fetch(`/products/search?q=${encodeURIComponent(query)}`, {
      headers: {
        "Accept": "text/html" 
      }
    })
    .then(response => response.text())
    .then(html => {
      document.querySelector('#search-results').innerHTML = html;
    })
    .catch(error => console.error('Error:', error));
  }

}
