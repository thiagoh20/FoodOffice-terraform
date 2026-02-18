export { COOKIE_NAME, ONE_YEAR_MS } from "@shared/const";

// Generate login URL at runtime so redirect URI reflects the current origin.
export const getLoginUrl = () => {
  const oauthPortalUrl = import.meta.env.VITE_OAUTH_PORTAL_URL;
  const appId = import.meta.env.VITE_APP_ID;
  
  // Validate required environment variables
  if (!oauthPortalUrl || typeof oauthPortalUrl !== 'string') {
    console.warn('VITE_OAUTH_PORTAL_URL is not configured. OAuth login is disabled.');
    // Return a fallback URL that won't cause errors
    return '/';
  }
  
  if (!appId || typeof appId !== 'string') {
    console.warn('VITE_APP_ID is not configured. OAuth login is disabled.');
    return '/';
  }
  
  const redirectUri = `${window.location.origin}/api/oauth/callback`;
  const state = btoa(redirectUri);

  try {
    // Detectar si es Auth0
    const isAuth0 = oauthPortalUrl.includes('auth0.com');
    
    if (isAuth0) {
      // Auth0 usa el formato estándar de OAuth2
      const url = new URL(`${oauthPortalUrl}/authorize`);
      url.searchParams.set("client_id", appId); // Auth0 usa client_id, no appId
      url.searchParams.set("redirect_uri", redirectUri); // Auth0 usa redirect_uri, no redirectUri
      url.searchParams.set("response_type", "code");
      url.searchParams.set("scope", "openid profile email");
      url.searchParams.set("state", state);
      
      return url.toString();
    } else {
      // Manus (comportamiento original)
      const url = new URL(`${oauthPortalUrl}/app-auth`);
      url.searchParams.set("appId", appId);
      url.searchParams.set("redirectUri", redirectUri);
      url.searchParams.set("state", state);
      url.searchParams.set("type", "signIn");

      return url.toString();
    }
  } catch (error) {
    console.error('Error constructing OAuth URL:', error);
    return '/';
  }
};
