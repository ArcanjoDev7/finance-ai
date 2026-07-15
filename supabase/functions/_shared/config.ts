export interface AppConfig {
  environment: string;
  appVersion: string;
  downloadPublicUrl?: string;
  webAppUrl?: string;
}

export function getConfig(): AppConfig {
  return {
    environment: Deno.env.get('ENVIRONMENT') ?? 'development',
    appVersion: Deno.env.get('APP_VERSION') ?? '1.0.0',
    downloadPublicUrl: Deno.env.get('DOWNLOAD_PUBLIC_URL'),
    webAppUrl: Deno.env.get('WEB_APP_URL'),
  };
}
