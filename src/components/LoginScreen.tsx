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

  // Form fields
  const [cadetName, setCadetName] = useState('Cadet Student');
  const [cadetEmail, setCadetEmail] = useState('student@purix.academy');
  const [mobileNumber, setMobileNumber] = useState('');
  const [inputError, setInputError] = useState('');

  const handleStartGoogleSignIn = () => {
    // Prompt cadet details / verification popup matching the Flutter flow
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
      // 1. Fetch User ID sheet to check existing user & status
      const usersData = await SheetService.fetchSheetData('User ID', true);
      
      let isOldUser = false;
      let finalPurixId = '';
      let accountStatus = 'ACTIVE';
      let planStatus = 'FREE';

      for (const row of usersData) {
        const sheetPhone = String(row['Phone'] || row['phone'] || '').trim();
        if (sheetPhone === cleanMobile) {
          isOldUser = true;
          finalPurixId = String(row['Unique ID'] || row['Unique ID '] || '').trim();
          planStatus = String(row['Plan'] || 'FREE').trim().toUpperCase();
          accountStatus = String(row['Status'] || 'ACTIVE').trim().toUpperCase();
          break;
        }
      }

      // Security block: If deactivated by admin
      if (isOldUser && (accountStatus === 'DEACTIVE' || accountStatus === 'BANNED' || accountStatus === 'BLOCKED')) {
        setIsLoading(false);
        onShowMessage("🔒 ACCOUNT SUSPENDED: Please contact Purix Academy support.", 'error');
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
      });

      if (syncResult.status === 'DEACTIVE') {
        setIsLoading(false);
        onShowMessage("🔒 ACCOUNT SUSPENDED: Please contact Purix Academy support.", 'error');
        return;
      }

      const activePlan = syncResult.plan || planStatus || 'FREE';

      // 3. Save to localStorage
      localStorage.setItem('user_name', cadetName.trim());
      localStorage.setItem('user_email', cadetEmail.trim());
      localStorage.setItem('user_phone', cleanMobile);
      localStorage.setItem('user_uid', finalPurixId);
      localStorage.setItem('user_sub', activePlan);
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
          {/* Logo with gold glowing aura */}
          <div className="relative mb-6">
            <div className="w-32 h-32 md:w-36 md:h-36 rounded-full p-1 bg-gradient-to-tr from-[#D4AF37] via-[#FFD700] to-[#00F0FF] shadow-[0_0_35px_rgba(212,175,55,0.45)] flex items-center justify-center">
              <img
                src="/logo.png"
                alt="Purix Academy Logo"
                className="w-full h-full object-cover rounded-full bg-[#070B14]"
                onError={(e) => {
                  // Fallback if image asset fails
                  const target = e.currentTarget;
                  target.style.display = 'none';
                  const parent = target.parentElement;
                  if (parent) {
                    parent.innerHTML = '<div class="text-3xl font-black text-[#D4AF37]">PA</div>';
                  }
                }}
              />
            </div>
          </div>

          <h1 className="text-2xl md:text-3xl font-black text-[#D4AF37] tracking-[0.15em] mb-2 drop-shadow-[0_2px_10px_rgba(212,175,55,0.3)]">
            PURIX ACADEMY
          </h1>
          <div className="text-xs font-mono font-bold tracking-[0.18em] text-white/90 mb-3 uppercase">
            NEW WAY OF LEARNING
          </div>
          <p className="text-xs text-white/60 font-mono max-w-xs mb-10 leading-relaxed">
            Access high-yield board question banks, simulations & notes
          </p>

          {/* Continue with Google button */}
          <button
            onClick={handleStartGoogleSignIn}
            className="w-full max-w-[340px] h-[52px] bg-white hover:bg-slate-100 text-[#1F1F1F] font-bold rounded-2xl flex items-center justify-center gap-3 transition-all transform active:scale-95 shadow-[0_4px_20px_rgba(255,255,255,0.1)] mb-6 cursor-pointer"
          >
            <div className="w-6 h-6 flex items-center justify-center font-black text-[#4285F4] text-xl">
              G
            </div>
            <span className="text-[15px] tracking-wide font-semibold text-[#1F1F1F]">
              Continue with Google
            </span>
          </button>

          {/* Security badge */}
          <div className="flex items-center gap-2 text-white/40 font-mono text-[10px] tracking-widest uppercase">
            <Shield className="w-3.5 h-3.5 text-[#00F0FF]/70" />
            <span>SECURE BOARD LEARNING PORTAL</span>
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
                // VERIFICATION REQUIRED
              </div>
            </div>

            <p className="text-xs text-white/70 mb-5 leading-relaxed">
              Welcome to Purix Academy! Complete your cadet verification with your WhatsApp number to secure your unique Purix ID.
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
                  Used for account security & PRO pass activation verification
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
