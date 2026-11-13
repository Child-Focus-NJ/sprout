// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails

// Dashboard charts: Chartkick helpers in the views draw with Chart.js.
import "chartkick"
import "Chart.bundle"
import "sms_templates"

// Textareas marked data-autogrow stretch to fit what's typed instead of scrolling inside a fixed box.
function autogrow(textarea) {
  textarea.style.height = "auto";
  const borders = textarea.offsetHeight - textarea.clientHeight;
  textarea.style.height = `${textarea.scrollHeight + borders}px`;
}

document.addEventListener("input", (event) => {
  if (event.target.matches("textarea[data-autogrow]")) autogrow(event.target);
});

document.querySelectorAll("textarea[data-autogrow]").forEach(autogrow);

// Long message bodies (Send Email / Send SMS history and the profile timeline)
// render as a one-line preview with a "Show more" control (_collapsible_message).
function initCollapsibleMessages() {
  document.querySelectorAll("[data-collapsible-message]").forEach((wrapper) => {
    const toggle = wrapper.querySelector("[data-collapsible-toggle]");
    if (!toggle || toggle.dataset.collapsibleBound === "true") return;
    toggle.dataset.collapsibleBound = "true";

    toggle.addEventListener("click", () => {
      const expanded = wrapper.classList.toggle("is-expanded");
      toggle.setAttribute("aria-expanded", String(expanded));
      toggle.textContent = expanded ? "Show less" : "Show more";
    });
  });
}

initCollapsibleMessages();
document.addEventListener("turbo:load", initCollapsibleMessages);
