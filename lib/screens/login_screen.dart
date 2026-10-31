import React, { useState } from 'react';
import { SheetService } from '../services/sheetService';
import { Shield, Smartphone, Mail, User, AlertCircle, ArrowRight, Loader2, Sparkles } from 'lucide-react';

interface LoginScreenProps {
  onLoginSuccess: (userName: string) => void;
  onShowMessage: (msg: string, type?: 'info' | 'error' | 'success') => void;
}

export const LoginScreen: React.FC<LoginScreenProps> = ({ onLoginSuccess, onShowMessage }) => {
  const [isLoading, setIsLoading] = useState(false);
  const [showVerificationModal, setShowVerificationModal] = useState(false);
  const [imageError, setImageError] = useState(false);

  // Form fields
  const [cadetName, setCadetName] = useState('Cadet Student');
  const [cadetEmail, setCadetEmail] = useState('student@purix.academy');
  const [mobileNumber, setMobileNumber] = useState('');
  const [inputError, setInputError] = useState('');

  const handleStartGoogleSignIn = () => {
    setShowVerificationModal(true);
  };

  const handleVerifyAndEnter = async (e: React.FormEvent) => {
    e.preventDefault();
    setInputError('');

    const cleanMobile = mobileNumber.replace(/\D/g, '');
    if (cleanMobile.length !== 10) {
      setInputError('Please enter a valid 10-digit WhatsApp number');
      return;
    }

    if (!cadetName.trim() || cadetName.trim().toLowerCase() === 'student') {
      setInputError('Please enter your full Cadet Name');
      return;
    }

    if (!cadetEmail.trim() || !cadetEmail.includes('@')) {
      setInputError('Please enter a valid email address');
      return;
    }

    setIsLoading(true);
    setShowVerificationModal(false);

    try {
      // 1. Fetch User ID sheet to check existing user & status (always fresh query)
      const userRow = await SheetService.fetchUserByPhone(cleanMobile);
      
      let isOldUser = false;
      let finalPurixId = '';
      let accountStatus = 'ACTIVE';
      let planStatus = 'FREE';

      if (userRow) {
        isOldUser = true;
        finalPurixId = String(userRow['Unique ID'] || userRow['UniqueID'] || userRow['Unique ID '] || '').trim();
        const rawPlan = String(
          userRow['Plan'] || userRow['plan'] || userRow['PLAN'] || 
          userRow['Subscription'] || userRow['subscription'] || 'FREE'
        ).trim().toUpperCase();
        
        // Strict check: 'PRO' or 'VERIFIED' in Google Sheet grants verified classroom enrollment
        planStatus = (rawPlan === 'PRO' || rawPlan === 'VERIFIED') ? 'PRO' : 'FREE';
        accountStatus = String(userRow['Status'] || userRow['status'] || 'ACTIVE').trim().toUpperCase();
      }

      // Security block: If deactivated by admin in Google Sheet
      if (isOldUser && (accountStatus === 'DEACTIVE' || accountStatus === 'BANNED' || accountStatus === 'BLOCKED')) {
        setIsLoading(false);
        onShowMessage("🔒 ACCOUNT SUSPENDED: Please contact Purix Academy center administration.", 'error');
        return;
      }

      // Generate new Purix ID if not existing
      if (!isOldUser || !finalPurixId) {
        finalPurixId = SheetService.generatePurixId();
      }

      // 2. Sync to Google Apps Script
      const syncResult = await SheetService.syncUserProfile({
        name: cadetName.trim(),
        phone: cleanMobile,
        email: cadetEmail.trim(),
        selectedClass: '',
        purixId: finalPurixId,
        force: true,
      });

      if (syncResult.status === 'DEACTIVE') {
        setIsLoading(false);
        onShowMessage("🔒 ACCOUNT SUSPENDED: Please contact Purix Academy center administration.", 'error');
        return;
      }

      const syncPlan = (syncResult.plan || '').trim().toUpperCase();
      const finalPlan = (syncPlan === 'PRO' || syncPlan === 'VERIFIED') ? 'PRO' : (planStatus === 'PRO' ? 'PRO' : 'FREE');

      // 3. Save to localStorage
      localStorage.setItem('user_name', cadetName.trim());
      localStorage.setItem('user_email', cadetEmail.trim());
      localStorage.setItem('user_phone', cleanMobile);
      localStorage.setItem('user_uid', finalPurixId);
      localStorage.setItem('user_sub', finalPlan);
      localStorage.setItem('user_status', syncResult.status || accountStatus);
      localStorage.setItem('is_logged_in', 'true');

      setIsLoading(false);
      onLoginSuccess(cadetName.trim());
    } catch (err) {
      console.error("Login verification error:", err);
      setIsLoading(false);
      onShowMessage("Network matrix error. Please try again.", 'error');
    }
  };

  return (
    <div className="min-h-screen bg-[#070B14] flex flex-col justify-center items-center px-4 relative overflow-hidden">
      {/* Sci-fi Cyber Background Ambient Glows */}
      <div className="absolute top-1/4 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[500px] h-[500px] bg-[#D4AF37]/10 rounded-full blur-[120px] pointer-events-none" />
      <div className="absolute bottom-10 right-10 w-80 h-80 bg-[#00F0FF]/10 rounded-full blur-[100px] pointer-events-none" />

      {isLoading ? (
        <div className="flex flex-col items-center justify-center space-y-4 z-10">
          <Loader2 className="w-10 h-10 text-[#00F0FF] animate-spin" />
          <div className="text-center font-mono text-xs tracking-[0.2em] text-[#00F0FF] animate-pulse">
            SYNCING SECURE MATRIX...
          </div>
          <div className="text-xs text-slate-400 font-mono">Connecting to Purix Academy Nodes</div>
        </div>
      ) : (
        <div className="w-full max-w-md mx-auto flex flex-col items-center text-center z-10 py-10">
          {/* Logo with gold glowing aura - Works in web, APK and fallback */}
          <div className="relative mb-6">
            <div className="w-28 h-28 md:w-32 md:h-32 rounded-full p-1 bg-gradient-to-tr from-[#D4AF37] via-[#FFD700] to-[#00F0FF] shadow-[0_0_35px_rgba(212,175,55,0.45)] flex items-center justify-center overflow-hidden bg-[#070B14]">
              {!imageError ? (
                <img
                  src="logo.png"
                  alt="Purix Academy Logo"
                  className="w-full h-full object-cover rounded-full"
                  onError={() => {
                    const img = document.querySelector('#purix-logo-img') as HTMLImageElement;
                    if (img && !img.src.includes('/logo.png')) {
                      img.src = '/logo.png';
                    } else {
                      setImageError(true);
                    }
                  }}
                  id="purix-logo-img"
                />
              ) : (
                <div className="w-full h-full rounded-full bg-[#0E1626] flex flex-col items-center justify-center text-[#D4AF37] border border-[#D4AF37]/40 shadow-inner">
                  <span className="text-3xl font-black font-mono tracking-tighter">PA</span>
                  <span className="text-[8px] font-mono tracking-widest text-[#00F0FF]">PURIX</span>
                </div>
              )}
            </div>
          </div>

          <h1 className="text-2xl md:text-3xl font-black text-[#D4AF37] tracking-[0.15em] mb-2 drop-shadow-[0_2px_10px_rgba(212,175,55,0.3)]">
            PURIX ACADEMY
          </h1>
          <div className="text-xs font-mono font-bold tracking-[0.18em] text-white/90 mb-3 uppercase">
            NEW WAY OF LEARNING
          </div>
          <p className="text-xs text-white/60 font-mono max-w-xs mb-10 leading-relaxed">
            High-yield board question banks, simulations & classroom notes
          </p>

          {/* Continue with Google button with Official Multi-Color Google "G" SVG Logo */}
          <button
            onClick={handleStartGoogleSignIn}
            className="w-full max-w-[340px] h-[52px] bg-white hover:bg-slate-100 text-[#1F1F1F] font-bold rounded-2xl flex items-center justify-center gap-3 transition-all transform active:scale-95 shadow-[0_4px_20px_rgba(255,255,255,0.15)] mb-6 cursor-pointer"
          >
            {/* Official 4-Color Google "G" Logo */}
            <svg className="w-5 h-5 flex-shrink-0" viewBox="0 0 24 24">
              <path
                fill="#4285F4"
                d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"
              />
              <path
                fill="#34A853"
                d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
              />
              <path
                fill="#FBBC05"
                d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.06H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.94l2.85-2.22.81-.63z"
              />
              <path
                fill="#EA4335"
                d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.06l3.66 2.84c.87-2.6 3.3-4.52 6.16-4.52z"
              />
            </svg>
            <span className="text-[15px] tracking-wide font-semibold text-[#1F1F1F]">
              Continue with Google
            </span>
          </button>

          {/* Security badge */}
          <div className="flex items-center gap-2 text-white/40 font-mono text-[10px] tracking-widest uppercase">
            <Shield className="w-3.5 h-3.5 text-[#00F0FF]/70" />
            <span>SECURE ACADEMY PORTAL</span>
          </div>
        </div>
      )}

      {/* Verification / Profile Dialog Modal */}
      {showVerificationModal && (
        <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="w-full max-w-md bg-[#0B111E] border border-[#00F0FF] rounded-2xl p-6 shadow-[0_0_30px_rgba(0,240,255,0.2)]">
            <div className="flex items-center gap-2 mb-3">
              <Sparkles className="w-4 h-4 text-[#00F0FF]" />
              <div className="text-xs font-mono font-bold tracking-widest text-[#00F0FF]">
                // PURIX CADET REGISTRATION
              </div>
            </div>

            <p className="text-xs text-white/70 mb-5 leading-relaxed font-mono">
              Welcome Cadet! Link your 10-digit WhatsApp number to verify your institute enrollment status & unique Purix ID.
            </p>

            <form onSubmit={handleVerifyAndEnter} className="space-y-4">
              <div>
                <label className="block text-[11px] font-mono text-white/60 mb-1">
                  Cadet Name
                </label>
                <div className="relative">
                  <User className="absolute left-3 top-3 w-4 h-4 text-[#00F0FF]/80" />
                  <input
                    type="text"
                    value={cadetName}
                    onChange={(e) => setCadetName(e.target.value)}
                    required
                    placeholder="Enter your full name"
                    className="w-full bg-[#070B14] border border-white/15 focus:border-[#00F0FF] rounded-xl py-2.5 pl-10 pr-3 text-sm text-white focus:outline-none transition-colors"
                  />
                </div>
              </div>

              <div>
                <label className="block text-[11px] font-mono text-white/60 mb-1">
                  Email Address
                </label>
                <div className="relative">
                  <Mail className="absolute left-3 top-3 w-4 h-4 text-[#00F0FF]/80" />
                  <input
                    type="email"
                    value={cadetEmail}
                    onChange={(e) => setCadetEmail(e.target.value)}
                    required
                    placeholder="cadet@example.com"
                    className="w-full bg-[#070B14] border border-white/15 focus:border-[#00F0FF] rounded-xl py-2.5 pl-10 pr-3 text-sm text-white focus:outline-none transition-colors"
                  />
                </div>
              </div>

              <div>
                <label className="block text-[11px] font-mono text-white/60 mb-1">
                  WhatsApp / Mobile Number (10 Digits)
                </label>
                <div className="relative">
                  <Smartphone className="absolute left-3 top-3 w-4 h-4 text-[#00F0FF]/80" />
                  <input
                    type="tel"
                    maxLength={10}
                    value={mobileNumber}
                    onChange={(e) => setMobileNumber(e.target.value.replace(/\D/g, ''))}
                    required
                    placeholder="9876543210"
                    className="w-full bg-[#070B14] border border-white/15 focus:border-[#00F0FF] rounded-xl py-2.5 pl-10 pr-3 text-sm font-mono tracking-widest text-white focus:outline-none transition-colors"
                  />
                </div>
                <div className="text-[10px] text-white/40 font-mono mt-1">
                  Links to institute admission & classroom batch verification
                </div>
              </div>

              {inputError && (
                <div className="flex items-center gap-2 p-2.5 bg-red-950/40 border border-red-500/40 rounded-lg text-xs text-red-300">
                  <AlertCircle className="w-4 h-4 flex-shrink-0 text-red-400" />
                  <span>{inputError}</span>
                </div>
              )}

              <div className="flex items-center justify-end gap-3 pt-3">
                <button
                  type="button"
                  onClick={() => setShowVerificationModal(false)}
                  className="px-4 py-2 text-xs font-mono text-white/60 hover:text-white transition-colors"
                >
                  CANCEL
                </button>
                <button
                  type="submit"
                  className="px-5 py-2.5 bg-[#00F0FF]/20 hover:bg-[#00F0FF]/30 border border-[#00F0FF] text-[#00F0FF] font-bold text-xs font-mono tracking-wider rounded-xl transition-all flex items-center gap-2 active:scale-95 cursor-pointer"
                >
                  <span>VERIFY & ENTER</span>
                  <ArrowRight className="w-3.5 h-3.5" />
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};