import { useEffect, useState } from 'react';

/**
 * Turn a `File` into an object URL for the session, revoking it when the file
 * changes or the component unmounts. Used only for an unsaved local logo
 * preview — the server has no GET route for a saved asset, so a picked file is
 * the one moment the portal can actually show the image.
 */
export function useObjectUrl(file: File | null): string | null {
  const [url, setUrl] = useState<string | null>(null);

  useEffect(() => {
    if (!file) {
      setUrl(null);
      return;
    }
    const next = URL.createObjectURL(file);
    setUrl(next);
    return () => URL.revokeObjectURL(next);
  }, [file]);

  return url;
}
