import { SheetService } from './sheetService';

export class SessionSecurity {
  // 12-Hour session verification TTL to prevent redundant Google Sheet API hits
  static readonly VERIFY_TTL_MS = 12 * 60 * 60 * 1000;

  /**
   * Verifies if the current user session is still active and valid in Google Sheets
   * Protected with 12-hour local caching to save API quota
   */
  static async verifySession(
    onForceLogout: (message: string) => void,
    force = false
  ): Promise<boolean> {
    const mobile = localStorage.getItem('user_phone') || '';
    if (!mobile) return true;

    const lastVerifyKey = 'session_last_verify_timestamp';
    const lastVerify = localStorage.getItem(lastVerifyKey);
    const now = Date.now();

    // If verified within the last 12 hours and not forced, bypass network call!
    if (!force && lastVerify && (now - new Date(lastVerify).getTime() < this.VERIFY_TTL_MS)) {
      const cachedStatus = (localStorage.getItem('user_status') || 'ACTIVE').toUpperCase();
      if (cachedStatus === 'DEACTIVE' || cachedStatus === 'BANNED' || cachedStatus === 'BLOCKED') {
        localStorage.clear();
        onForceLogout("🔒 ACCOUNT SUSPENDED: Your access has been revoked by Admin. Please contact Purix Academy support.");
        return false;
      }
      return true;
    }

    try {
      const usersData = await SheetService.fetchSheetData('User ID', force);
      const cleanPhone = mobile.trim();

      for (const row of usersData) {
        const sheetPhone = String(row['Phone'] || row['phone'] || '').trim();

        if (sheetPhone === cleanPhone) {
          const accountStatus = String(row['Status'] || 'ACTIVE').trim().toUpperCase();
          const planStatus = String(row['Plan'] || 'FREE').trim().toUpperCase();

          // 1. Suspension check
          if (accountStatus === 'DEACTIVE' || accountStatus === 'BANNED' || accountStatus === 'BLOCKED') {
            localStorage.clear();
            onForceLogout("🔒 ACCOUNT SUSPENDED: Your access has been revoked by Admin. Please contact Purix Academy support.");
            return false;
          }

          // 2. Update local plan and status
          if (planStatus) {
            localStorage.setItem('user_sub', planStatus);
          }
          localStorage.setItem('user_status', accountStatus);
          localStorage.setItem(lastVerifyKey, new Date().toISOString());
          break;
        }
      }
      localStorage.setItem(lastVerifyKey, new Date().toISOString());
    } catch (e) {
      console.warn("Session verification warning:", e);
    }

    return true;
  }
}
