$(document).ready(function () {
  const page = $('#filter-container').data('page');
  let url;
  if (page === 'browse') {
    url = '/marketplace/browse';
  } else if (page === 'featured') {
    url = '/marketplace/browse/featured';
  } else {
    url = window.location.pathname;
  }

  // Handle checkbox changes
  $('#categories-container, #languages-container').on("change", ".filter-checkbox", function () {
    const selectedFilters = {};
    
    // Get all checked categories
    const checkedCategories = $('input[name="filters[category][]"]:checked').map(function() {
      return $(this).val();
    }).get();
    
    if (checkedCategories.length > 0) {
      selectedFilters.category = checkedCategories;
    }

    // Get all checked languages
    const checkedLanguages = $('input[name="filters[language][]"]:checked').map(function() {
      return $(this).val();
    }).get();
    
    if (checkedLanguages.length > 0) {
      selectedFilters.language = checkedLanguages;
    }

    // Handle Upload Date
    const uploadDate = $('input[name="filters[upload_date]"]:checked').val();
    if (uploadDate) {
      selectedFilters.upload_date = uploadDate;
    }

    // Handle Alphabetical Order
    const alphabetical = $('input[name="filters[alphabetical]"]:checked').val();
    if (alphabetical) {
      selectedFilters.alphabetical = alphabetical;
    }

    // Update URL with selected filters
    const searchParams = new URLSearchParams(window.location.search);
    
    if (Object.keys(selectedFilters).length > 0) {
      searchParams.set('filters', JSON.stringify(selectedFilters));
    } else {
      searchParams.delete('filters');
    }
    searchParams.delete('page'); // Remove page parameter to correctly handle pagination

    const newUrl = `${url}?${searchParams.toString()}`;
    window.history.pushState({}, '', newUrl);

    // Fetch updated results via AJAX
    $.ajax({
      url: url,
      method: 'GET',
      data: searchParams.toString(),
      dataType: 'script',
      headers: {
        'X-Requested-With': 'XMLHttpRequest',
        'Accept': 'text/javascript'
      },
      success: function(response) {
        // DOM updates will be handled in the corresponding `index.js.erb`
      }
    });
  });

  // Handle "Load More" buttons for Categories and Languages
  document.body.addEventListener('click', function (event) {
    if (event.target.id === 'load-more-languages') {
      const container = document.getElementById('languages-container');
      const offset = container.children.length;
      const limit = 5;
      const urlParams = new URLSearchParams(window.location.search);

      fetch(`/marketplace/languages/load_more?offset=${offset}&limit=${limit}`)
        .then((response) => response.json())
        .then((data) => {
          if (data.languages.length < limit) {
            document.getElementById('load-more-languages').style.display = 'none';
          }

          data.languages.forEach(function (language) {
            const languageDiv = document.createElement('div');
            languageDiv.classList.add('flex', 'items-center');

            const checkbox = document.createElement('input');
            checkbox.type = 'checkbox';
            checkbox.name = 'filters[language][]';
            checkbox.value = language.id;
            checkbox.id = `language-${language.id}`;
            checkbox.classList.add('h-4', 'w-4', 'rounded', 'border-gray-300', 'text-indigo-600', 'focus:ring-indigo-500', 'filter-checkbox');
            
            const label = document.createElement('label');
            label.htmlFor = `language-${language.id}`;
            label.textContent = language.name;
            label.classList.add('ml-3', 'text-sm', 'text-gray-600');

            languageDiv.appendChild(checkbox);
            languageDiv.appendChild(label);
            container.appendChild(languageDiv);
          });
        });
    } else if (event.target.id === 'load-more-categories') {
      const container = document.getElementById('categories-container');
      const offset = container.children.length;
      const limit = 5;
      const urlParams = new URLSearchParams(window.location.search);

      fetch(`/marketplace/categories/load_more?offset=${offset}&limit=${limit}`)
        .then((response) => response.json())
        .then((data) => {
          if (data.categories.length < limit) {
            document.getElementById('load-more-categories').style.display = 'none';
          }

          data.categories.forEach(function (category) {
            const categoryDiv = document.createElement('div');
            categoryDiv.classList.add('flex', 'items-center');

            const checkbox = document.createElement('input');
            checkbox.type = 'checkbox';
            checkbox.name = 'filters[category][]';
            checkbox.value = category.id;
            checkbox.id = `category-${category.id}`;
            checkbox.classList.add('h-4', 'w-4', 'rounded', 'border-gray-300', 'text-indigo-600', 'focus:ring-indigo-500', 'filter-checkbox');
            
            const label = document.createElement('label');
            label.htmlFor = `category-${category.id}`;
            label.textContent = category.name;
            label.classList.add('ml-3', 'text-sm', 'text-gray-600');

            categoryDiv.appendChild(checkbox);
            categoryDiv.appendChild(label);
            container.appendChild(categoryDiv);
          });
        });
    }
  });
});
