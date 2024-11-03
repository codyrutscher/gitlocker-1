import { Controller } from '@hotwired/stimulus';

const buttonClasses = {
  'active': ['!border-white', '!text-white'],
  'inactive': ['border-transparent', 'text-black', 'hover:border-black', '!hover:text-black']
};

// Connects to data-controller="product-tabs"
export default class extends Controller {
  static targets = ['button', 'panel'];

  toggleTab(e) {
    const tabName = e.target.id.replace('tab-', '');

    this.buttonTargets.forEach((button) => {
      if (button.id === e.target.id) {
        button.classList.add(...buttonClasses['active']);
        button.classList.remove(...buttonClasses['inactive']);
      } else {
        button.classList.add(...buttonClasses['inactive']);
        button.classList.remove(...buttonClasses['active']);
      }
    });

    this.panelTargets.forEach((panel) => {
      if (panel.id === `panel-${tabName}`) {
        panel.classList.remove('hidden');
      } else {
        panel.classList.add('hidden');
      }
    });
  }
}
