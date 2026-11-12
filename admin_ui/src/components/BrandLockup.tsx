/**
 * The UDM mark. Mirrors `Mark` in the mobile app: a rounded tile on the hero
 * gradient with an open-book glyph, so the console and the phone agree on what
 * the brand looks like without shipping a binary logo to either.
 */
export function BrandMark({ size = 36, id = "udm-brand-mark" }: { size?: number; id?: string }) {
  return (
    <span className="brand-mark" aria-hidden="true">
      <svg width={size} height={size} viewBox="0 0 36 36" role="presentation">
        <defs>
          <linearGradient id={id} x1="0" y1="0" x2="1" y2="1">
            <stop offset="0" stopColor="#2E8FD0" />
            <stop offset="0.52" stopColor="#1769AA" />
            <stop offset="1" stopColor="#123B63" />
          </linearGradient>
        </defs>
        <rect width="36" height="36" rx="11.5" fill={`url(#${id})`} />
        <path
          d="M18 12.4c-2.1-1.4-4.4-2-6.8-1.9v13c2.4-.1 4.7.6 6.8 2 2.1-1.4 4.4-2.1 6.8-2v-13c-2.4-.1-4.7.5-6.8 1.9Zm0 0v13.1"
          fill="none"
          stroke="#FFFFFF"
          strokeWidth="1.9"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
      </svg>
    </span>
  );
}

export function BrandLockup({ compact = false }: { compact?: boolean }) {
  return (
    <div className="brand-lockup">
      <strong>UDM</strong>
      {!compact && <small>MINISTRY CONSOLE</small>}
    </div>
  );
}

export function BrandTile({ size = 36 }: { size?: number }) {
  return (
    <div className="auth-brand-mark" aria-hidden="true">
      <BrandMark size={size} id={`udm-brand-mark-${size}`} />
    </div>
  );
}
