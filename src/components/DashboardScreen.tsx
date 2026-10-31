import React, { useState, useEffect, useMemo } from 'react';
import { SheetService } from '../services/sheetService';
import { StudyMode } from '../types';
import { 
  Home,
  Zap, 
  Layers, 
  BookOpen, 
  Compass, 
  GraduationCap, 
  MessageCircle, 
  User, 
  ArrowRight, 
  X, 
  Shield, 
  RefreshCw,
  LogOut,
  Edit3,
  Phone,
  Mail,
  Target,
  Trophy,
  CheckCircle2,
  ChevronRight,
  FileText,
  FileEdit,
  Building2,
  ShieldAlert,
  ShieldCheck
} from 'lucide-react';

import { LearningProgressTracker } from './LearningProgressTracker';

interface DashboardScreenProps {
  userName: string;
  selectedClass: string;
  selectedBoard?: string;
  onNavigateToModule: (mode: StudyMode) => void;
  onNavigateToFree: () => void;
  onSwitchClass: () => void;
  onSwitchBoard?: () => void;
  onLogout: () => void;
  onShowMessage: (msg: string, type?: 'info' | 'error' | 'success') => void;
  onNavigateToSubject?: (mode: StudyMode, subjectName: string) => void;
}

export const DashboardScreen: React.FC<DashboardScreenProps> = ({
  userName,
  selectedClass,
  selectedBoard = 'Bihar Board (BSEB)',
  onNavigateToModule,
  onNavigateToFree,
  onSwitchClass,
  onSwitchBoard,
  onLogout,
  onShowMessage,
  onNavigateToSubject,
}) => {
  const [currentName, setCurrentName] = useState(userName || 'Student');
  const [currentPhone, setCurrentPhone] = useState(localStorage.getItem('user_phone') || '');
  const [currentEmail, setCurrentEmail] = useState(localStorage.getItem('user_email') || '');
  const [currentUid, setCurrentUid] = useState(localStorage.getItem('user_uid') || 'FETCHING...');
  const [subscriptionStatus, setSubscriptionStatus] = useState(localStorage.getItem('user_sub') || 'SYNCING...');
  
  // Modals
  const [showProfileModal, setShowProfileModal] = useState(false);
  const [showEditDialog, setShowEditDialog] = useState(false);
  const [showClassroomDialog, setShowClassroomDialog] = useState(false);
  const [isCheckingVerification, setIsCheckingVerification] = useState(false);

  // Edit form
  const [editName, setEditName] = useState(currentName);
  const [editPhone, setEditPhone] = useState(currentPhone);
  const [editEmail, setEditEmail] = useState(currentEmail);
  const [isSyncing, setIsSyncing] = useState(false);

  const SUPPORT_PHONE = "+919508774890";
  const SUPPORT_WHATSAPP = "919508774890";

  // Strict check: Only 'PRO' or 'VERIFIED' in Google Sheet grants verified classroom enrollment
  const isClassroomVerified = 
    subscriptionStatus.trim().toUpperCase() === 'PRO' || 
    subscriptionStatus.trim().toUpperCase() === 'VERIFIED';

  // Live Sheet Status Sync: Cadet or admin can verify in real-time
  const handleCheckLiveVerification = async () => {
    setIsCheckingVerification(true);
    try {
      const phone = localStorage.getItem('user_phone') || currentPhone;
      const name = localStorage.getItem('user_name') || currentName;
      const email = localStorage.getItem('user_email') || currentEmail;

      if (!phone) {
        onShowMessage("No registered phone number found to sync.", 'error');
        return;
      }

      const res = await SheetService.syncUserProfile({
        name,
        phone,
        email: email || 'N/A',
        selectedClass,
        selectedBoard,
        force: true,
      });

      const userVerified = res.plan.trim().toUpperCase() === 'PRO' || res.plan.trim().toUpperCase() === 'VERIFIED';
      const cleanSub = userVerified ? 'PRO' : 'FREE';
      setSubscriptionStatus(cleanSub);
      localStorage.setItem('user_sub', cleanSub);

      if (userVerified) {
        onShowMessage("✅ CLASSROOM STATUS: VERIFIED (Enrolled in Purix Academy)", "success");
      } else {
        onShowMessage("ℹ️ CLASSROOM STATUS: UNVERIFIED (Contact Classroom Center to enroll)", "info");
      }
    } catch (e) {
      onShowMessage("Could not sync verification status with Google Sheet.", 'error');
    } finally {
      setIsCheckingVerification(false);
    }
  };

  // Background auto-sync and 12-hour content preloader
  useEffect(() => {
    let isMounted = true;

    // 1. Preload and cache all MCQ and Study data for the class in 1 single pass (stored for 12 hours)
    SheetService.preloadClassContent(selectedClass, selectedBoard).catch(() => {});

    // 2. Throttled user sync (bypasses network call if verified within 12 hours)
    const syncStatus = async () => {
      const phone = localStorage.getItem('user_phone') || '';
      const name = localStorage.getItem('user_name') || currentName;
      const email = localStorage.getItem('user_email') || '';

      if (phone && name.toLowerCase() !== 'student') {
        try {
          const result = await SheetService.syncUserProfile({
            name,
            phone,
            email: email || 'N/A',
            selectedClass,
            selectedBoard,
            force: false,
          });

          if (!isMounted) return;

          const cleanSub = result.plan.trim().toUpperCase();
          const cleanStatus = result.status.trim().toLowerCase();

          // Strict deactivation check
          if (cleanStatus === 'deactive' || cleanStatus === 'banned' || cleanStatus === 'blocked' || cleanSub === 'DEACTIVE') {
            localStorage.clear();
            onShowMessage("Your account has been deactivated by Admin.", 'error');
            onLogout();
            return;
          }

          const isUserVerified = cleanSub === 'PRO' || cleanSub === 'VERIFIED';
          const finalSub = isUserVerified ? 'PRO' : 'FREE';
          localStorage.setItem('user_sub', finalSub);
          if (result.uniqueId) {
            localStorage.setItem('user_uid', result.uniqueId);
            setCurrentUid(result.uniqueId);
          }
          setSubscriptionStatus(finalSub);
        } catch (e) {
          console.warn("Auto-sync error:", e);
        }
      }
    };

    syncStatus();

    // Check mandatory profile completeness
    if (!currentPhone || currentPhone.length < 10 || currentName.toLowerCase() === 'student' || !currentEmail) {
      setShowEditDialog(true);
    }

    return () => {
      isMounted = false;
    };
  }, [selectedClass, selectedBoard]);

  const handleOpenWhatsApp = (customMessage?: string) => {
    const text = customMessage || `Hello Purix Academy! I am Cadet ${currentName} (${selectedClass}, ${selectedBoard}). I would like to inquire about classroom admission and batch enrollment.`;
    const cleanPhone = SUPPORT_WHATSAPP.replace(/\D/g, '');
    const url = `https://wa.me/${cleanPhone}?text=${encodeURIComponent(text)}`;
    window.open(url, '_blank');
  };

  const handleSaveProfile = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editName.trim() || editName.trim().toLowerCase() === 'student') {
      onShowMessage("Valid Cadet name is mandatory.", 'error');
      return;
    }
    const cleanPhone = editPhone.replace(/\D/g, '');
    if (cleanPhone.length !== 10) {
      onShowMessage("Valid 10-digit mobile number is mandatory.", 'error');
      return;
    }
    if (!editEmail.trim() || !editEmail.includes('@')) {
      onShowMessage("Valid email address is mandatory.", 'error');
      return;
    }

    setIsSyncing(true);
    try {
      localStorage.setItem('user_name', editName.trim());
      localStorage.setItem('user_phone', cleanPhone);
      localStorage.setItem('user_email', editEmail.trim());

      setCurrentName(editName.trim());
      setCurrentPhone(cleanPhone);
      setCurrentEmail(editEmail.trim());
      setSubscriptionStatus('SYNCING...');
      setShowEditDialog(false);

      const res = await SheetService.syncUserProfile({
        name: editName.trim(),
        phone: cleanPhone,
        email: editEmail.trim(),
        selectedClass,
        selectedBoard,
        force: true,
      });

      if (res.status === 'DEACTIVE') {
        localStorage.clear();
        onShowMessage("Your account has been deactivated by Admin.", 'error');
        onLogout();
        return;
      }

      const isUserVerified = res.plan.trim().toUpperCase() === 'PRO' || res.plan.trim().toUpperCase() === 'VERIFIED';
      const finalSub = isUserVerified ? 'PRO' : 'FREE';
      localStorage.setItem('user_sub', finalSub);
      setSubscriptionStatus(finalSub);
      if (res.uniqueId) {
        localStorage.setItem('user_uid', res.uniqueId);
        setCurrentUid(res.uniqueId);
      }
      onShowMessage("Cadet profile synced successfully!", 'success');
    } catch (err) {
      onShowMessage("Error syncing profile with server.", 'error');
    } finally {
      setIsSyncing(false);
    }
  };

  // Client-side quick metrics
  const completedQuizCount = useMemo(() => {
    let count = 0;
    try {
      for (let i = 0; i < localStorage.length; i++) {
        const key = localStorage.key(i);
        if (key && key.startsWith('quiz_') && key.endsWith('_completed') && localStorage.getItem(key) === 'true') {
          count++;
        }
      }
    } catch (e) {
      // ignore
    }
    return count;
  }, []);

  const greeting = useMemo(() => {
    const hour = new Date().getHours();
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }, []);

  const quote = "Every question practiced today is an exam mark secured tomorrow.";

  const userInitial = useMemo(() => {
    return currentName ? currentName.trim().charAt(0).toUpperCase() : 'C';
  }, [currentName]);

  return (
    <div className="min-h-screen bg-[#040814] text-white flex flex-col pb-32 relative overflow-x-hidden font-sans">
      {/* Sci-fi matrix ambient glows */}
      <div className="absolute top-0 right-0 w-[500px] h-[300px] bg-[#00F0FF]/5 rounded-full blur-[140px] pointer-events-none" />
      <div className="absolute top-80 left-0 w-[450px] h-[450px] bg-[#BF00FF]/5 rounded-full blur-[160px] pointer-events-none" />

      {/* 1. TOP HEADER (Class & Board cleanly moved inside Profile Icon) */}
      <header className="sticky top-0 z-30 bg-[#040814]/95 backdrop-blur-md border-b border-white/5 px-4 md:px-6 py-3 flex items-center justify-between">
        {/* Left: Logo + Branding */}
        <div className="flex items-center gap-2.5">
          <div className="w-9 h-9 rounded-full overflow-hidden bg-black/40 border border-[#FFB800]/50 flex items-center justify-center flex-shrink-0 shadow-[0_0_12px_rgba(255,184,0,0.25)]">
            <img 
              src="logo.png" 
              alt="Purix Academy" 
              className="w-full h-full object-cover"
              onError={(e) => {
                const target = e.target as HTMLImageElement;
                if (!target.src.includes('/logo.png')) {
                  target.src = '/logo.png';
                }
              }} 
            />
          </div>
          <div>
            <div className="flex items-center gap-1.5 leading-none">
              <span className="font-black text-base tracking-wider text-white">
                PURIX
              </span>
              <span className="font-black text-base tracking-wider text-[#FFB800]">
                ACADEMY
              </span>
            </div>
            <div className="text-[8px] font-mono tracking-[0.2em] text-white/50 uppercase mt-0.5 font-semibold">
              NEW WAY OF LEARNING
            </div>
          </div>
        </div>

        {/* Right: Profile Avatar Button (Class & Board switches accessible inside) */}
        <button
          onClick={() => setShowProfileModal(true)}
          className="w-9 h-9 rounded-full bg-[#1A253A] border border-[#0099FF] text-white font-bold text-sm flex items-center justify-center hover:scale-105 transition-all cursor-pointer shadow-[0_0_12px_rgba(0,153,255,0.35)]"
          title="Open Cadet Profile (Class & Board settings)"
        >
          {userInitial}
        </button>
      </header>

      {/* Main Content Area */}
      <main className="max-w-2xl w-full mx-auto px-4 md:px-5 pt-4 space-y-4 z-10 flex-1">
        {/* 2. EXECUTIVE HERO BANNER */}
        <div className="w-full bg-gradient-to-br from-[#0F1D38] via-[#091326] to-[#040812] border border-[#0099FF]/40 rounded-3xl p-5 md:p-6 shadow-[0_8px_30px_rgba(0,153,255,0.15)] relative overflow-hidden">
          <div className="absolute inset-0 opacity-15 pointer-events-none bg-[radial-gradient(ellipse_at_top,_var(--tw-gradient-stops))] from-blue-400/20 via-transparent to-transparent" />
          
          <div className="flex items-center justify-between gap-4 relative z-10">
            {/* Left Column: Greeting + Cadet Name + Daily Board Quote */}
            <div className="space-y-1">
              <div className="text-white font-bold text-base md:text-lg">
                {greeting},
              </div>
              <h1 className="text-2xl md:text-3xl font-black text-[#FFB800] tracking-tight">
                {currentName}!
              </h1>
              <p className="text-xs text-white/75 italic max-w-[240px] sm:max-w-xs pt-1 leading-relaxed">
                "{quote}"
              </p>
            </div>

            {/* Right Column: Target Board */}
            <div className="flex flex-col items-center flex-shrink-0 relative">
              <div className="text-right text-[#FFD700] text-xs font-serif italic font-bold tracking-wide transform -rotate-6 mb-1 select-none drop-shadow">
                Keep Going ~
              </div>

              <div className="relative">
                <div className="absolute inset-0 bg-[#FFB800]/25 rounded-full blur-xl animate-pulse" />
                <div className="w-16 h-16 md:w-20 md:h-20 rounded-full bg-gradient-to-tr from-[#1A1305] via-[#2A1D07] to-[#120E04] border-2 border-[#FFB800] flex items-center justify-center shadow-[0_0_25px_rgba(255,184,0,0.4)] relative">
                  <Target className="w-9 h-9 md:w-11 md:h-11 text-[#FFB800]" />
                  <div className="absolute w-2 h-2 rounded-full bg-[#00FF88] shadow-[0_0_8px_#00FF88]" />
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* 3. METRICS ROW (Non-clickable Stat Display Cards) */}
        <div className="grid grid-cols-2 gap-3">
          {/* Card 1: TESTS COMPLETED */}
          <div className="bg-[#0A1324] border border-[#00FF88]/30 rounded-2xl p-4 shadow-[0_4px_16px_rgba(0,0,0,0.4)] relative overflow-hidden">
            <div className="absolute top-0 right-0 w-24 h-24 bg-[#00FF88]/5 rounded-full blur-2xl pointer-events-none" />
            <div className="flex items-start justify-between">
              <div className="w-10 h-10 rounded-xl bg-[#00FF88]/15 border border-[#00FF88]/40 flex items-center justify-center text-[#00FF88] shadow-[0_0_12px_rgba(0,255,136,0.2)]">
                <Trophy className="w-5 h-5" />
              </div>
              <span className="text-[9px] font-mono font-bold text-[#00FF88] bg-[#00FF88]/10 border border-[#00FF88]/30 px-2 py-0.5 rounded-full">
                ACTIVE
              </span>
            </div>
            <div className="mt-3">
              <div className="text-[10px] font-mono font-bold uppercase tracking-wider text-white/50">
                TESTS COMPLETED
              </div>
              <div className="text-2xl font-black text-white mt-1 leading-none tracking-tight">
                {completedQuizCount}
              </div>
              <div className="text-[10px] font-mono text-white/40 mt-1 flex items-center gap-1">
                <CheckCircle2 className="w-3 h-3 text-[#00FF88]" />
                <span>Simulations Done</span>
              </div>
            </div>
          </div>

          {/* Card 2: TARGET GOAL */}
          <div className="bg-[#0A1324] border border-[#00F0FF]/30 rounded-2xl p-4 shadow-[0_4px_16px_rgba(0,0,0,0.4)] relative overflow-hidden">
            <div className="absolute top-0 right-0 w-24 h-24 bg-[#00F0FF]/5 rounded-full blur-2xl pointer-events-none" />
            <div className="flex items-start justify-between">
              <div className="w-10 h-10 rounded-xl bg-[#00F0FF]/15 border border-[#00F0FF]/40 flex items-center justify-center text-[#00F0FF] shadow-[0_0_12px_rgba(0,240,255,0.2)]">
                <Target className="w-5 h-5" />
              </div>
              <span className="text-[9px] font-mono font-bold text-[#00F0FF] bg-[#00F0FF]/10 border border-[#00F0FF]/30 px-2 py-0.5 rounded-full">
                GOAL
              </span>
            </div>
            <div className="mt-3">
              <div className="text-[10px] font-mono font-bold uppercase tracking-wider text-white/50">
                TARGET GOAL
              </div>
              <div className="flex items-baseline gap-1.5 mt-1">
                <span className="text-2xl font-black text-white leading-none tracking-tight">
                  95%+
                </span>
                <span className="text-[10px] font-mono text-white/50">
                  Board Exam
                </span>
              </div>
              <div className="w-full h-1.5 bg-[#050912] rounded-full overflow-hidden mt-2 border border-white/5">
                <div className="h-full bg-gradient-to-r from-[#00F0FF] to-[#0099FF] w-4/5 rounded-full shadow-[0_0_8px_rgba(0,240,255,0.5)]" />
              </div>
            </div>
          </div>
        </div>

        {/* 4. MODULE SHORTCUT CARDS ROW (4 Modules) */}
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-2.5 sm:gap-3">
          {/* Card 1: MCQ SPRINT */}
          <button
            onClick={() => onNavigateToModule('mcq')}
            className="p-3 rounded-2xl bg-[#0A1324] border border-[#0099FF]/50 hover:border-[#0099FF] transition-all text-left group cursor-pointer shadow-[0_4px_16px_rgba(0,0,0,0.4)] flex flex-col justify-between"
          >
            <div className="flex items-center justify-between mb-2">
              <div className="w-8 h-8 rounded-full bg-[#0099FF]/20 border border-[#0099FF]/40 flex items-center justify-center text-[#00A2FF]">
                <Zap className="w-4 h-4" />
              </div>
              <div className="w-5 h-5 rounded-full bg-white/5 flex items-center justify-center text-white/40 group-hover:text-white transition-colors">
                <ChevronRight className="w-3.5 h-3.5" />
              </div>
            </div>
            <div>
              <div className="text-xs font-bold text-white tracking-wide">
                MCQ SPRINT
              </div>
              <div className="text-[9px] font-mono text-white/50">
                Timed Tests
              </div>
            </div>
          </button>

          {/* Card 2: PRACTICE */}
          <button
            onClick={() => onNavigateToModule('practice')}
            className="p-3 rounded-2xl bg-[#0A1324] border border-[#00FF88]/50 hover:border-[#00FF88] transition-all text-left group cursor-pointer shadow-[0_4px_16px_rgba(0,0,0,0.4)] flex flex-col justify-between"
          >
            <div className="flex items-center justify-between mb-2">
              <div className="w-8 h-8 rounded-full bg-[#00FF88]/20 border border-[#00FF88]/40 flex items-center justify-center text-[#00FF88]">
                <FileEdit className="w-4 h-4" />
              </div>
              <div className="w-5 h-5 rounded-full bg-white/5 flex items-center justify-center text-white/40 group-hover:text-white transition-colors">
                <ChevronRight className="w-3.5 h-3.5" />
              </div>
            </div>
            <div>
              <div className="text-xs font-bold text-white tracking-wide">
                PRACTICE
              </div>
              <div className="text-[9px] font-mono text-white/50">
                PDF Sets & Papers
              </div>
            </div>
          </button>

          {/* Card 3: PURIX NOTES */}
          <button
            onClick={() => onNavigateToModule('notes')}
            className="p-3 rounded-2xl bg-[#0A1324] border border-[#BF00FF]/50 hover:border-[#BF00FF] transition-all text-left group cursor-pointer shadow-[0_4px_16px_rgba(0,0,0,0.4)] flex flex-col justify-between"
          >
            <div className="flex items-center justify-between mb-2">
              <div className="w-8 h-8 rounded-full bg-[#BF00FF]/20 border border-[#BF00FF]/40 flex items-center justify-center text-[#D946EF]">
                <FileText className="w-4 h-4" />
              </div>
              <div className="w-5 h-5 rounded-full bg-white/5 flex items-center justify-center text-white/40 group-hover:text-white transition-colors">
                <ChevronRight className="w-3.5 h-3.5" />
              </div>
            </div>
            <div>
              <div className="text-xs font-bold text-white tracking-wide">
                PURIX NOTES
              </div>
              <div className="text-[9px] font-mono text-white/50">
                Core Theory
              </div>
            </div>
          </button>

          {/* Card 4: FREE MATRIX */}
          <button
            onClick={onNavigateToFree}
            className="p-3 rounded-2xl bg-[#0A1324] border border-[#FFB800]/50 hover:border-[#FFB800] transition-all text-left group cursor-pointer shadow-[0_4px_16px_rgba(0,0,0,0.4)] flex flex-col justify-between"
          >
            <div className="flex items-center justify-between mb-2">
              <div className="w-8 h-8 rounded-full bg-[#FFB800]/20 border border-[#FFB800]/40 flex items-center justify-center text-[#FFB800]">
                <Compass className="w-4 h-4" />
              </div>
              <div className="w-5 h-5 rounded-full bg-white/5 flex items-center justify-center text-white/40 group-hover:text-white transition-colors">
                <ChevronRight className="w-3.5 h-3.5" />
              </div>
            </div>
            <div>
              <div className="text-xs font-bold text-white tracking-wide">
                FREE MATRIX
              </div>
              <div className="text-[9px] font-mono text-white/50">
                PYQ & Model Sets
              </div>
            </div>
          </button>
        </div>

        {/* 5. LEARNING PROGRESS TRACKER */}
        <LearningProgressTracker
          selectedClass={selectedClass}
          onNavigateToSubject={(mode, subjectName) => {
            if (onNavigateToSubject) {
              onNavigateToSubject(mode, subjectName);
            } else {
              onNavigateToModule(mode);
            }
          }}
          onShowMessage={onShowMessage}
        />

        {/* 6. NEED HELP? HELP DESK BANNER */}
        <div className="w-full bg-gradient-to-r from-[#2A200B] via-[#1D1708] to-[#120E04] border border-[#FFB800]/40 rounded-2xl p-4 flex items-center justify-between shadow-[0_4px_20px_rgba(255,184,0,0.15)]">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-[#FFB800]/20 border border-[#FFB800]/40 flex items-center justify-center text-[#FFB800] flex-shrink-0">
              <FileText className="w-5 h-5" />
            </div>
            <div>
              <div className="text-sm font-bold text-white">
                Need Help?
              </div>
              <div className="text-xs text-white/70">
                Academic support & classroom center inquiry
              </div>
            </div>
          </div>

          <button
            onClick={() => handleOpenWhatsApp()}
            className="px-4 py-2 bg-[#FFB800] hover:bg-[#ffe033] text-black font-bold text-xs rounded-xl transition-all flex items-center gap-1.5 shadow-md flex-shrink-0 cursor-pointer active:scale-95"
          >
            <span>Ask Us</span>
            <ChevronRight className="w-3.5 h-3.5" />
          </button>
        </div>
      </main>

      {/* 7. BOTTOM NAVIGATION BAR (5 Items: Home, MCQ Test, Practice, Notes, Free Matrix) */}
      <nav className="fixed bottom-0 left-0 right-0 z-40 bg-[#040814]/95 backdrop-blur-xl border-t border-white/5 py-2 px-2">
        <div className="max-w-lg mx-auto grid grid-cols-5 gap-1">
          {/* 1. Home */}
          <button
            onClick={() => window.scrollTo({ top: 0, behavior: 'smooth' })}
            className="flex flex-col items-center justify-center py-1.5 px-0.5 rounded-xl bg-white/5 text-[#00F0FF] relative cursor-pointer"
          >
            <Home className="w-5 h-5 mb-0.5" />
            <span className="font-mono text-[9px] font-bold tracking-tight">
              Home
            </span>
            <div className="w-1 h-1 rounded-full bg-[#00F0FF] mt-0.5" />
          </button>

          {/* 2. MCQ Test */}
          <button
            onClick={() => onNavigateToModule('mcq')}
            className="group flex flex-col items-center justify-center py-1.5 px-0.5 rounded-xl hover:bg-white/5 active:scale-95 transition-all cursor-pointer text-white/60 hover:text-[#00A2FF]"
          >
            <Layers className="w-5 h-5 mb-0.5 transition-colors group-hover:text-[#00A2FF]" />
            <span className="font-mono text-[9px] font-bold text-white/80 group-hover:text-[#00A2FF] tracking-tight truncate">
              MCQ Test
            </span>
          </button>

          {/* 3. Practice */}
          <button
            onClick={() => onNavigateToModule('practice')}
            className="group flex flex-col items-center justify-center py-1.5 px-0.5 rounded-xl hover:bg-white/5 active:scale-95 transition-all cursor-pointer text-white/60 hover:text-[#00FF88]"
          >
            <FileEdit className="w-5 h-5 mb-0.5 transition-colors group-hover:text-[#00FF88]" />
            <span className="font-mono text-[9px] font-bold text-white/80 group-hover:text-[#00FF88] tracking-tight truncate">
              Practice
            </span>
          </button>

          {/* 4. Notes */}
          <button
            onClick={() => onNavigateToModule('notes')}
            className="group flex flex-col items-center justify-center py-1.5 px-0.5 rounded-xl hover:bg-white/5 active:scale-95 transition-all cursor-pointer text-white/60 hover:text-[#BF00FF]"
          >
            <BookOpen className="w-5 h-5 mb-0.5 transition-colors group-hover:text-[#BF00FF]" />
            <span className="font-mono text-[9px] font-bold text-white/80 group-hover:text-[#BF00FF] tracking-tight truncate">
              Notes
            </span>
          </button>

          {/* 5. Free Matrix */}
          <button
            onClick={onNavigateToFree}
            className="group flex flex-col items-center justify-center py-1.5 px-0.5 rounded-xl hover:bg-white/5 active:scale-95 transition-all cursor-pointer text-white/60 hover:text-[#FFB800]"
          >
            <Compass className="w-5 h-5 mb-0.5 transition-colors group-hover:text-[#FFB800]" />
            <span className="font-mono text-[9px] font-bold text-white/80 group-hover:text-[#FFB800] tracking-tight truncate">
              Free Matrix
            </span>
          </button>
        </div>
      </nav>

      {/* Profile Modal (Contains Class, Board, Classroom Status & Center Details) */}
      {showProfileModal && (
        <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="w-full max-w-md bg-[#0B111E] border border-[#00F0FF]/50 rounded-2xl p-5 md:p-6 shadow-[0_0_30px_rgba(0,240,255,0.2)] relative max-h-[90vh] overflow-y-auto">
            <button
              onClick={() => setShowProfileModal(false)}
              className="absolute top-4 right-4 text-white/50 hover:text-white p-1 cursor-pointer"
            >
              <X className="w-5 h-5" />
            </button>

            {/* Cadet Details Header */}
            <div className="flex flex-col items-center text-center mb-3">
              <div className="w-14 h-14 rounded-full bg-[#00F0FF]/15 border border-[#00F0FF]/40 text-[#00F0FF] font-bold text-xl flex items-center justify-center mb-2 shadow-[0_0_15px_rgba(0,240,255,0.25)]">
                {userInitial}
              </div>
              <h3 className="text-base font-bold text-white tracking-wide uppercase">
                {currentName}
              </h3>
              <div className="text-[11px] font-mono text-white/70 mt-0.5">
                CLASS: {selectedClass} • {selectedBoard}
              </div>
              <div className="text-xs font-mono font-bold text-[#00F0FF] mt-0.5">
                CADET ID: {currentUid}
              </div>
              {currentPhone && (
                <div className="text-[10px] font-mono text-white/50 mt-0.5">
                  PHONE: +91 {currentPhone}
                </div>
              )}
            </div>

            {/* Dedicated Classroom Status Indicator (Verified only if PRO/VERIFIED in Google Sheet) */}
            <div className={`w-full p-3.5 rounded-xl border flex items-center justify-between mb-4 font-mono transition-all ${
              isClassroomVerified
                ? 'bg-[#00FF88]/10 border-[#00FF88]/40 shadow-[0_0_15px_rgba(0,255,136,0.12)]'
                : 'bg-amber-500/10 border-amber-500/35 shadow-[0_0_15px_rgba(245,158,11,0.08)]'
            }`}>
              <div className="flex items-center gap-3">
                <div className={`w-9 h-9 rounded-lg flex items-center justify-center flex-shrink-0 ${
                  isClassroomVerified ? 'bg-[#00FF88]/20 text-[#00FF88]' : 'bg-amber-500/20 text-amber-300'
                }`}>
                  {isClassroomVerified ? <CheckCircle2 className="w-5 h-5" /> : <ShieldAlert className="w-5 h-5" />}
                </div>
                <div className="text-left">
                  <div className="text-[9px] text-white/50 uppercase font-bold tracking-widest">
                    CLASSROOM STATUS
                  </div>
                  <div className={`text-xs font-bold tracking-wide ${isClassroomVerified ? 'text-[#00FF88]' : 'text-amber-300'}`}>
                    {isClassroomVerified ? 'VERIFIED' : 'UNVERIFIED'}
                  </div>
                  <div className="text-[9px] text-white/60">
                    {isClassroomVerified ? 'Monthly Classroom Batch Active' : 'Monthly Admission Required'}
                  </div>
                </div>
              </div>

              <div className="flex flex-col items-end gap-1 flex-shrink-0">
                <span className={`text-[10px] font-bold px-2.5 py-0.5 rounded-full uppercase border ${
                  isClassroomVerified
                    ? 'bg-[#00FF88]/20 text-[#00FF88] border-[#00FF88]/50'
                    : 'bg-amber-500/20 text-amber-300 border-amber-500/50'
                }`}>
                  {isClassroomVerified ? 'VERIFIED' : 'UNVERIFIED'}
                </span>
                <button
                  onClick={handleCheckLiveVerification}
                  disabled={isCheckingVerification}
                  className="text-[10px] text-[#00F0FF] hover:underline flex items-center gap-1 cursor-pointer pt-0.5"
                  title="Refresh status from live Google Sheet"
                >
                  <RefreshCw className={`w-3 h-3 ${isCheckingVerification ? 'animate-spin' : ''}`} />
                  <span>{isCheckingVerification ? 'Syncing...' : 'Live Sync'}</span>
                </button>
              </div>
            </div>

            {/* Policy Compliant Classroom Enrollment Card (Zero paid/gateway words) */}
            <div className="mb-4 bg-gradient-to-br from-[#121A2A] via-[#0E1522] to-[#1A180E] border border-[#FFD700]/40 rounded-xl p-4 shadow-[0_4px_20px_rgba(255,215,0,0.1)] relative overflow-hidden">
              <div className="flex items-center justify-between mb-2">
                <div className="flex items-center gap-2">
                  <div className="w-7 h-7 rounded-lg bg-[#FFD700]/15 border border-[#FFD700]/50 flex items-center justify-center text-[#FFD700]">
                    <GraduationCap className="w-4 h-4" />
                  </div>
                  <div>
                    <h4 className="text-xs font-black text-[#FFD700] tracking-wider uppercase font-mono">
                      CLASSROOM ENROLLMENT
                    </h4>
                    <div className="text-[9px] font-mono text-white/60">
                      Syllabus Node: {selectedClass} ({selectedBoard.split(' ')[0]})
                    </div>
                  </div>
                </div>
                <span className={`px-2 py-0.5 rounded-full font-mono font-bold text-[9px] border ${
                  isClassroomVerified 
                    ? 'bg-[#00FF88]/15 border-[#00FF88]/40 text-[#00FF88]' 
                    : 'bg-amber-500/15 border-amber-500/40 text-amber-300'
                }`}>
                  {isClassroomVerified ? 'ACTIVE CADET 🎓' : 'NOT ENROLLED'}
                </span>
              </div>

              {/* Curriculum Checklist */}
              <div className="space-y-1.5 py-1.5 text-[10px] text-white/80 font-mono">
                <div className="flex items-center gap-1.5">
                  <CheckCircle2 className="w-3 h-3 text-[#00FF66] flex-shrink-0" />
                  <span>Full Chapter Test Question Banks</span>
                </div>
                <div className="flex items-center gap-1.5">
                  <CheckCircle2 className="w-3 h-3 text-[#00FF66] flex-shrink-0" />
                  <span>Handwritten Formula & PDF Material</span>
                </div>
                <div className="flex items-center gap-1.5">
                  <CheckCircle2 className="w-3 h-3 text-[#00FF66] flex-shrink-0" />
                  <span>High-Yield Board Revision Drills</span>
                </div>
                <div className="flex items-center gap-1.5">
                  <CheckCircle2 className="w-3 h-3 text-[#00FF66] flex-shrink-0" />
                  <span>Direct Mentor Guidance at Institute Center</span>
                </div>
              </div>

              <button
                onClick={() => {
                  setShowProfileModal(false);
                  setShowClassroomDialog(true);
                }}
                className="w-full mt-2 py-2.5 px-3 rounded-lg bg-[#FFD700] hover:bg-[#ffe033] text-black font-black text-xs font-mono tracking-wider transition-all shadow-md flex items-center justify-center gap-1.5 cursor-pointer active:scale-95"
              >
                <ShieldCheck className="w-4 h-4 fill-black" />
                <span>
                  {isClassroomVerified ? 'VIEW CLASSROOM DETAILS' : 'INQUIRE AT CLASSROOM CENTER'}
                </span>
              </button>
            </div>

            {/* Profile Action Items: Class, Board, Profile Edit, Logout */}
            <div className="space-y-2.5">
              {/* Switch Target Class */}
              <div
                onClick={() => {
                  setShowProfileModal(false);
                  onSwitchClass();
                }}
                className="bg-[#101726] border border-white/10 hover:border-[#00F0FF]/50 rounded-xl p-3 flex items-center justify-between cursor-pointer transition-all"
              >
                <div className="flex items-center gap-3">
                  <div className="p-2 rounded-lg bg-[#FFB800]/15 text-[#FFB800]">
                    <GraduationCap className="w-4 h-4" />
                  </div>
                  <div className="text-left">
                    <div className="text-xs font-semibold text-white">Switch Target Class</div>
                    <div className="text-[10px] text-white/50">Current: {selectedClass}</div>
                  </div>
                </div>
                <ArrowRight className="w-4 h-4 text-white/30" />
              </div>

              {/* Switch Education Board */}
              {onSwitchBoard && (
                <div
                  onClick={() => {
                    setShowProfileModal(false);
                    onSwitchBoard();
                  }}
                  className="bg-[#101726] border border-white/10 hover:border-[#00F0FF]/50 rounded-xl p-3 flex items-center justify-between cursor-pointer transition-all"
                >
                  <div className="flex items-center gap-3">
                    <div className="p-2 rounded-lg bg-[#00F0FF]/15 text-[#00F0FF]">
                      <Building2 className="w-4 h-4" />
                    </div>
                    <div className="text-left">
                      <div className="text-xs font-semibold text-white">Switch Education Board</div>
                      <div className="text-[10px] text-white/50">{selectedBoard}</div>
                    </div>
                  </div>
                  <ArrowRight className="w-4 h-4 text-white/30" />
                </div>
              )}

              {/* Edit Cadet Details */}
              <div
                onClick={() => {
                  setShowProfileModal(false);
                  setShowEditDialog(true);
                }}
                className="bg-[#101726] border border-white/10 hover:border-[#00F0FF]/50 rounded-xl p-3 flex items-center justify-between cursor-pointer transition-all"
              >
                <div className="flex items-center gap-3">
                  <div className="p-2 rounded-lg bg-white/5 text-white/80">
                    <Edit3 className="w-4 h-4" />
                  </div>
                  <div className="text-left">
                    <div className="text-xs font-semibold text-white">Edit Cadet Details</div>
                    <div className="text-[10px] text-white/50">Update phone, email or name</div>
                  </div>
                </div>
                <ArrowRight className="w-4 h-4 text-white/30" />
              </div>

              {/* Terminate Session (Logout) */}
              <div
                onClick={() => {
                  setShowProfileModal(false);
                  onLogout();
                }}
                className="bg-[#101726] border border-red-500/30 hover:border-red-500/60 rounded-xl p-3 flex items-center justify-between cursor-pointer transition-all text-red-400"
              >
                <div className="flex items-center gap-3">
                  <div className="p-2 rounded-lg bg-red-950/40 text-red-400">
                    <LogOut className="w-4 h-4" />
                  </div>
                  <div className="text-left">
                    <div className="text-xs font-semibold">Terminate Session (Logout)</div>
                    <div className="text-[10px] text-red-300/60">Clear local session data</div>
                  </div>
                </div>
                <ArrowRight className="w-4 h-4 text-red-400/40" />
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Profile Edit Dialog */}
      {showEditDialog && (
        <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="w-full max-w-md bg-[#0B111E] border border-[#FFD700] rounded-2xl p-6 shadow-[0_0_30px_rgba(255,215,0,0.2)]">
            <div className="flex items-center gap-2 mb-2 text-[#FFD700]">
              <Shield className="w-5 h-5" />
              <h3 className="text-sm font-bold tracking-wider uppercase font-mono">
                CADET PROFILE VERIFICATION
              </h3>
            </div>
            <p className="text-[11px] text-white/70 mb-5 leading-relaxed font-mono">
              Valid Name, Email, and 10-digit WhatsApp number are required to maintain access to test simulations and synced records.
            </p>

            <form onSubmit={handleSaveProfile} className="space-y-4">
              <div>
                <label className="block text-[11px] font-mono text-white/60 mb-1">
                  Cadet Name (Mandatory)
                </label>
                <div className="relative">
                  <User className="absolute left-3 top-3 w-4 h-4 text-[#FFD700]" />
                  <input
                    type="text"
                    value={editName}
                    onChange={(e) => setEditName(e.target.value)}
                    required
                    placeholder="Enter your name"
                    className="w-full bg-[#101726] border border-white/15 focus:border-[#FFD700] rounded-xl py-2.5 pl-10 pr-3 text-sm text-white focus:outline-none transition-colors"
                  />
                </div>
              </div>

              <div>
                <label className="block text-[11px] font-mono text-white/60 mb-1">
                  Email Address (Mandatory)
                </label>
                <div className="relative">
                  <Mail className="absolute left-3 top-3 w-4 h-4 text-[#FFD700]" />
                  <input
                    type="email"
                    value={editEmail}
                    onChange={(e) => setEditEmail(e.target.value)}
                    required
                    placeholder="student@purix.edu"
                    className="w-full bg-[#101726] border border-white/15 focus:border-[#FFD700] rounded-xl py-2.5 pl-10 pr-3 text-sm text-white focus:outline-none transition-colors"
                  />
                </div>
              </div>

              <div>
                <label className="block text-[11px] font-mono text-white/60 mb-1">
                  WhatsApp Mobile (10 Digits)
                </label>
                <div className="relative">
                  <Phone className="absolute left-3 top-3 w-4 h-4 text-[#FFD700]" />
                  <input
                    type="tel"
                    maxLength={10}
                    value={editPhone}
                    onChange={(e) => setEditPhone(e.target.value)}
                    required
                    placeholder="9876543210"
                    className="w-full bg-[#101726] border border-white/15 focus:border-[#FFD700] rounded-xl py-2.5 pl-10 pr-3 text-sm text-white focus:outline-none transition-colors"
                  />
                </div>
              </div>

              <div className="pt-2 flex gap-3">
                <button
                  type="submit"
                  disabled={isSyncing}
                  className="flex-1 py-3 bg-[#FFD700] hover:bg-[#ffe033] text-black font-black font-mono text-xs rounded-xl transition-all shadow-[0_2px_15px_rgba(255,215,0,0.3)] flex items-center justify-center gap-2 cursor-pointer"
                >
                  {isSyncing ? (
                    <>
                      <RefreshCw className="w-4 h-4 animate-spin" />
                      <span>SAVING & SYNCING...</span>
                    </>
                  ) : (
                    <span>CONFIRM & SAVE DETAILS</span>
                  )}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Indus App Store Policy Compliant Dialog (No Price, No Payment, Only Contact Center) */}
      {showClassroomDialog && (
        <div className="fixed inset-0 z-50 bg-black/85 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="w-full max-w-md bg-[#0A0F1D] border-2 border-[#FFD700] rounded-3xl p-6 shadow-[0_0_40px_rgba(255,215,0,0.25)] relative">
            <button
              onClick={() => setShowClassroomDialog(false)}
              className="absolute top-4 right-4 text-white/50 hover:text-white p-1"
            >
              <X className="w-5 h-5" />
            </button>

            <div className="text-center mb-5">
              <div className="w-12 h-12 rounded-2xl bg-[#FFD700]/15 border border-[#FFD700]/50 flex items-center justify-center text-[#FFD700] mx-auto mb-2 shadow-[0_0_20px_rgba(255,215,0,0.3)]">
                <Shield className="w-6 h-6 text-[#FFD700]" />
              </div>
              <h3 className="text-lg font-black text-[#FFD700] tracking-wider uppercase font-mono">
                Classroom Students Only
              </h3>
              <p className="text-xs text-white/70 mt-1">
                This section is exclusively for registered students of Purix Academy. Access is provided at our classroom center upon enrollment.
              </p>
            </div>

            <div className="bg-[#101726] border border-white/10 rounded-2xl p-4 mb-5 space-y-3 font-mono text-xs">
              <div className="flex items-center justify-between border-b border-white/10 pb-2">
                <span className="text-white/60">Center Node:</span>
                <span className="font-bold text-white">Purix Classroom Center</span>
              </div>
              <div className="flex items-center justify-between border-b border-white/10 pb-2">
                <span className="text-white/60">Cadet ID:</span>
                <span className="font-bold text-[#FFD700]">{currentUid}</span>
              </div>
              <div className="flex items-center justify-between border-b border-white/10 pb-2">
                <span className="text-white/60">Batch Material:</span>
                <span className="font-bold text-[#00FF88]">{selectedClass} Syllabus</span>
              </div>
              <div className="flex items-center justify-between pt-1">
                <span className="text-white/60">Education Board:</span>
                <span className="font-bold text-white">{selectedBoard}</span>
              </div>
            </div>

            <div className="space-y-2.5">
              <button
                onClick={() => {
                  window.location.href = `tel:${SUPPORT_PHONE}`;
                }}
                className="w-full py-3 px-4 rounded-xl bg-[#00F0FF] hover:bg-[#00d5e3] text-black font-black text-xs font-mono tracking-wider transition-all shadow-[0_2px_15px_rgba(0,240,255,0.3)] flex items-center justify-center gap-2 cursor-pointer active:scale-95"
              >
                <Phone className="w-4 h-4 fill-black" />
                <span>CONTACT CENTER: {SUPPORT_PHONE}</span>
              </button>

              <button
                onClick={() => {
                  handleOpenWhatsApp();
                  setShowClassroomDialog(false);
                }}
                className="w-full py-3 px-4 rounded-xl bg-white/10 hover:bg-white/15 text-white font-bold text-xs font-mono tracking-wider transition-all flex items-center justify-center gap-2 cursor-pointer"
              >
                <MessageCircle className="w-4 h-4 text-[#00FF88]" />
                <span>INQUIRE VIA WHATSAPP</span>
              </button>

              <button
                onClick={() => setShowClassroomDialog(false)}
                className="w-full py-2 text-xs font-mono text-white/40 hover:text-white transition-colors"
              >
                CLOSE
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
