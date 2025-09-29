/* global PublicKeyCredential */
import csrfToken from './CsrfTokenHelper';

const RailsWebauthn = (function () {
  let basePath = '/api/v1/webauthn'; // default, can be overridden
  let getCsrfToken = csrfToken;

  function base64UrlToUint8Array(base64UrlString) {
    const padding = (4 - (base64UrlString.length % 4)) % 4;
    const base64 = base64UrlString.replace(/-/g, '+').replace(/_/g, '/').padEnd(base64UrlString.length + padding, '=');
    const binary = atob(base64);
    return Uint8Array.from(binary, (c) => c.charCodeAt(0));
  }

  function arrayBufferToBase64Url(buffer) {
    const binary = String.fromCharCode(...new Uint8Array(buffer));
    const base64 = btoa(binary);
    return base64.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  }

  function configure({ apiBasePath, csrfTokenFunction }) {
    if (apiBasePath) basePath = apiBasePath;
    if (csrfTokenFunction) getCsrfToken = csrfTokenFunction;
  }

  async function isPlatformAuthenticatorAvailable() {
    if (!window.PublicKeyCredential) return false;
    try {
      return await PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable();
    } catch (err) {
      console.warn('Error checking authenticator availability:', err);
      return false;
    }
  }

  async function hasAvailableCredentials(allowCredentials = null) {
    if (!window.PublicKeyCredential || !allowCredentials || allowCredentials.length === 0) {
      return false;
    }
    try {
      return await PublicKeyCredential.isConditionalMediationAvailable();
    } catch (err) {
      console.warn('Error checking credential availability:', err);
      return false;
    }
  }

  // Generic fetch wrapper
  async function fetchJson(url, options = {}) {
    const opts = {
      credentials: 'include',
      headers: {
        'Content-Type': 'application/json',
        'X-Requested-With': 'XMLHttpRequest',
        'X-CSRF-TOKEN': getCsrfToken(),
        ...(options.headers || {}),
      },
      ...options,
    };
    const resp = await fetch(`${basePath}${url}`, opts);
    if (!resp.ok) throw new Error(`Request failed: ${resp.status}`);
    const contentType = resp.headers.get('content-type');
    if (contentType && contentType.includes('application/json')) return resp.json();
    return resp.text();
  }

  // --- Public API functions ---

  async function checkUserRegistered(email) {
    const data = await fetchJson('/check_registered', { method: 'POST', body: JSON.stringify({ email }) });
    const availableHere = await isPlatformAuthenticatorAvailable();
    const hasCredentialsHere = data.allowCredentials
      ? await hasAvailableCredentials(data.allowCredentials)
      : false;
    return { ...data, availableHere, hasCredentialsHere, canUsePasskey: availableHere && (hasCredentialsHere || !data.registered) };
  }

  async function registerPasskey({ nickname = null } = {}) {
    const { options } = await fetchJson('/begin_registration', { method: 'POST' });
    options.challenge = base64UrlToUint8Array(options.challenge);
    options.user.id = base64UrlToUint8Array(options.user.id);
    if (options.excludeCredentials) {
      options.excludeCredentials = options.excludeCredentials.map((cred) => ({ ...cred, id: base64UrlToUint8Array(cred.id) }));
    }

    if (!(await isPlatformAuthenticatorAvailable())) throw new Error('No platform authenticator available');

    const credential = await navigator.credentials.create({ publicKey: options });
    const credentialData = {
      id: credential.id,
      type: credential.type,
      rawId: arrayBufferToBase64Url(credential.rawId),
      response: {
        attestationObject: arrayBufferToBase64Url(credential.response.attestationObject),
        clientDataJSON: arrayBufferToBase64Url(credential.response.clientDataJSON),
      },
    };
    return fetchJson('/verify_registration', { method: 'POST', body: JSON.stringify({ credential: credentialData, nickname }) });
  }

  async function authenticateWithPasskey({ email, useConditionalUI = false }) {
    const { options } = await fetchJson('/begin_authentication', { method: 'POST', body: JSON.stringify({ email }) });
    options.challenge = base64UrlToUint8Array(options.challenge);
    if (options.allowCredentials) {
      options.allowCredentials = options.allowCredentials.map((cred) => ({ ...cred, id: base64UrlToUint8Array(cred.id) }));
    }

    const requestOptions = { publicKey: options };
    if (useConditionalUI && PublicKeyCredential.isConditionalMediationAvailable) {
      try {
        if (await PublicKeyCredential.isConditionalMediationAvailable()) requestOptions.mediation = 'conditional';
      } catch (_) {}
    }

    const credential = await navigator.credentials.get(requestOptions);
    const credentialData = {
      id: credential.id,
      type: credential.type,
      rawId: arrayBufferToBase64Url(credential.rawId),
      response: {
        authenticatorData: arrayBufferToBase64Url(credential.response.authenticatorData),
        clientDataJSON: arrayBufferToBase64Url(credential.response.clientDataJSON),
        signature: arrayBufferToBase64Url(credential.response.signature),
        userHandle: credential.response.userHandle ? arrayBufferToBase64Url(credential.response.userHandle) : null,
      },
    };

    return fetchJson('/verify_authentication', { method: 'POST', body: JSON.stringify({ credential: credentialData }) });
  }

  async function getUserPasskeys() {
    return fetchJson('/credentials', { method: 'GET' });
  }

  async function updatePasskey(id, { nickname }) {
    return fetchJson(`/credentials/${id}`, { method: 'PATCH', body: JSON.stringify({ credential: { nickname } }) });
  }

  async function deletePasskey(id) {
    return fetchJson(`/credentials/${id}`, { method: 'DELETE' });
  }

  async function getPasskeySupport() {
    const support = {
      webAuthnSupported: !!window.PublicKeyCredential,
      platformAuthenticator: false,
      conditionalUI: false,
      userAgent: navigator.userAgent,
      isChrome: /Chrome/i.test(navigator.userAgent) && !/Edge/i.test(navigator.userAgent),
      isFirefox: /Firefox/i.test(navigator.userAgent),
      isSafari: /Safari/i.test(navigator.userAgent) && !/Chrome/i.test(navigator.userAgent),
    };

    if (support.webAuthnSupported) {
      try { support.platformAuthenticator = await PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable(); } catch (_) {}
      try { support.conditionalUI = await PublicKeyCredential.isConditionalMediationAvailable(); } catch (_) {}
    }

    return support;
  }

  return {
    configure,
    checkUserRegistered,
    registerPasskey,
    authenticateWithPasskey,
    getUserPasskeys,
    updatePasskey,
    deletePasskey,
    getPasskeySupport,
  };
})();

export default RailsWebauthn;
