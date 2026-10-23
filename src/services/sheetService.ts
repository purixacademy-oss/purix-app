import { SheetRow } from '../types';

export class SheetService {
  // Google Apps Script Web App Endpoint
  static readonly SCRIPT_URL = "https://script.google.com/macros/s/AKfycbyMCVQQB7BkbRxxvociPZL56LWryYz7zSEF3hKxxK6zxDsApHXE_VEoRsTS0GmU7VDMSA/exec";

  // 12-Hour Cache Duration in Milliseconds (12 * 60 * 60 * 1000 = 43,200,000 ms)
  static readonly CACHE_TTL_MS = 12 * 60 * 60 * 1000;

  // In-Flight Promise Registry to prevent duplicate parallel network calls
  private static inFlightRequests: Map<string, Promise<SheetRow[]>> = new Map();

  /**
   * Detect client device information
   */
  static getDeviceInfo(): string {
    if (typeof window === 'undefined' || !window.navigator) {
      return "Web Browser Client";
    }

    const ua = navigator.userAgent;
    let device = "Web Browser";

    if (/android/i.test(ua)) {
      device = "Android Web";
      const match = ua.match(/Android\s([0-9.]+);?\s?([^;)]*)/);
      if (match && match[2]) {
        device = `Android (${match[2].trim()})`;
      }
    } else if (/iPad|iPhone|iPod/.test(ua)) {
      device = "iOS Web";
    } else if (/Macintosh|Mac OS X/.test(ua)) {
      device = "macOS Web";
    } else if (/Windows/.test(ua)) {
      device = "Windows PC Web";
    } else if (/Linux/.test(ua)) {
      device = "Linux Web";
    }

    return device;
  }

  /**
   * Purix ID Generator matching Flutter random 5-char code
   */
  static generatePurixId(): string {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    let result = '';
    for (let i = 0; i < 5; i++) {
      result += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return `PRX-${result}`;
  }

  /**
   * Checks whether the specified sheet data is already cached and valid within 12 hours
   */
  static isCacheValid(sheetName: string): boolean {
    const cacheKey = `cache_data_${sheetName}`;
    const timeKey = `cache_time_${sheetName}`;

    try {
      const cachedString = localStorage.getItem(cacheKey);
      const cachedTimeStr = localStorage.getItem(timeKey);

      if (cachedString && cachedTimeStr) {
        const cachedTime = new Date(cachedTimeStr).getTime();
        const now = Date.now();
        if (now - cachedTime < this.CACHE_TTL_MS) {
          return true;
        }
      }
    } catch (e) {
      // ignore
    }
    return false;
  }

  /**
   * Safely saves data to localStorage, pruning obsolete items if quota exceeded
   */
  private static saveToLocalStorage(key: string, value: string): void {
    try {
      localStorage.setItem(key, value);
    } catch (e) {
      console.warn("Storage quota warning, attempting cleanup...", e);
      try {
        // Prune older temporary cache keys
        const now = Date.now();
        for (let i = 0; i < localStorage.length; i++) {
          const k = localStorage.key(i);
          if (k && k.startsWith('cache_time_')) {
            const timeVal = localStorage.getItem(k);
            if (timeVal && now - new Date(timeVal).getTime() > this.CACHE_TTL_MS) {
              const dataKey = k.replace('cache_time_', 'cache_data_');
              localStorage.removeItem(k);
              localStorage.removeItem(dataKey);
            }
          }
        }
        localStorage.setItem(key, value);
      } catch (err) {
        console.error("Could not write to localStorage:", err);
      }
    }
  }

  /**
   * Fetches data from specified Google Sheet tab with strict 12-hour localStorage caching
   * & In-Flight Promise deduplication to protect Google Apps Script quota
   */
  static async fetchSheetData(sheetName: string, forceRefresh = false): Promise<SheetRow[]> {
    const cacheKey = `cache_data_${sheetName}`;
    const timeKey = `cache_time_${sheetName}`;

    // 1. Check 12-Hour Cache First: If valid, NO API call will be made!
    if (!forceRefresh) {
      try {
        const cachedString = localStorage.getItem(cacheKey);
        const cachedTimeStr = localStorage.getItem(timeKey);

        if (cachedString && cachedTimeStr) {
          const cachedTime = new Date(cachedTimeStr).getTime();
          const now = Date.now();

          if (now - cachedTime < this.CACHE_TTL_MS) {
            const parsed = JSON.parse(cachedString);
            if (Array.isArray(parsed) && parsed.length > 0) {
              return parsed as SheetRow[];
            }
          }
        }
      } catch (err) {
        console.warn(`Cache read warning for ${sheetName}:`, err);
      }
    }

    // 2. In-Flight Request Deduplication: Avoid duplicate parallel calls for same sheet
    if (this.inFlightRequests.has(sheetName)) {
      return this.inFlightRequests.get(sheetName)!;
    }

    // 3. Initiate single network fetch
    const fetchPromise = (async () => {
      try {
        const url = `${this.SCRIPT_URL}?sheet=${encodeURIComponent(sheetName)}`;
        const response = await fetch(url, {
          method: 'GET',
          headers: {
            'Accept': 'application/json',
          },
        });

        if (!response.ok) {
          throw new Error(`HTTP error ${response.status}`);
        }

        const data = await response.json();
        if (Array.isArray(data)) {
          // Save in 12-hour cache
          this.saveToLocalStorage(cacheKey, JSON.stringify(data));
          this.saveToLocalStorage(timeKey, new Date().toISOString());
          return data as SheetRow[];
        }
        return [];
      } catch (error) {
        console.error(`Error fetching sheet [${sheetName}]:`, error);
        
        // Offline Fallback: If network failed, serve existing local data even if older than 12h
        try {
          const fallbackCached = localStorage.getItem(cacheKey);
          if (fallbackCached) {
            return JSON.parse(fallbackCached) as SheetRow[];
          }
        } catch (e) {
          // ignore
        }
        return [];
      } finally {
        this.inFlightRequests.delete(sheetName);
      }
    })();

    this.inFlightRequests.set(sheetName, fetchPromise);
    return fetchPromise;
  }

  /**
   * Pre-loads and caches all MCQ and Study data for the user's class in 1 single pass
   * Once called, all quizzes, chapters, and notes run 100% offline from localStorage for 12 hours.
   */
  static async preloadClassContent(selectedClass: string, force = false): Promise<{ mcqCount: number; notesCount: number }> {
    let prefix = "8th";
    if (selectedClass.includes("9")) prefix = "9th";
    else if (selectedClass.includes("10") || selectedClass.toLowerCase().includes("board")) prefix = "10th";

    const mcqSheet = `${prefix} MCQ`;
    const notesSheet = `${prefix} Notes`;

    // If both sheets are already cached within 12 hours and not forced, do 0 network calls!
    if (!force && this.isCacheValid(mcqSheet) && this.isCacheValid(notesSheet)) {
      const cachedMcq = JSON.parse(localStorage.getItem(`cache_data_${mcqSheet}`) || '[]');
      const cachedNotes = JSON.parse(localStorage.getItem(`cache_data_${notesSheet}`) || '[]');
      return { mcqCount: cachedMcq.length, notesCount: cachedNotes.length };
    }

    try {
      const [mcqData, notesData] = await Promise.all([
        this.fetchSheetData(mcqSheet, force),
        this.fetchSheetData(notesSheet, force).catch(() => [] as SheetRow[]),
      ]);

      return { mcqCount: mcqData.length, notesCount: notesData.length };
    } catch (e) {
      console.warn("Preload content warning:", e);
      return { mcqCount: 0, notesCount: 0 };
    }
  }

  /**
   * Syncs user profile with Google Sheet with smart throttling (12-hour TTL)
   * Avoids hitting Google Apps Script on every single page load
   */
  static async syncUserProfile(params: {
    name: string;
    phone: string;
    email: string;
    selectedClass: string;
    purixId?: string;
    deviceInfo?: string;
    force?: boolean;
  }): Promise<{ plan: string; status: string; uniqueId: string }> {
    const finalPurixId = params.purixId || localStorage.getItem('user_uid') || this.generatePurixId();
    const finalDevice = params.deviceInfo || this.getDeviceInfo();
    const currentDateTime = new Date().toISOString().substring(0, 16).replace('T', ' ');

    const lastSyncKey = 'user_last_sync_timestamp';
    const lastSync = localStorage.getItem(lastSyncKey);
    const now = Date.now();
    const isCacheExpired = !lastSync || (now - new Date(lastSync).getTime() > this.CACHE_TTL_MS);

    // If not forced and user was synced recently within 12 hours, use local verified data
    if (!params.force && !isCacheExpired && localStorage.getItem('user_sub')) {
      return {
        plan: localStorage.getItem('user_sub') || 'FREE',
        status: localStorage.getItem('user_status') || 'ACTIVE',
        uniqueId: finalPurixId,
      };
    }

    try {
      // 1. Post registration / login ping to Google Apps Script
      await fetch(this.SCRIPT_URL, {
        method: 'POST',
        headers: {
          'Content-Type': 'text/plain;charset=utf-8',
        },
        body: JSON.stringify({
          name: params.name,
          phone: params.phone,
          email: params.email,
          purix_id: finalPurixId,
          selected_class: params.selectedClass,
          device_info: finalDevice,
          login_time: currentDateTime,
        }),
      });
    } catch (e) {
      console.warn("Sync post warning:", e);
    }

    // 2. Fetch User ID sheet to check live Plan and Status
    try {
      // Use cached User ID if within 12 hours unless forced
      const usersData = await this.fetchSheetData('User ID', params.force || isCacheExpired);
      const cleanPhone = params.phone.trim();

      for (const row of usersData) {
        const rowPhone = String(row['Phone'] || row['phone'] || '').trim();
        if (rowPhone === cleanPhone) {
          const plan = String(row['Plan'] || 'FREE').trim().toUpperCase();
          const status = String(row['Status'] || 'ACTIVE').trim().toUpperCase();
          const uid = String(row['Unique ID'] || row['Unique ID '] || finalPurixId).trim();

          localStorage.setItem('user_sub', plan);
          localStorage.setItem('user_status', status);
          localStorage.setItem(lastSyncKey, new Date().toISOString());

          return { plan, status, uniqueId: uid };
        }
      }
    } catch (err) {
      console.warn("Could not query User ID sheet:", err);
    }

    localStorage.setItem(lastSyncKey, new Date().toISOString());
    return {
      plan: localStorage.getItem('user_sub') || 'FREE',
      status: localStorage.getItem('user_status') || 'ACTIVE',
      uniqueId: finalPurixId,
    };
  }
}
