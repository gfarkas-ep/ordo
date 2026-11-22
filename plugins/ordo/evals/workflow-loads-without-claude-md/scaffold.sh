#!/bin/bash
mkdir -p src/signup
cat > src/signup/errors.js <<'JS'
export const SIGNUP_ERRORS = {
  EMAIL_TAKEN: "Error: email already exists.",
  EMAIL_INVALID: "Invalid email.",
  PASSWORD_SHORT: "Password too short (min 8).",
  TERMS: "You must accept the terms.",
};
JS
cat > src/signup/SignupForm.jsx <<'JS'
import { SIGNUP_ERRORS } from "./errors";

export function SignupForm({ errors, onSubmit }) {
  return (
    <form onSubmit={onSubmit}>
      {errors.length > 0 && (
        <div className="error-box">
          {errors.map((code) => <p key={code}>{SIGNUP_ERRORS[code]}</p>)}
        </div>
      )}
      <input name="email" type="email" />
      <input name="password" type="password" />
      <label><input name="terms" type="checkbox" /> I accept the terms</label>
      <button type="submit">Sign up</button>
    </form>
  );
}
JS
