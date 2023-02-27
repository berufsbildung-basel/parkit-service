// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "loadicons/main"
import "parking-spot-status/main"

document.addEventListener("turbo:load", function () {
  loadIcons('/spectrum-css-icons.svg');
  loadIcons('/spectrum-workflow-icons.svg');

  const sideBar = document.querySelector('#site-sidebar');
  const overlay = document.querySelector('#site-overlay');
  const sidebarMQL = window.matchMedia('(max-width: 960px)');

  function handleSidebarMQLChange() {
    if (!sidebarMQL.matches) {
      // Get rid of the overlay if we resize while the sidebar is open
      hideSideBar();
    }
  }

  sidebarMQL.addListener(handleSidebarMQLChange);

  handleSidebarMQLChange();

  function showSideBar() {
    if (sidebarMQL.matches) {
      overlay.addEventListener('click', hideSideBar);
      sideBar.classList.add('is-open');
      overlay.classList.add('is-open');
    }
  }

  function hideSideBar() {
    overlay.removeEventListener('click', hideSideBar);
    overlay.classList.remove('is-open');
    if (sideBar) {
      sideBar.classList.remove('is-open');
    }
    if (window.siteSearch) {
      window.siteSearch.hideResults();
    }
  }

  document.querySelector('#site-menu').addEventListener('click', function (event) {
    if (sideBar.classList.contains('is-open')) {
      hideSideBar();
    } else {
      showSideBar();
    }
  });

  document.querySelectorAll('.spectrum-Toast button').forEach((el) => {
    el.addEventListener('click', function (event) {
      el.parentElement?.parentElement?.remove();
    });
  });
});
