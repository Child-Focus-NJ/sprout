// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails

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
