import React, { useState, useEffect } from 'react';
import { SheetService } from '../services/sheetService';
import { StudyMode } from '../types';
import { 
  ArrowLeft, 
  RefreshCw, 
  Layers, 
  Zap, 
  BookOpen, 
  Network, 
  ChevronRight, 
  Loader2,
  FolderX
} from 'lucide-react';

interface SubjectScreenProps {
  selectedClass: string;
  mode: StudyMode;
  onSelectSubject: (subjectName: string) => void;
  onBack: () => void;
}

export const SubjectScreen: React.FC<SubjectScreenProps> = ({
  selectedClass,
  mode,
  onSelectSubject,
  onBack,
}) => {
  const [isLoading, setIsLoading] = useState(true);
  const [subjectsList, setSubjectsList] = useState<string[]>([]);

  const getTargetSheetName = () => {
    let prefix = "8th";
    if (selectedClass.includes("9")) {
      prefix = "9th";
    } else if (selectedClass.includes("10") || selectedClass.toLowerCase().includes("board")) {
      prefix = "10th";
    }

    if (mode === 'mcq') {
      return `${prefix} MCQ`;
    } else if (mode === 'notes') {
      return `${prefix} Notes`;
    } else {
      return `${prefix} practice pdf`;
    }
  };

  const loadSubjects = async (force = false) => {
    setIsLoading(true);
    const targetSheet = getTargetSheetName();

    try {
      const data = await SheetService.fetchSheetData(targetSheet, force);
      const uniqueSubjects = new Set<string>();

      for (const row of data) {
        const rawSubject = (
          row['Subject'] || 
          row['subject'] || 
          row['SUBJECT'] || 
          row['Sub'] || 
          row['sub'] || 
          row['Subject Name'] || 
          row['विषय'] || 
          ''
        ).toString().trim();

        if (rawSubject) {
          // Normalize case so "math" or "Math" displays cleanly
          const normalized = rawSubject.replace(/\w\S*/g, (txt: string) => txt.charAt(0).toUpperCase() + txt.substring(1).toLowerCase());
          uniqueSubjects.add(normalized);
        }
      }

      setSubjectsList(Array.from(uniqueSubjects));
    } catch (e) {
      console.error("Error loading subjects:", e);
      setSubjectsList([]);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    loadSubjects(false);
  }, [selectedClass, mode]);

  // Color theme per mode
  let titleText = `${selectedClass} - Subjects`;
  let themeGlow = '#00FF66';
  let ModeIcon = Zap;

  if (mode === 'mcq') {
    titleText = `${selectedClass} - MCQ Tests`;
    themeGlow = '#00FF66';
    ModeIcon = Zap;
  } else if (mode === 'practice') {
    titleText = `${selectedClass} - Practice Sets`;
    themeGlow = '#FF9900';
    ModeIcon = Network;
  } else {
    titleText = `${selectedClass} - Purix Notes`;
    themeGlow = '#BF00FF';
    ModeIcon = BookOpen;
  }

  return (
    <div className="min-h-screen bg-[#070B14] text-white flex flex-col relative">
      {/* Header */}
      <header className="sticky top-0 z-30 bg-[#0A0F1D] border-b border-white/10 px-4 py-3 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <button
            onClick={onBack}
            className="p-1.5 rounded-lg bg-white/5 hover:bg-white/10 text-white transition-colors cursor-pointer"
            title="Go Back"
          >
            <ArrowLeft className="w-5 h-5" />
          </button>
          <h1 className="text-sm font-bold tracking-wider uppercase text-white font-mono">
            {titleText}
          </h1>
        </div>

        <button
          onClick={() => loadSubjects(true)}
          disabled={isLoading}
          className="p-2 rounded-lg bg-white/5 hover:bg-white/10 text-[#00F0FF] transition-colors cursor-pointer"
          title="Refresh Subjects"
        >
          <RefreshCw className={`w-4 h-4 ${isLoading ? 'animate-spin' : ''}`} />
        </button>
      </header>

      {/* Main Content */}
      <main className="max-w-2xl w-full mx-auto px-4 py-6 flex-1">
        {isLoading ? (
          <div className="flex flex-col items-center justify-center py-20 space-y-3">
            <Loader2 className="w-8 h-8 text-[#00F0FF] animate-spin" />
            <div className="text-xs font-mono text-[#00F0FF] tracking-widest">
              LOADING SUBJECTS FROM NODE...
            </div>
          </div>
        ) : subjectsList.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-20 px-4 text-center">
            <FolderX className="w-12 h-12 text-white/30 mb-3" />
            <div className="text-sm font-bold text-white/70 tracking-wider uppercase mb-1 font-mono">
              NO SUBJECTS FOUND
            </div>
            <p className="text-[11px] text-white/40 font-mono max-w-xs">
              Ensure records exist in sheet: {getTargetSheetName()}
            </p>
            <button
              onClick={() => loadSubjects(true)}
              className="mt-5 px-4 py-2 rounded-xl bg-white/10 hover:bg-white/20 text-xs font-mono text-white transition-colors"
            >
              Retry Node Query
            </button>
          </div>
        ) : (
          <div className="space-y-3.5">
            {subjectsList.map((subject) => (
              <div
                key={subject}
                onClick={() => onSelectSubject(subject)}
                style={{
                  borderColor: `${themeGlow}44`,
                }}
                className="group bg-[#0B111E] hover:bg-[#0f1729] border rounded-2xl p-4 flex items-center justify-between cursor-pointer transition-all duration-200 transform hover:-translate-y-0.5 active:scale-[0.99] shadow-[0_4px_16px_rgba(0,0,0,0.3)]"
              >
                <div className="flex items-center gap-3.5">
                  <div
                    style={{
                      backgroundColor: `${themeGlow}20`,
                      color: themeGlow,
                    }}
                    className="w-11 h-11 rounded-xl flex items-center justify-center"
                  >
                    <ModeIcon className="w-5 h-5" />
                  </div>
                  <div>
                    <h3 className="text-sm md:text-base font-bold text-white tracking-wider uppercase">
                      {subject}
                    </h3>
                    <p
                      style={{ color: `${themeGlow}b3` }}
                      className="text-[11px] font-mono mt-0.5"
                    >
                      Tap to view chapters & topics
                    </p>
                  </div>
                </div>

                <ChevronRight className="w-4 h-4 text-white/40 group-hover:text-white group-hover:translate-x-0.5 transition-all" />
              </div>
            ))}
          </div>
        )}
      </main>
    </div>
  );
};
