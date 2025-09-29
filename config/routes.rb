RailsWebauthn::Engine.routes.draw do
  post   "webauthn/check_registered",     to: "webauthn_credentials#check_registered"
  post   "webauthn/begin_registration",   to: "webauthn_credentials#begin_registration"
  post   "webauthn/verify_registration",  to: "webauthn_credentials#verify_registration"
  post   "webauthn/begin_authentication", to: "webauthn_credentials#begin_authentication"
  post   "webauthn/verify_authentication",to: "webauthn_credentials#verify_authentication"
  get    "webauthn/credentials",          to: "webauthn_credentials#index"
  patch  "webauthn/credentials/:id",      to: "webauthn_credentials#update"
  delete "webauthn/credentials/:id",      to: "webauthn_credentials#destroy"
end