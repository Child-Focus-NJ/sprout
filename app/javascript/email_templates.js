// An email template fills in an editable draft of the subject and message
const pendingLoads = new WeakMap();
// The template last filled in and the text it gave, so a draft is only treated as staff's own once they edit it
const filledDrafts = new WeakMap();

function draftFields(form) {
  return [ form.querySelector("[data-email-subject]"), form.querySelector("[data-email-message]") ];
}

function draftText(form) {
  return draftFields(form).map((field) => field.value).join("\n");
}

function loading(form, active) {
  form.setAttribute("aria-busy", String(active));
  const send = form.querySelector("button[type='submit']");
  send.disabled = active || "sendDisabled" in send.dataset;
}

function cancelLoad(form) {
  pendingLoads.get(form)?.abort();
  pendingLoads.delete(form);
  loading(form, false);
}

function clearPicker(form, statusText) {
  form.querySelector("[data-email-template-picker]").value = "";
  form.querySelector("[data-email-template-status]").textContent = statusText;
  filledDrafts.delete(form);
}

document.addEventListener("email-recipient-changed", (event) => {
  const form = event.target;
  cancelLoad(form);
  clearPicker(form, "");
});

document.addEventListener("input", (event) => {
  if (!event.target.matches("[data-email-subject], [data-email-message]")) return;
  const form = event.target.form;
  if (!pendingLoads.has(form)) return;
  cancelLoad(form);
  clearPicker(form, "Template loading canceled. Your draft was kept.");
});

document.addEventListener("change", async (event) => {
  const picker = event.target.closest("[data-email-template-picker]");
  if (!picker) return;
  const form = picker.form;
  const status = form.querySelector("[data-email-template-status]");
  cancelLoad(form);
  status.textContent = "";
  if (!picker.value) { // Switching to a custom email keeps the current draft.
    filledDrafts.delete(form);
    return;
  }

  // Ask before a template replaces something staff wrote themselves
  const filled = filledDrafts.get(form);
  const ownDraft = draftFields(form).some((field) => field.value.trim()) && draftText(form) !== filled?.text;
  if (ownDraft && !window.confirm("Replace your draft with this template?")) {
    picker.value = filled?.templateId || "";
    return;
  }

  const controller = new AbortController();
  pendingLoads.set(form, controller);
  loading(form, true);
  status.textContent = "Loading template…";
  try {
    const url = new URL(form.dataset.emailTemplateUrl, window.location.origin);
    url.searchParams.set("template_id", picker.value);
    const response = await fetch(url, { headers: { Accept: "application/json" }, signal: controller.signal });
    if (!response.ok || response.redirected) throw new Error("Template unavailable");
    const result = await response.json();
    if (typeof result.subject !== "string" || typeof result.body !== "string") throw new Error("Invalid template");
    if (pendingLoads.get(form) !== controller) return;
    pendingLoads.delete(form);
    const [ subject, message ] = draftFields(form);
    subject.value = result.subject;
    message.value = result.body;
    [ subject, message ].forEach((field) => field.dispatchEvent(new Event("input", { bubbles: true })));
    filledDrafts.set(form, { templateId: picker.value, text: draftText(form) });
    status.textContent = "Template loaded. Review and edit the email before sending.";
  } catch (error) {
    if (error.name === "AbortError" || pendingLoads.get(form) !== controller) return;
    picker.value = filled?.templateId || "";
    status.textContent = "Could not load this template. Your draft was kept. Try again or write a custom email.";
  } finally {
    if (pendingLoads.get(form) === controller) pendingLoads.delete(form);
    if (!pendingLoads.has(form)) loading(form, false);
  }
});
