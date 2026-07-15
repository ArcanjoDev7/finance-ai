export function downloadUrl(): URL | null {
  const rawUrl = Deno.env.get('DOWNLOAD_PUBLIC_URL');
  if (rawUrl === undefined || rawUrl.length === 0) return null;
  try {
    const url = new URL(rawUrl);
    return url.protocol === 'https:' ? url : null;
  } on TypeError {
    return null;
  }
}
