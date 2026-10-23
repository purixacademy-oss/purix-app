import React, { useState, useEffect, useMemo } from 'react';
import { SheetService } from '../services/sheetService';
import { StudyMode } from '../types';
import { 
  Zap, 
  Layers, 
  BookOpen, 
  Compass, 
  Crown, 
  MessageCircle, 
  User, 
  ArrowRight, 
  Copy, 
  Check, 
  X, 
  ExternalLink,
  Shield, 
  RefreshCw,
  LogOut,
  Edit3,
  Phone,
  Mail,
  Target,
  Trophy,
  Sparkles,
  TrendingUp,
  CheckCircle2,
  GraduationCap,
  ChevronDown,
  ChevronRight,
  Rocket,
  FileText,
  Home
} from 'lucide-react';

import { LearningProgressTracker } from './LearningProgressTracker';

interface DashboardScreenProps {
  userName: string;
  selectedClass: string;
  onNavigateToModule: (mode: StudyMode) => void;
  onNavigateToFree: () => void;
  onSwitchClass: () => void;
  onLogout: () => void;
  onShowMessage: (msg: string, type?: 'info' | 'error' | 'success') => void;
  onNavigateToSubject?: (mode: StudyMode, subjectName: string) => void;
}

export const DashboardScreen: React.FC<DashboardScreenProps> = ({
  userName,
  selectedClass,
  onNavigateToModule,
  onNavigateToFree,
  onSwitchClass,
  onLogout,
  onShowMessage,
  onNavigateToSubject,
}) => {
  const [currentName, setCurrentName] = useState(userName || 'Akhil Kumar');
  const [currentPhone, setCurrentPhone] = useState(localStorage.getItem('user_phone') || '');
  const [currentEmail, setCurrentEmail] = useState(localStorage.getItem('user_email') || '');
  const [currentUid, setCurrentUid] = useState(localStorage.getItem('user_uid') || 'FETCHING...');
  const [subscriptionStatus, setSubscriptionStatus] = useState(localStorage.getItem('user_sub') || 'SYNCING...');
  
  // Modals
  const [showProfileModal, setShowProfileModal] = useState(false);
  const [showEditDialog, setShowEditDialog] = useState(false);
  const [showPaymentDialog, setShowPaymentDialog] = useState(false);
  const [copiedUpi, setCopiedUpi] = useState(false);

  // Edit form
  const [editName, setEditName] = useState(currentName);
  const [editPhone, setEditPhone] = useState(currentPhone);
  const [editEmail, setEditEmail] = useState(currentEmail);
  const [isSyncing, setIsSyncing] = useState(false);

  const SUPPORT_WHATSAPP = "919508774890";
  const ACADEMY_UPI = "6201161834@ptyes";

  const isProOrActive = 
    subscriptionStatus.toUpperCase() === 'PRO' || 
    subscriptionStatus.toUpperCase() === 'ACTIVE';

  // Background auto-sync and 12-hour content preloader
  useEffect(() => {
    let isMounted = true;

    // 1. Preload and cache all MCQ and Study data for the class in 1 single pass (stored for 12 hours)
    SheetService.preloadClassContent(selectedClass).catch(() => {});

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
            force: false,
          });

          if (!isMounted) return;

          const cleanSub = result.plan.trim().toLowerCase();
          const cleanStatus = result.status.trim().toLowerCase();

          // Strict deactivation check
          if (cleanStatus === 'deactive' || cleanStatus === 'banned' || cleanStatus === 'blocked' || cleanSub === 'deactive') {
            localStorage.clear();
            onShowMessage("Your account has been deactivated by Admin.", 'error');
            onLogout();
            return;
          }

          localStorage.setItem('user_sub', result.plan);
          if (result.uniqueId) {
            localStorage.setItem('user_uid', result.uniqueId);
            setCurrentUid(result.uniqueId);
          }
          setSubscriptionStatus(result.plan);
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
  }, [selectedClass]);

  const handleOpenWhatsApp = (customMessage?: string) => {
    const text = customMessage || `Hello Purix Academy! I am Cadet ${currentName} (${selectedClass}). I need assistance with my learning modules.`;
    const cleanPhone = SUPPORT_WHATSAPP.replace(/\D/g, '');
    const url = `https://wa.me/${cleanPhone}?text=${encodeURIComponent(text)}`;
    window.open(url, '_blank');
  };

  const handleCopyUpi = () => {
    navigator.clipboard.writeText(ACADEMY_UPI);
    setCopiedUpi(true);
    setTimeout(() => setCopiedUpi(false), 2000);
    onShowMessage("UPI ID copied to clipboard!", 'success');
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
        force: true,
      });

      if (res.status === 'DEACTIVE') {
        localStorage.clear();
        onShowMessage("Your account has been deactivated by Admin.", 'error');
        onLogout();
        return;
      }

      localStorage.setItem('user_sub', res.plan);
      setSubscriptionStatus(res.plan);
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

  // Client-side quick metrics (calculated without any API calls)
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
    return currentName ? currentName.trim().charAt(0).toUpperCase() : 'A';
  }, [currentName]);

  return (
    <div className="min-h-screen bg-[#040814] text-white flex flex-col pb-32 relative overflow-x-hidden font-sans">
      {/* Sci-fi matrix ambient glows */}
      <div className="absolute top-0 right-0 w-[500px] h-[300px] bg-[#00F0FF]/5 rounded-full blur-[140px] pointer-events-none" />
      <div className="absolute top-80 left-0 w-[450px] h-[450px] bg-[#BF00FF]/5 rounded-full blur-[160px] pointer-events-none" />

      {/* 1. TOP HEADER (Exact Match: Logo + PURIX ACADEMY + Class Selector + Avatar) */}
      <header className="sticky top-0 z-30 bg-[#040814]/95 backdrop-blur-md border-b border-white/5 px-4 md:px-6 py-3 flex items-center justify-between">
        {/* Left: Logo + Branding */}
        <div className="flex items-center gap-2.5">
          {/* User requested logo image on the left of PURIX ACADEMY */}
          <div className="w-9 h-9 rounded-full overflow-hidden bg-black/40 border border-[#FFB800]/50 flex items-center justify-center flex-shrink-0 shadow-[0_0_12px_rgba(255,184,0,0.25)]">
            <img 
              src="/logo.png" 
              alt="Purix Academy" 
              className="w-full h-full object-cover"
              onError={(e) => {
                // Fallback to stylized P badge if image not loaded
                (e.target as HTMLElement).style.display = 'none';
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

        {/* Right: Class Selector Pill + Avatar */}
        <div className="flex items-center gap-2.5">
          {/* Class 10th Selector Pill */}
          <button
            onClick={onSwitchClass}
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-[#0E1729] hover:bg-[#15233D] border border-white/10 text-white text-xs font-semibold transition-all cursor-pointer shadow-sm"
          >
            <GraduationCap className="w-3.5 h-3.5 text-[#00F0FF]" />
            <span>{selectedClass || 'Class 10th'}</span>
            <ChevronDown className="w-3 h-3 text-white/50" />
          </button>

          {/* User Avatar */}
          <button
            onClick={() => setShowProfileModal(true)}
            className="w-8 h-8 rounded-full bg-[#1A253A] border border-[#0099FF] text-white font-bold text-xs flex items-center justify-center hover:scale-105 transition-all cursor-pointer shadow-[0_0_10px_rgba(0,153,255,0.3)]"
            title="Open Cadet Profile"
          >
            {userInitial}
          </button>
        </div>
      </header>

      {/* Main Content Area */}
      <main className="max-w-2xl w-full mx-auto px-4 md:px-5 pt-4 space-y-4 z-10 flex-1">
        {/* 2. EXECUTIVE HERO BANNER (Matches Reference Image) */}
        <div className="w-full bg-gradient-to-br from-[#0F1D38] via-[#091326] to-[#040812] border border-[#0099FF]/40 rounded-3xl p-5 md:p-6 shadow-[0_8px_30px_rgba(0,153,255,0.15)] relative overflow-hidden">
          {/* Subtle mountain contour waves in background */}
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

            {/* Right Column: Hand-drawn "Keep Going" + 3D Glowing Target Board */}
            <div className="flex flex-col items-center flex-shrink-0 relative">
              {/* Cursive style Keep Going */}
              <div className="text-right text-[#FFD700] text-xs font-serif italic font-bold tracking-wide transform -rotate-6 mb-1 select-none drop-shadow">
                Keep Going ~
              </div>

              {/* 3D Glowing Target Board with Halo */}
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

        {/* 3. METRICS ROW: 2 Cards (TESTS COMPLETED & TARGET GOAL) */}
        <div className="grid grid-cols-2 gap-3">
          {/* Card 1: TESTS COMPLETED */}
          <div className="bg-[#0A1324] border border-[#00FF88]/40 rounded-2xl p-3.5 flex items-center justify-between shadow-[0_4px_16px_rgba(0,0,0,0.4)] relative overflow-hidden group">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-full bg-[#00FF88]/15 border border-[#00FF88]/40 flex items-center justify-center text-[#00FF88] flex-shrink-0 shadow-[0_0_12px_rgba(0,255,136,0.2)]">
                <Trophy className="w-5 h-5" />
              </div>
              <div>
                <div className="text-[9px] font-mono font-bold uppercase tracking-wider text-white/50">
                  TESTS COMPLETED
                </div>
                <div className="text-xl font-black text-white leading-none mt-0.5">
                  {completedQuizCount}
                </div>
                <div className="text-[10px] font-mono text-white/40 mt-0.5">
                  / 0
                </div>
              </div>
            </div>
            <div className="w-6 h-6 rounded-full bg-white/5 flex items-center justify-center text-white/40 group-hover:text-white transition-colors">
              <ChevronRight className="w-4 h-4" />
            </div>
          </div>

          {/* Card 2: TARGET GOAL */}
          <div className="bg-[#0A1324] border border-[#00F0FF]/40 rounded-2xl p-3.5 flex items-center justify-between shadow-[0_4px_16px_rgba(0,0,0,0.4)] relative overflow-hidden group">
            <div className="flex items-center gap-3 w-full">
              <div className="w-10 h-10 rounded-full bg-[#00F0FF]/15 border border-[#00F0FF]/40 flex items-center justify-center text-[#00F0FF] flex-shrink-0 shadow-[0_0_12px_rgba(0,240,255,0.2)]">
                <Target className="w-5 h-5" />
              </div>
              <div className="flex-1">
                <div className="text-[9px] font-mono font-bold uppercase tracking-wider text-white/50">
                  TARGET GOAL
                </div>
                <div className="flex items-baseline gap-1.5 mt-0.5">
                  <span className="text-xl font-black text-white leading-none">
                    95%+
                  </span>
                  <span className="text-[10px] font-mono text-white/50">
                    Board
                  </span>
                </div>
                {/* Sleek Cyan Progress Bar */}
                <div className="w-full h-1 bg-[#050912] rounded-full overflow-hidden mt-1.5">
                  <div className="h-full bg-gradient-to-r from-[#00F0FF] to-[#0099FF] w-4/5 rounded-full" />
                </div>
              </div>
            </div>
            <div className="w-6 h-6 rounded-full bg-white/5 flex items-center justify-center text-white/40 group-hover:text-white transition-colors ml-2 flex-shrink-0">
              <ChevronRight className="w-4 h-4" />
            </div>
          </div>
        </div>

        {/* 4. THREE MODULE SHORTCUT CARDS ROW */}
        <div className="grid grid-cols-3 gap-2.5 sm:gap-3">
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

          {/* Card 2: PURIX NOTES */}
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

          {/* Card 3: FREE MATRIX */}
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
                PYQ & Blueprints
              </div>
            </div>
          </button>
        </div>

        {/* 5. LEARNING PROGRESS TRACKER (With Scrollable Subjects List) */}
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

        {/* 6. NEED HELP? HELP DESK BANNER (Matches Reference Image) */}
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
                Get instant support for your queries.
              </div>
            </div>
          </div>

          <button
            onClick={() => handleOpenWhatsApp()}
            className="px-4 py-2.5 rounded-xl bg-[#FFB800] hover:bg-[#FFA500] active:scale-95 text-black font-extrabold text-xs font-mono tracking-wider flex items-center gap-1.5 transition-all shadow-[0_2px_12px_rgba(255,184,0,0.35)] cursor-pointer flex-shrink-0"
          >
            <MessageCircle className="w-3.5 h-3.5 fill-black" />
            <span>HELP DESK</span>
            <ChevronRight className="w-3.5 h-3.5 text-black" />
          </button>
        </div>
      </main>

      {/* 7. FIXED BOTTOM NAVIGATION BAR (Exact Match: 5 Tabs - Home, MCQ Test, Practice, Notes, Free Matrix) */}
      <nav className="fixed bottom-0 left-0 right-0 z-40 bg-[#040814]/95 backdrop-blur-md border-t border-white/10 shadow-[0_-8px_25px_rgba(0,0,0,0.8)] px-2 py-2">
        <div className="max-w-2xl mx-auto grid grid-cols-5 gap-1">
          {/* Tab 1: HOME (Active) */}
          <button
            onClick={() => {}}
            className="flex flex-col items-center justify-center py-1 px-1 rounded-xl transition-all cursor-pointer relative"
          >
            <div className="text-[#FFB800] mb-0.5">
              <Home className="w-5 h-5 fill-[#FFB800]" />
            </div>
            <span className="font-mono text-[9px] font-bold text-[#FFB800] tracking-wide">
              Home
            </span>
            {/* Active Golden Line Underneath */}
            <div className="w-5 h-0.5 bg-[#FFB800] rounded-full mt-0.5" />
          </button>

          {/* Tab 2: MCQ Test (Rocket) */}
          <button
            onClick={() => onNavigateToModule('mcq')}
            className="group flex flex-col items-center justify-center py-1 px-1 rounded-xl hover:bg-white/5 active:scale-95 transition-all cursor-pointer relative"
          >
            <div className="text-white/60 group-hover:text-[#00F0FF] mb-0.5 transition-colors">
              <Rocket className="w-5 h-5" />
            </div>
            <span className="font-mono text-[9px] font-bold text-white/80 group-hover:text-[#00F0FF] tracking-wide truncate">
              MCQ Test
            </span>
            <span className="font-mono text-[7px] text-[#00F0FF] font-bold">
              SEC.01
            </span>
          </button>

          {/* Tab 3: Practice (Open Book) */}
          <button
            onClick={() => onNavigateToModule('practice')}
            className="group flex flex-col items-center justify-center py-1 px-1 rounded-xl hover:bg-white/5 active:scale-95 transition-all cursor-pointer relative"
          >
            <div className="text-white/60 group-hover:text-[#FFB800] mb-0.5 transition-colors">
              <BookOpen className="w-5 h-5" />
            </div>
            <span className="font-mono text-[9px] font-bold text-white/80 group-hover:text-[#FFB800] tracking-wide truncate">
              Practice
            </span>
            <span className="font-mono text-[7px] text-[#FFB800] font-bold">
              SEC.02
            </span>
          </button>

          {/* Tab 4: Notes (Document) */}
          <button
            onClick={() => onNavigateToModule('notes')}
            className="group flex flex-col items-center justify-center py-1 px-1 rounded-xl hover:bg-white/5 active:scale-95 transition-all cursor-pointer relative"
          >
            <div className="text-white/60 group-hover:text-[#BF00FF] mb-0.5 transition-colors">
              <FileText className="w-5 h-5" />
            </div>
            <span className="font-mono text-[9px] font-bold text-white/80 group-hover:text-[#BF00FF] tracking-wide truncate">
              Notes
            </span>
            <span className="font-mono text-[7px] text-[#BF00FF] font-bold">
              SEC.03
            </span>
          </button>

          {/* Tab 5: Free Matrix (Compass) */}
          <button
            onClick={onNavigateToFree}
            className="group flex flex-col items-center justify-center py-1 px-1 rounded-xl hover:bg-white/5 active:scale-95 transition-all cursor-pointer relative"
          >
            <div className="text-white/60 group-hover:text-[#00F0FF] mb-0.5 transition-colors">
              <Compass className="w-5 h-5" />
            </div>
            <span className="font-mono text-[9px] font-bold text-white/80 group-hover:text-[#00F0FF] tracking-wide truncate">
              Free Matrix
            </span>
            <span className="font-mono text-[7px] text-[#00F0FF] font-bold">
              SEC.04
            </span>
          </button>
        </div>
      </nav>

      {/* Profile Modal / Drawer (Contains VIP Pro Pass Card Securely Inside) */}
      {showProfileModal && (
        <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="w-full max-w-md bg-[#0B111E] border border-[#00F0FF]/50 rounded-2xl p-5 md:p-6 shadow-[0_0_30px_rgba(0,240,255,0.2)] relative max-h-[90vh] overflow-y-auto">
            <button
              onClick={() => setShowProfileModal(false)}
              className="absolute top-4 right-4 text-white/50 hover:text-white p-1 cursor-pointer"
            >
              <X className="w-5 h-5" />
            </button>

            <div className="flex flex-col items-center text-center mb-4">
              <div className="w-14 h-14 rounded-full bg-[#00F0FF]/15 border border-[#00F0FF]/40 text-[#00F0FF] font-bold text-xl flex items-center justify-center mb-2">
                {userInitial}
              </div>
              <h3 className="text-base font-bold text-white tracking-wide uppercase">
                {currentName}
              </h3>
              <div className="text-[11px] font-mono text-[#00FF66] mt-0.5">
                NODE: {selectedClass} | STATUS: {subscriptionStatus}
              </div>
              <div className="text-xs font-mono font-bold text-[#00F0FF] mt-0.5">
                UID: {currentUid}
              </div>
              {currentPhone && (
                <div className="text-[10px] font-mono text-white/60 mt-0.5">
                  PHONE: {currentPhone}
                </div>
              )}
            </div>

            {/* VIP Purix PRO Pass Card (Inside Profile) */}
            <div className="mb-4 bg-gradient-to-br from-[#121A2A] via-[#0E1522] to-[#1A180E] border border-[#FFD700]/50 rounded-xl p-4 shadow-[0_4px_20px_rgba(255,215,0,0.12)] relative overflow-hidden">
              <div className="flex items-center justify-between mb-2">
                <div className="flex items-center gap-2">
                  <div className="w-7 h-7 rounded-lg bg-[#FFD700]/15 border border-[#FFD700]/50 flex items-center justify-center text-[#FFD700]">
                    <Crown className="w-3.5 h-3.5" />
                  </div>
                  <div>
                    <h4 className="text-xs font-black text-[#FFD700] tracking-wider uppercase font-mono">
                      PURIX PRO PASS
                    </h4>
                    <div className="text-[9px] font-mono text-white/60">
                      Full VIP Syllabus for {selectedClass}
                    </div>
                  </div>
                </div>
                <span className="px-2 py-0.5 rounded-full font-mono font-bold text-[9px] bg-[#FFD700]/15 border border-[#FFD700]/50 text-[#FFD700]">
                  {isProOrActive ? 'ACTIVE 👑' : '₹599 PASS'}
                </span>
              </div>

              {/* Benefits Checklist */}
              <div className="space-y-1.5 py-1.5 text-[10px] text-white/80 font-mono">
                <div className="flex items-center gap-1.5">
                  <CheckCircle2 className="w-3 h-3 text-[#00FF66] flex-shrink-0" />
                  <span>All Chapter Test Sets Unlocked</span>
                </div>
                <div className="flex items-center gap-1.5">
                  <CheckCircle2 className="w-3 h-3 text-[#00FF66] flex-shrink-0" />
                  <span>Handwritten Formula & PDF Notes</span>
                </div>
                <div className="flex items-center gap-1.5">
                  <CheckCircle2 className="w-3 h-3 text-[#00FF66] flex-shrink-0" />
                  <span>100% Ad-Free Rapid Revisions</span>
                </div>
                <div className="flex items-center gap-1.5">
                  <CheckCircle2 className="w-3 h-3 text-[#00FF66] flex-shrink-0" />
                  <span>Direct Mentor Guidance on WhatsApp</span>
                </div>
              </div>

              <button
                onClick={() => {
                  setShowProfileModal(false);
                  setShowPaymentDialog(true);
                }}
                className="w-full mt-2 py-2 px-3 rounded-lg bg-gradient-to-r from-[#FFD700] to-[#FFA500] hover:from-[#ffe033] hover:to-[#ffb31a] text-black font-black text-xs font-mono tracking-wider transition-all shadow-[0_2px_12px_rgba(255,215,0,0.3)] flex items-center justify-center gap-1.5 cursor-pointer active:scale-95"
              >
                <Crown className="w-3.5 h-3.5 fill-black" />
                <span>
                  {isProOrActive ? 'VIEW MEMBERSHIP DETAILS' : 'UPGRADE TO PRO PASS (₹599)'}
                </span>
              </button>
            </div>

            <div className="space-y-2.5">
              <div
                onClick={() => {
                  setShowProfileModal(false);
                  setShowEditDialog(true);
                }}
                className="bg-[#101726] border border-white/10 hover:border-[#00F0FF]/50 rounded-xl p-3 flex items-center justify-between cursor-pointer transition-all"
              >
                <div className="flex items-center gap-3">
                  <Edit3 className="w-4 h-4 text-[#00F0FF]" />
                  <div className="text-left">
                    <div className="text-xs font-semibold text-white">Edit Cadet Details</div>
                    <div className="text-[10px] text-white/50">Update phone, email or name</div>
                  </div>
                </div>
                <ArrowRight className="w-4 h-4 text-white/30" />
              </div>

              <div
                onClick={() => {
                  setShowProfileModal(false);
                  onSwitchClass();
                }}
                className="bg-[#101726] border border-white/10 hover:border-[#00F0FF]/50 rounded-xl p-3 flex items-center justify-between cursor-pointer transition-all"
              >
                <div className="flex items-center gap-3">
                  <RefreshCw className="w-4 h-4 text-[#00F0FF]" />
                  <div className="text-left">
                    <div className="text-xs font-semibold text-white">Switch Target Class</div>
                    <div className="text-[10px] text-white/50">Change syllabus node ({selectedClass})</div>
                  </div>
                </div>
                <ArrowRight className="w-4 h-4 text-white/30" />
              </div>

              <div
                onClick={() => {
                  setShowProfileModal(false);
                  onLogout();
                }}
                className="bg-[#101726] border border-red-500/30 hover:border-red-500/60 rounded-xl p-3 flex items-center justify-between cursor-pointer transition-all text-red-400"
              >
                <div className="flex items-center gap-3">
                  <LogOut className="w-4 h-4 text-red-400" />
                  <div className="text-left">
                    <div className="text-xs font-semibold">Terminate Session (Logout)</div>
                    <div className="text-[10px] text-red-300/60">Clear local session tokens</div>
                  </div>
                </div>
                <ArrowRight className="w-4 h-4 text-red-400/40" />
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Edit Cadet Profile Dialog */}
      {showEditDialog && (
        <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="w-full max-w-md bg-[#0B111E] border border-[#FFD700] rounded-2xl p-6 shadow-[0_0_30px_rgba(255,215,0,0.2)]">
            <div className="flex items-center gap-2 mb-2 text-[#FFD700]">
              <Shield className="w-5 h-5" />
              <h3 className="text-sm font-bold tracking-wider uppercase font-mono">
                CADET PROFILE VERIFICATION
              </h3>
            </div>
            <p className="text-[11px] text-white/70 mb-5 leading-relaxed">
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

      {/* VIP Payment Dialog */}
      {showPaymentDialog && (
        <div className="fixed inset-0 z-50 bg-black/85 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="w-full max-w-md bg-[#0A0F1D] border-2 border-[#FFD700] rounded-3xl p-6 shadow-[0_0_40px_rgba(255,215,0,0.25)] relative">
            <button
              onClick={() => setShowPaymentDialog(false)}
              className="absolute top-4 right-4 text-white/50 hover:text-white p-1"
            >
              <X className="w-5 h-5" />
            </button>

            <div className="text-center mb-5">
              <div className="w-12 h-12 rounded-2xl bg-[#FFD700]/15 border border-[#FFD700]/50 flex items-center justify-center text-[#FFD700] mx-auto mb-2 shadow-[0_0_20px_rgba(255,215,0,0.3)]">
                <Crown className="w-6 h-6 fill-[#FFD700]" />
              </div>
              <h3 className="text-lg font-black text-[#FFD700] tracking-wider uppercase font-mono">
                PURIX PRO VIP PASS
              </h3>
              <p className="text-xs text-white/70">
                Unlock 100% Chapter Tests, PDF Notes & Mentor Support
              </p>
            </div>

            <div className="bg-[#101726] border border-white/10 rounded-2xl p-4 mb-5 space-y-3">
              <div className="flex items-center justify-between text-xs border-b border-white/10 pb-2">
                <span className="text-white/60 font-mono">Syllabus Access</span>
                <span className="font-bold text-white">{selectedClass} Full Curriculum</span>
              </div>
              <div className="flex items-center justify-between text-xs border-b border-white/10 pb-2">
                <span className="text-white/60 font-mono">Pass Fee</span>
                <span className="font-bold text-[#FFD700] text-sm">₹599 (Lifetime Node)</span>
              </div>
              <div className="flex items-center justify-between text-xs pt-1">
                <span className="text-white/60 font-mono">Official UPI ID</span>
                <div className="flex items-center gap-2">
                  <span className="font-mono font-bold text-white text-xs">{ACADEMY_UPI}</span>
                  <button
                    onClick={handleCopyUpi}
                    className="p-1.5 rounded-lg bg-white/10 hover:bg-[#FFD700]/20 text-[#FFD700] transition-colors cursor-pointer"
                    title="Copy UPI"
                  >
                    {copiedUpi ? <Check className="w-3.5 h-3.5" /> : <Copy className="w-3.5 h-3.5" />}
                  </button>
                </div>
              </div>
            </div>

            <div className="space-y-2.5">
              <button
                onClick={() => {
                  handleOpenWhatsApp(`Hello Purix Admin, I want to activate PURIX PRO PASS (₹599) for Cadet ${currentName} (${selectedClass}, UID: ${currentUid}, Phone: ${currentPhone}). Please assist with activation.`);
                  setShowPaymentDialog(false);
                }}
                className="w-full py-3.5 px-4 rounded-xl bg-gradient-to-r from-[#FFD700] to-[#FFA500] hover:from-[#ffe033] hover:to-[#ffb31a] text-black font-black text-xs font-mono tracking-wider transition-all shadow-[0_2px_15px_rgba(255,215,0,0.35)] flex items-center justify-center gap-2 cursor-pointer active:scale-95"
              >
                <MessageCircle className="w-4 h-4 fill-black" />
                <span>PAY VIA UPI & NOTIFY ON WHATSAPP</span>
              </button>

              <button
                onClick={() => setShowPaymentDialog(false)}
                className="w-full py-2.5 text-xs font-mono text-white/50 hover:text-white transition-colors"
              >
                CANCEL & CLOSE
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
