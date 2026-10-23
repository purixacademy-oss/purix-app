import React, { useState, useEffect } from 'react';
import { NavigationScreen, StudyMode } from './types';
import { SheetService } from './services/sheetService';
import { SessionSecurity } from './services/sessionSecurity';
import { LoginScreen } from './components/LoginScreen';
import { ClassScreen } from './components/ClassScreen';
import { DashboardScreen } from './components/DashboardScreen';
import { SubjectScreen } from './components/SubjectScreen';
import { SubSubjectScreen } from './components/SubSubjectScreen';
import { ChapterScreen } from './components/ChapterScreen';
import { QuizScreen } from './components/QuizScreen';
import { FreeContentScreen } from './components/FreeContentScreen';
import { PdfViewerScreen } from './components/PdfViewerScreen';
import { AlertCircle, CheckCircle, Info, X } from 'lucide-react';

export const App: React.FC = () => {
  // Authentication & session state
  const [isLoggedIn, setIsLoggedIn] = useState<boolean>(() => {
    return localStorage.getItem('is_logged_in') === 'true';
  });

  const [userName, setUserName] = useState<string>(() => {
    return localStorage.getItem('user_name') || 'Student';
  });

  const [userClass, setUserClass] = useState<string | null>(() => {
    return localStorage.getItem('user_class');
  });

  // Navigation Stack
  const [screen, setScreen] = useState<NavigationScreen>(() => {
    const logged = localStorage.getItem('is_logged_in') === 'true';
    const cls = localStorage.getItem('user_class');
    if (logged && cls) {
      return { name: 'dashboard' };
    } else if (logged) {
      return { name: 'classSelect' };
    }
    return { name: 'login' };
  });

  // Toast notifications
  const [toast, setToast] = useState<{ message: string; type: 'info' | 'error' | 'success' } | null>(null);

  const showToast = (message: string, type: 'info' | 'error' | 'success' = 'info') => {
    setToast({ message, type });
    setTimeout(() => {
      setToast((current) => (current?.message === message ? null : current));
    }, 4500);
  };

  // Replicate Flutter `didChangeAppLifecycleState` for session security check
  useEffect(() => {
    const handleVisibilityChange = () => {
      if (document.visibilityState === 'visible' && isLoggedIn) {
        SessionSecurity.verifySession((suspendedMsg) => {
          showToast(suspendedMsg, 'error');
          handleLogout();
        });
      }
    };

    document.addEventListener('visibilitychange', handleVisibilityChange);
    // Initial verification
    if (isLoggedIn) {
      SessionSecurity.verifySession((suspendedMsg) => {
        showToast(suspendedMsg, 'error');
        handleLogout();
      });
    }

    return () => {
      document.removeEventListener('visibilitychange', handleVisibilityChange);
    };
  }, [isLoggedIn]);

  const handleLoginSuccess = (name: string) => {
    setUserName(name);
    setIsLoggedIn(true);
    const existingClass = localStorage.getItem('user_class');
    if (existingClass) {
      setUserClass(existingClass);
      setScreen({ name: 'dashboard' });
    } else {
      setScreen({ name: 'classSelect' });
    }
  };

  const handleSelectClass = (selectedClass: string) => {
    localStorage.setItem('user_class', selectedClass);
    setUserClass(selectedClass);
    setScreen({ name: 'dashboard' });

    // Preload & cache all MCQs and study content for this class into 12-hour localStorage
    SheetService.preloadClassContent(selectedClass).catch(() => {});

    // Sync class change
    const phone = localStorage.getItem('user_phone') || '';
    const email = localStorage.getItem('user_email') || '';
    if (phone) {
      SheetService.syncUserProfile({
        name: userName,
        phone,
        email,
        selectedClass,
      });
    }
  };

  const handleLogout = () => {
    localStorage.clear();
    setIsLoggedIn(false);
    setUserClass(null);
    setUserName('Student');
    setScreen({ name: 'login' });
  };

  // Navigation handlers
  const navigateToSubject = (mode: StudyMode) => {
    setScreen({ name: 'subject', mode });
  };

  const navigateToSubSubject = (mode: StudyMode, subjectName: string) => {
    setScreen({ name: 'subSubject', mode, subjectName });
  };

  const navigateToChapter = (mode: StudyMode, subjectName: string, subSubjectName: string) => {
    setScreen({ name: 'chapter', mode, subjectName, subSubjectName });
  };

  const navigateToQuiz = (subject: string, chapter: string, quizSetNumber: number) => {
    setScreen({ name: 'quiz', subject, chapter, quizSetNumber });
  };

  const navigateToPdf = (pdfUrl: string, title: string) => {
    setScreen({ name: 'pdfViewer', pdfUrl, title });
  };

  const navigateToFreeContent = () => {
    setScreen({ name: 'freeContent' });
  };

  // Render current active screen
  const renderScreen = () => {
    switch (screen.name) {
      case 'login':
        return (
          <LoginScreen
            onLoginSuccess={handleLoginSuccess}
            onShowMessage={showToast}
          />
        );

      case 'classSelect':
        return (
          <ClassScreen
            userName={userName}
            onSelectClass={handleSelectClass}
          />
        );

      case 'dashboard':
        return (
          <DashboardScreen
            userName={userName}
            selectedClass={userClass || 'Class 10th'}
            onNavigateToModule={navigateToSubject}
            onNavigateToSubject={(mode, subjectName) => navigateToSubSubject(mode, subjectName)}
            onNavigateToFree={navigateToFreeContent}
            onSwitchClass={() => setScreen({ name: 'classSelect' })}
            onLogout={handleLogout}
            onShowMessage={showToast}
          />
        );

      case 'subject':
        return (
          <SubjectScreen
            selectedClass={userClass || 'Class 10th'}
            mode={screen.mode}
            onSelectSubject={(subjectName) => navigateToSubSubject(screen.mode, subjectName)}
            onBack={() => setScreen({ name: 'dashboard' })}
          />
        );

      case 'subSubject':
        return (
          <SubSubjectScreen
            className={userClass || 'Class 10th'}
            subjectName={screen.subjectName}
            mode={screen.mode}
            onSelectSubSubject={(subSubjectName) =>
              navigateToChapter(screen.mode, screen.subjectName, subSubjectName)
            }
            onBack={() => setScreen({ name: 'subject', mode: screen.mode })}
          />
        );

      case 'chapter':
        return (
          <ChapterScreen
            className={userClass || 'Class 10th'}
            subjectName={screen.subjectName}
            subSubjectName={screen.subSubjectName}
            mode={screen.mode}
            onStartQuiz={(chapterName, setNumber) =>
              navigateToQuiz(screen.subjectName, chapterName, setNumber)
            }
            onOpenPdf={(pdfUrl, title) => navigateToPdf(pdfUrl, title)}
            onBack={() =>
              setScreen({
                name: 'subSubject',
                mode: screen.mode,
                subjectName: screen.subjectName,
              })
            }
            onUpgradePrompt={() => {
              showToast("🔒 PRO CONTENT: Please upgrade to Purix PRO from the Dashboard to unlock all tests & materials.", 'error');
              setScreen({ name: 'dashboard' });
            }}
          />
        );

      case 'quiz':
        return (
          <QuizScreen
            selectedClass={userClass || 'Class 10th'}
            subject={screen.subject}
            chapter={screen.chapter}
            quizSetNumber={screen.quizSetNumber}
            onExit={() =>
              setScreen({
                name: 'chapter',
                mode: 'mcq',
                subjectName: screen.subject,
                subSubjectName: screen.subject,
              })
            }
          />
        );

      case 'freeContent':
        return (
          <FreeContentScreen
            selectedClass={userClass || 'Class 10th'}
            onOpenPdf={(pdfUrl, title) => navigateToPdf(pdfUrl, title)}
            onBack={() => setScreen({ name: 'dashboard' })}
          />
        );

      case 'pdfViewer':
        return (
          <PdfViewerScreen
            pdfUrl={screen.pdfUrl}
            title={screen.title}
            onBack={() => setScreen({ name: 'dashboard' })}
          />
        );

      default:
        return (
          <LoginScreen
            onLoginSuccess={handleLoginSuccess}
            onShowMessage={showToast}
          />
        );
    }
  };

  return (
    <div className="min-h-screen bg-[#070B14] text-white">
      {renderScreen()}

      {/* Global Toast Alert */}
      {toast && (
        <div className="fixed top-4 left-1/2 -translate-x-1/2 z-50 w-11/12 max-w-md animate-in fade-in slide-in-from-top-4 duration-200">
          <div
            className={`flex items-start gap-3 p-3.5 rounded-xl border shadow-xl backdrop-blur-md ${
              toast.type === 'error'
                ? 'bg-red-950/90 border-red-500/50 text-red-100'
                : toast.type === 'success'
                ? 'bg-emerald-950/90 border-emerald-500/50 text-emerald-100'
                : 'bg-slate-900/90 border-[#00F0FF]/50 text-cyan-100'
            }`}
          >
            {toast.type === 'error' ? (
              <AlertCircle className="w-5 h-5 text-red-400 flex-shrink-0 mt-0.5" />
            ) : toast.type === 'success' ? (
              <CheckCircle className="w-5 h-5 text-emerald-400 flex-shrink-0 mt-0.5" />
            ) : (
              <Info className="w-5 h-5 text-[#00F0FF] flex-shrink-0 mt-0.5" />
            )}
            <div className="flex-1 text-xs font-mono leading-relaxed">
              {toast.message}
            </div>
            <button
              onClick={() => setToast(null)}
              className="text-white/40 hover:text-white p-0.5"
            >
              <X className="w-4 h-4" />
            </button>
          </div>
        </div>
      )}
    </div>
  );
};
