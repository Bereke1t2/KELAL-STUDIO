/** Title + optional subtitle block shared by the auth screens. */
export function AuthHeading({
  title,
  subtitle,
}: {
  title: string;
  subtitle?: string;
}) {
  return (
    <div className="flex flex-col gap-1">
      <h1 className="text-title text-ink">{title}</h1>
      {subtitle ? (
        <p className="text-body-sm text-ink-secondary">{subtitle}</p>
      ) : null}
    </div>
  );
}
