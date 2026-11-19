/**
 * The UDM mark. Mirrors `Mark` in the mobile app: the ministry's own cross and
 * open Bible, drawn in white on the tile gradient, so the console and the phone
 * show the same artwork rather than two drawings of it.
 */
export function BrandMark({ size = 36 }: { size?: number }) {
  return (
    <span
      className="brand-mark"
      style={{ width: size, height: size, flexBasis: size }}
      aria-hidden="true"
    >
      <img src="/brand/udm-mark-white.png" alt="" />
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
      <BrandMark size={size} />
    </div>
  );
}
