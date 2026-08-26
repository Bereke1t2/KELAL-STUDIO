/**
 * Root of the Kelal Studio web management portal.
 *
 * Scope is deliberately narrow (PRD §4): Brand Kit configuration and admin
 * oversight. The composer lives on mobile — this portal never generates
 * content, and under the descope ladder (PRD §5.6) it collapses to
 * Admin + Brand Kit only, which is exactly what is built here.
 *
 * This is the foundation branch: routing, auth, and the real screens land in
 * the branches stacked on top of this one.
 */
export function App() {
  return (
    <main>
      <h1>Kelal Studio</h1>
      <p>Management portal</p>
    </main>
  );
}
