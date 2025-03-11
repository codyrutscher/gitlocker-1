// marketplace_browse.js

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
    const filterType = $(this).attr('name').replace('[]', '');
    const value = $(this).val();
    
    // Collect all checked checkboxes
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
});
