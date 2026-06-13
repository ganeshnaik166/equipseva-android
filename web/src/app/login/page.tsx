import { LoginForm } from "./LoginForm";

export const metadata = { title: "Sign in — EquipSeva Founder Console" };

export default function LoginPage() {
  return (
    <div className="mx-auto mt-16 max-w-md">
      <h1 className="text-xl font-semibold">Sign in</h1>
      <p className="mt-1 text-sm text-[var(--color-muted)]">
        Magic link to your founder email. Non-founder emails are rejected
        server-side by every RPC, even if this client gate is bypassed.
      </p>
      <div className="mt-6">
        <LoginForm />
      </div>
    </div>
  );
}
