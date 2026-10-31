import { SheetRow } from '../types';

export class SheetService {
  // ==============================================================
  // 🏛️ CENTRAL URLs (4 active Google Apps Script deployments from official Purix repository)
  // ==============================================================
  static readonly STUDENT_DATA_URL = "https://script.google.com/macros/s/AKfycbxW1tu6jkT29VBflDapForv8tLdV56-XfMeFjqX9xd-Q3hhwuwsNz_IJTexO4hEsoDTOA/exec";
  static readonly BIHAR_BOARD_URL = "https://script.google.com/macros/s/AKfycbwNSja_UzoISlT4hb8ESpgUls_0Vw1VqpkibIRaVo56L2dCMIF3bJ4NjcB6aOUvZomn/exec";
  static readonly CBSE_BOARD_URL = "https://script.google.com/macros/s/AKfycbxrukMQn5IFkfaAkCr9EzKjv1QI7eTm1C6H7DoTT3ABEYcim1TPgOA92l2XxDcKNRBUSQ/exec";
  static readonly JHARKHAND_BOARD_URL = "https://script.google.com/macros/s/AKfycbxji5Af2_gwCwWS3j-qoapuwncAD9VIw7nztICi8RPoWiZ7HsbvSnuReAAGyGbNFmGa/exec";

  // 12-Hour Cache Duration in Milliseconds (12 * 60 * 60 * 1000 = 43,200,000 ms)
  static readonly CACHE_TTL_MS = 12 * 60 * 60 * 1000;

  // In-Flight Promise Registry to prevent duplicate parallel network calls
  private static inFlightRequests: Map<string, Promise<SheetRow[]>> = new Map();

  /**
   * Determine the appropriate Google Apps Script endpoint based on the sheet name and selected board
   */
  static getScriptUrlForSheet(sheetName: string, board?: string): string {
    const cleanSheet = sheetName.trim().toLowerCase();
    if (cleanSheet.includes('user') || cleanSheet.includes('student')) {
      return this.STUDENT_DATA_URL;
    }

    const cleanBoard = (board || localStorage.getItem('user_board') || 'Bihar Board (BSEB)').trim().toLowerCase();
    if (cleanBoard.includes('cbse')) {
      return this.CBSE_BOARD_URL;
    } else if (cleanBoard.includes('jharkhand') || cleanBoard.includes('jac')) {
      return this.JHARKHAND_BOARD_URL;
    } else {
      return this.BIHAR_BOARD_URL;
    }
  }

  /**
   * Detect client device information silently (Brand, Model, OS)
   * Captures mobile model from User-Agent without any prompt or permission popup
   */
  static getDeviceInfo(): string {
    if (typeof window === 'undefined' || !window.navigator) {
      return "Web Browser Client";
    }

    const ua = navigator.userAgent;
    let device = "Web Browser";

    if (/android/i.test(ua)) {
      device = "Android Device";
      // Extract Android version and device model (e.g. SM-G998B, Redmi Note 10, vivo 1920)
      const androidMatch = ua.match(/Android\s([0-9.]+)/i);
      const version = androidMatch ? `Android ${androidMatch[1]}` : 'Android';
      
      const modelMatch = ua.match(/;\s*([^;)]+)\s*Build/i) || ua.match(/Android[^;]+;\s*([^;)]+)\)/i);
      if (modelMatch && modelMatch[1]) {
        device = `${version} (${modelMatch[1].trim()})`;
      } else {
        device = version;
      }
    } else if (/iPad|iPhone|iPod/.test(ua)) {
      const match = ua.match(/iPhone\sOS\s([0-9_]+)/i);
      const iosVer = match ? `iOS ${match[1].replace(/_/g, '.')}` : 'iOS';
      device = `Apple iPhone (${iosVer})`;
    } else if (/Macintosh|Mac OS X/.test(ua)) {
      device = "Apple Mac (Desktop)";
    } else if (/Windows/.test(ua)) {
      device = "Windows PC";
    } else if (/Linux/.test(ua)) {
      device = "Linux Machine";
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
   * Generates a safe cache key scoped by board, class, and sheet
   */
  private static getCacheKey(sheetName: string, board?: string, className?: string): { dataKey: string; timeKey: string } {
    const activeBoard = (board || localStorage.getItem('user_board') || 'Bihar Board (BSEB)').replace(/[^a-zA-Z0-9]/g, '_');
    const activeClass = (className || localStorage.getItem('user_class') || '').replace(/[^a-zA-Z0-9]/g, '_');
    const safeSheet = sheetName.replace(/[^a-zA-Z0-9]/g, '_');

    return {
      dataKey: `cache_data_${activeBoard}_${activeClass}_${safeSheet}`,
      timeKey: `cache_time_${activeBoard}_${activeClass}_${safeSheet}`,
    };
  }

  /**
   * Checks whether the specified sheet data is already cached and valid.
   * Enforces 12:00 AM Midnight Reset: Cache expires when midnight passes so a new day fetches fresh content.
   * Also enforces 12-hour max TTL.
   */
  static isCacheValid(sheetName: string, board?: string, className?: string): boolean {
    const { dataKey, timeKey } = this.getCacheKey(sheetName, board, className);

    try {
      const cachedString = localStorage.getItem(dataKey);
      const cachedTimeStr = localStorage.getItem(timeKey);

      if (cachedString && cachedTimeStr) {
        const cachedDate = new Date(cachedTimeStr);
        const cachedTime = cachedDate.getTime();
        const now = new Date();

        // 1. Midnight 12:00 AM check: Must be on the exact same calendar day
        const isSameCalendarDay =
          cachedDate.getFullYear() === now.getFullYear() &&
          cachedDate.getMonth() === now.getMonth() &&
          cachedDate.getDate() === now.getDate();

        // 2. 12-hour TTL sliding limit
        const isWithin12Hours = (now.getTime() - cachedTime) < this.CACHE_TTL_MS;

        if (isSameCalendarDay && isWithin12Hours) {
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
   * Fetches data from the appropriate Google Sheet endpoint with 12-hour localStorage caching
   * & In-Flight Promise deduplication to protect Google Apps Script quota
   */
  static async fetchSheetData(
    sheetName: string,
    options?: { board?: string; className?: string; forceRefresh?: boolean } | boolean
  ): Promise<SheetRow[]> {
    const forceRefresh = typeof options === 'boolean' ? options : options?.forceRefresh ?? false;
    const board = typeof options === 'object' ? options.board : undefined;
    const className = typeof options === 'object' ? options.className : undefined;

    const { dataKey, timeKey } = this.getCacheKey(sheetName, board, className);
    const flightKey = `${sheetName}_${board || ''}_${className || ''}`;

    // 1. Check 12-Hour Cache First: If valid, NO API call will be made!
    if (!forceRefresh) {
      try {
        const cachedString = localStorage.getItem(dataKey);
        const cachedTimeStr = localStorage.getItem(timeKey);

        if (cachedString && cachedTimeStr) {
          const cachedDate = new Date(cachedTimeStr);
          const cachedTime = cachedDate.getTime();
          const now = new Date();

          // 1. Midnight 12:00 AM reset: Must be same calendar day
          const isSameCalendarDay =
            cachedDate.getFullYear() === now.getFullYear() &&
            cachedDate.getMonth() === now.getMonth() &&
            cachedDate.getDate() === now.getDate();

          // 2. Max 12-hour duration
          const isWithin12Hours = (now.getTime() - cachedTime) < this.CACHE_TTL_MS;

          if (isSameCalendarDay && isWithin12Hours) {
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
    if (this.inFlightRequests.has(flightKey)) {
      return this.inFlightRequests.get(flightKey)!;
    }

    // 3. Initiate single network fetch using the correct board URL
    const fetchPromise = (async () => {
      try {
        const targetUrl = this.getScriptUrlForSheet(sheetName, board);
        const activeClass = className || localStorage.getItem('user_class') || '';
        const isUserSheet = targetUrl === this.STUDENT_DATA_URL;
        const classQuery = (!isUserSheet && activeClass) ? `&class=${encodeURIComponent(activeClass)}` : '';
        const url = `${targetUrl}?sheet=${encodeURIComponent(sheetName)}${classQuery}`;

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
          this.saveToLocalStorage(dataKey, JSON.stringify(data));
          this.saveToLocalStorage(timeKey, new Date().toISOString());
          return data as SheetRow[];
        }
        return [];
      } catch (error) {
        console.error(`Error fetching sheet [${sheetName}]:`, error);
        
        // Offline Fallback: If network failed, serve existing local data even if older than 12h
        try {
          const fallbackCached = localStorage.getItem(dataKey);
          if (fallbackCached) {
            return JSON.parse(fallbackCached) as SheetRow[];
          }
        } catch (e) {
          // ignore
        }
        return [];
      } finally {
        this.inFlightRequests.delete(flightKey);
      }
    })();

    this.inFlightRequests.set(flightKey, fetchPromise);
    return fetchPromise;
  }

  /**
   * Fetches single user row by phone from Student Data sheet (always fresh for login)
   */
  static async fetchUserByPhone(phone: string): Promise<SheetRow | null> {
    try {
      const cleanPhone = phone.trim();
      const url = `${this.STUDENT_DATA_URL}?sheet=${encodeURIComponent('User ID')}&phone=${encodeURIComponent(cleanPhone)}`;
      const response = await fetch(url, {
        method: 'GET',
        headers: {
          'Accept': 'application/json',
        },
      });

      if (response.ok) {
        const data = await response.json();
        if (Array.isArray(data) && data.length > 0) {
          return data[0] as SheetRow;
        }
      }
    } catch (e) {
      console.warn("fetchUserByPhone error:", e);
    }

    // Fallback: search full User ID sheet
    try {
      const fullList = await this.fetchSheetData('User ID', { forceRefresh: true });
      const cleanPhone = phone.trim();
      for (const row of fullList) {
        const p = String(row['Phone'] || row['phone'] || '').trim();
        if (p === cleanPhone) {
          return row;
        }
      }
    } catch (err) {
      console.warn("User lookup fallback error:", err);
    }
    return null;
  }

  /**
   * Pre-loads and caches all MCQ and Study data for the user's class and board in 1 single pass
   * Once called, all quizzes, chapters, and notes run 100% offline from localStorage for 12 hours.
   */
  static async preloadClassContent(selectedClass: string, board?: string, force = false): Promise<{ mcqCount: number; notesCount: number }> {
    let prefix = "8th";
    if (selectedClass.includes("9")) prefix = "9th";
    else if (selectedClass.includes("10") || selectedClass.toLowerCase().includes("board")) prefix = "10th";

    const mcqSheet = `${prefix} MCQ`;
    const notesSheet = `${prefix} Notes`;

    // If both sheets are already cached within 12 hours and not forced, do 0 network calls!
    if (!force && this.isCacheValid(mcqSheet, board, selectedClass) && this.isCacheValid(notesSheet, board, selectedClass)) {
      const { dataKey: mcqKey } = this.getCacheKey(mcqSheet, board, selectedClass);
      const { dataKey: notesKey } = this.getCacheKey(notesSheet, board, selectedClass);
      const cachedMcq = JSON.parse(localStorage.getItem(mcqKey) || '[]');
      const cachedNotes = JSON.parse(localStorage.getItem(notesKey) || '[]');
      return { mcqCount: cachedMcq.length, notesCount: cachedNotes.length };
    }

    try {
      const [mcqData, notesData] = await Promise.all([
        this.fetchSheetData(mcqSheet, { board, className: selectedClass, forceRefresh: force }),
        this.fetchSheetData(notesSheet, { board, className: selectedClass, forceRefresh: force }).catch(() => [] as SheetRow[]),
      ]);

      return { mcqCount: mcqData.length, notesCount: notesData.length };
    } catch (e) {
      console.warn("Preload content warning:", e);
      return { mcqCount: 0, notesCount: 0 };
    }
  }

  /**
   * Syncs user profile with Google Sheet with smart throttling (12-hour TTL)
   * Posts to Student Data URL with selectedBoard support matching Flutter backend
   */
  static async syncUserProfile(params: {
    name: string;
    phone: string;
    email: string;
    selectedClass: string;
    selectedBoard?: string;
    purixId?: string;
    deviceInfo?: string;
    force?: boolean;
  }): Promise<{ plan: string; status: string; uniqueId: string }> {
    const finalPurixId = params.purixId || localStorage.getItem('user_uid') || this.generatePurixId();
    const finalBoard = params.selectedBoard || localStorage.getItem('user_board') || "Bihar Board (BSEB)";
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
      // 1. Post registration / login ping to Student Data Apps Script
      // Sends device information (Brand, Model, OS) completely silently in the background
      const payload = {
        name: params.name,
        phone: params.phone,
        email: params.email,
        purix_id: finalPurixId,
        selected_class: params.selectedClass,
        selected_board: finalBoard,
        device_info: finalDevice,
        device: finalDevice,
        model: finalDevice,
        login_time: currentDateTime,
      };

      await fetch(this.STUDENT_DATA_URL, {
        method: 'POST',
        headers: {
          'Content-Type': 'text/plain;charset=utf-8',
        },
        body: JSON.stringify(payload),
      });
    } catch (e) {
      console.warn("Sync post warning:", e);
    }

    // 2. Fetch specific user record by phone to check live Plan and Status
    try {
      const userRow = await this.fetchUserByPhone(params.phone);
      if (userRow) {
        const rawPlan = String(userRow['Plan'] || userRow['plan'] || userRow['PLAN'] || userRow['Subscription'] || 'FREE').trim().toUpperCase();
        const plan = rawPlan === 'PRO' ? 'PRO' : 'FREE';
        const status = String(userRow['Status'] || userRow['status'] || 'ACTIVE').trim().toUpperCase();
        const uid = String(userRow['Unique ID'] || userRow['UniqueID'] || userRow['Unique ID '] || finalPurixId).trim();

        localStorage.setItem('user_sub', plan);
        localStorage.setItem('user_status', status);
        localStorage.setItem('user_uid', uid);
        localStorage.setItem(lastSyncKey, new Date().toISOString());

        return { plan, status, uniqueId: uid };
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
