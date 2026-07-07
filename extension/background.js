// background.js — IGProspect service worker
// Handles cross-origin API requests to avoid CORS issues from content script

chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {

  if (msg.type === 'agendor_create_person') {
    const { token, person } = msg;

    fetch('https://api.agendor.com.br/v3/people', {
      method: 'POST',
      headers: {
        'Authorization': `Token ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        name: person.name,
        contact: {
          mobile: person.phone || '',
          instagram: person.instagram || '',
        },
        description: [
          person.niche    ? `Nicho: ${person.niche}`          : '',
          person.mutual   ? `Amigos em comum: ${person.mutual}`: '',
          person.notes    ? `Obs: ${person.notes}`             : '',
          person.profileUrl ? `Perfil: ${person.profileUrl}`  : '',
        ].filter(Boolean).join('\n'),
      }),
    })
      .then(async r => {
        const data = await r.json().catch(() => ({}));
        sendResponse({ ok: r.ok, status: r.status, data });
      })
      .catch(err => sendResponse({ ok: false, error: err.message }));

    return true; // keep message channel open for async response
  }

});
