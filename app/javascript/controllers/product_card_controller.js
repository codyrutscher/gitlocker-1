import { Controller } from '@hotwired/stimulus';
import { toggle } from 'el-transition';
import { useHover } from 'stimulus-use';

export default class extends Controller {
  static targets = ['menu', 'menuItem'];

  connect() {
    // Check if the menuTarget exists before attempting to use it
    if (this.hasMenuTarget) {
      this.menuItemTargets.forEach((menuItem) => {
        useHover(this, { element: menuItem });
      });

      document.addEventListener('click', this.handleClickOutside.bind(this));
    } else {
      console.warn('Menu target is missing for "product-card" controller');
    }
  }

  disconnect() {
    if (this.hasMenuTarget) {
      document.removeEventListener('click', this.handleClickOutside.bind(this));
    }
  }

  handleClickOutside(event) {
    if (this.hasMenuTarget && !this.element.contains(event.target)) {
      if (this.menuTarget.classList.contains('hidden')) {
        return;
      }
      toggle(this.menuTarget);
    }
  }

  open() {
    if (this.hasMenuTarget) {
      toggle(this.menuTarget);
    }
  }

  mouseEnter(e) {
    e.target.classList.add('bg-gray-50');
  }

  mouseLeave(e) {
    e.target.classList.remove('bg-gray-50');
  }
}
