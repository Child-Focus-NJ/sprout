// A template starts an editable draft. Only the Send form calls the messaging provider.
const pendingLoads = new WeakMap();

function loading(form, active) {
  form.setAttribute("aria-busy", String(active));
  form.querySelector("button[type='submit']").disabled = active;
}

function cancelLoad(form) {
  pendingLoads.get(form)?.abort();
  pendingLoads.delete(form);
  loading(form, false);
}

document.addEventListener("sms-recipient-changed", (event) => {
  const form = event.target;
  cancelLoad(form);
  form.querySelector("[data-sms-template-picker]").value = "";
  form.querySelector("[data-sms-template-status]").textContent = "";
});

document.addEventListener("input", (event) => {
  if (!event.target.matches("[data-sms-message]")) return;
  const form = event.target.form;
  if (!pendingLoads.has(form)) return;
  cancelLoad(form);
  form.querySelector("[data-sms-template-picker]").value = "";
  form.querySelector("[data-sms-template-status]").textContent = "Template loading canceled. Your draft was kept.";
});

document.addEventListener("change", async (event) => {
  const picker = event.target.closest("[data-sms-template-picker]");
  if (!picker) return;
  const form = picker.form;
  const message = form.querySelector("[data-sms-message]");
  const status = form.querySelector("[data-sms-template-status]");
  cancelLoad(form);
  status.textContent = "";
  if (!picker.value) return; // Switching to Custom message keeps the current draft.

  if (!form.dataset.smsTemplateUrl) {
    message.value = picker.selectedOptions[0].dataset.body;
    message.dispatchEvent(new Event("input", { bubbles: true }));
    status.textContent = "Template loaded. Merge fields will be filled in for each recipient.";
    return;
  }

  const controller = new AbortController();
  pendingLoads.set(form, controller);
  loading(form, true);
  status.textContent = "Loading template…";
  try {
    const url = new URL(form.dataset.smsTemplateUrl, window.location.origin);
    url.searchParams.set("template_id", picker.value);
    const response = await fetch(url, { headers: { Accept: "application/json" }, signal: controller.signal });
    if (!response.ok || response.redirected) throw new Error("Template unavailable");
    const result = await response.json();
    if (typeof result.body !== "string") throw new Error("Invalid template");
    if (pendingLoads.get(form) !== controller) return;
    pendingLoads.delete(form);
    message.value = result.body;
    message.dispatchEvent(new Event("input", { bubbles: true }));
    status.textContent = "Template loaded. Review and edit the message before sending.";
  } catch (error) {
    if (error.name === "AbortError" || pendingLoads.get(form) !== controller) return;
    picker.value = "";
    status.textContent = "Could not load this template. Your draft was kept. Try again or write a custom message.";
  } finally {
    if (pendingLoads.get(form) === controller) pendingLoads.delete(form);
    if (!pendingLoads.has(form)) loading(form, false);
  }
});
