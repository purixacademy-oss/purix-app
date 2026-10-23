import React, { useState, useEffect, useMemo } from 'react';
import { SheetService } from '../services/sheetService';
import { SheetRow, StudyMode } from '../types';
import { 
  BarChart2, 
  Crown, 
  ChevronRight, 
  FlaskConical, 
  Globe, 
  Calculator, 
  Languages, 
  BookOpen, 
  Target, 
  RefreshCw 
} from 'lucide-react';

interface SubjectStat {
  subject: string;
  totalChapters: number;
  completedChapters: number;
  percentage: number;
  level: {
    name: string;
    levelNum: number;
    color: string;
    bg: string;
    border: string;
  };
}

interface LearningProgressTrackerProps {
  selectedClass: string;
  onNavigateToSubject: (mode: StudyMode, subjectName: string) => void;
  onShowMessage?: (msg: string, type?: 'info' | 'error' | 'success') => void;
}

// Calculate level based on percentage
function calculateLevel(percentage: number) {
  if (percentage >= 80) {
    return {
      name: 'Level 4 • Master',
      levelNum: 4,
      color: 'text-[#00FF88]',
      bg: 'bg-[#00FF88]/15',
      border: 'border-[#00FF88]/40',
    };
  }
  if (percentage >= 50) {
    return {
      name: 'Level 3 • Advanced',
      levelNum: 3,
      color: 'text-[#00F0FF]',
      bg: 'bg-[#00F0FF]/15',
      border: 'border-[#00F0FF]/40',
    };
  }
  if (percentage >= 20) {
    return {
      name: 'Level 2 • Intermediate',
      levelNum: 2,
      color: 'text-[#FFD700]',
      bg: 'bg-[#FFD700]/15',
      border: 'border-[#FFD700]/40',
    };
  }
  return {
    name: 'Level 1 • Beginner',
    levelNum: 1,
    color: 'text-white/70',
    bg: 'bg-white/10',
    border: 'border-white/20',
  };
}

// Normalizes subject names to Title Case
function normalizeSubjectName(raw: string): string {
  const clean = raw.trim();
  if (!clean) return '';
  
  const lower = clean.toLowerCase();
  if (lower === 'math' || lower === 'maths') return 'Mathematics';
  if (lower === 'sst') return 'Social Science';
  if (lower === 'sci') return 'Science';
  if (lower === 'hin') return 'Hindi';
  if (lower === 'san' || lower === 'sansk') return 'Sanskrit';
  if (lower === 'eng') return 'English';

  return clean.replace(/\w\S*/g, (txt: string) => txt.charAt(0).toUpperCase() + txt.substring(1).toLowerCase());
}

export const LearningProgressTracker: React.FC<LearningProgressTrackerProps> = ({
  selectedClass,
  onNavigateToSubject,
  onShowMessage,
}) => {
  const [isLoading, setIsLoading] = useState(true);
  const [subjectsList, setSubjectsList] = useState<SubjectStat[]>([]);
  const [refreshKey, setRefreshKey] = useState(0);

  const prefix = useMemo(() => {
    if (selectedClass.includes("9")) return "9th";
    if (selectedClass.includes("10") || selectedClass.toLowerCase().includes("board")) return "10th";
    return "8th";
  }, [selectedClass]);

  const loadProgressData = async (forceRefresh = false) => {
    try {
      const mcqSheetName = `${prefix} MCQ`;
      const mcqData = await SheetService.fetchSheetData(mcqSheetName, forceRefresh);

      const grouped: Record<string, Record<string, { questions: SheetRow[] }>> = {};

      const processRow = (row: SheetRow) => {
        const rawSubject = (
          row['Subject'] || row['subject'] || row['SUBJECT'] || 
          row['Sub'] || row['sub'] || row['Subject Name'] || row['विषय'] || ''
        ).toString().trim();

        const rawChapter = (
          row['Chapter'] || row['chapter'] || row['CHAPTER'] || 
          row['Chap'] || row['chap'] || row['Chapter Name'] || row['पाठ'] || row['अध्याय'] || ''
        ).toString().trim();

        if (!rawSubject || !rawChapter) return;
        const subjectKey = normalizeSubjectName(rawSubject);

        if (!grouped[subjectKey]) grouped[subjectKey] = {};
        if (!grouped[subjectKey][rawChapter]) grouped[subjectKey][rawChapter] = { questions: [] };

        grouped[subjectKey][rawChapter].questions.push(row);
      };

      for (const row of mcqData) {
        processRow(row);
      }

      const subjects = Object.keys(grouped);
      const computedList: SubjectStat[] = [];

      for (const sub of subjects) {
        const chapEntries = Object.entries(grouped[sub]);
        const totalChapters = chapEntries.length;
        let completedChapters = 0;

        for (const [chapName] of chapEntries) {
          const directKey = `chapter_completed_${selectedClass}_${sub}_${chapName}`;
          const isDirect = localStorage.getItem(directKey) === 'true';

          let setCompleted = false;
          const quizKey = `quiz_${selectedClass}_${sub}_${chapName}_set_1_completed`;
          if (localStorage.getItem(quizKey) === 'true') {
            setCompleted = true;
          }

          if (isDirect || setCompleted) {
            completedChapters++;
          }
        }

        const pct = totalChapters > 0 ? Math.round((completedChapters / totalChapters) * 100) : 0;
        computedList.push({
          subject: sub,
          totalChapters,
          completedChapters,
          percentage: pct,
          level: calculateLevel(pct),
        });
      }

      // If empty fallback
      if (computedList.length === 0) {
        computedList.push(
          { subject: 'Science', totalChapters: 14, completedChapters: 0, percentage: 0, level: calculateLevel(0) },
          { subject: 'Social Science', totalChapters: 20, completedChapters: 0, percentage: 0, level: calculateLevel(0) }
        );
      }

      setSubjectsList(computedList);
    } catch (e) {
      console.warn("Could not calculate progress:", e);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    loadProgressData(false);

    const handleUpdate = () => setRefreshKey((k) => k + 1);
    window.addEventListener('purix_progress_updated', handleUpdate);
    window.addEventListener('storage', handleUpdate);

    return () => {
      window.removeEventListener('purix_progress_updated', handleUpdate);
      window.removeEventListener('storage', handleUpdate);
    };
  }, [prefix, selectedClass, refreshKey]);

  // Overall syllabus completion across all subjects
  const overallStats = useMemo(() => {
    if (subjectsList.length === 0) {
      return { percentage: 0, level: calculateLevel(0), totalCompleted: 0, totalChaps: 0 };
    }
    const totalChaps = subjectsList.reduce((acc, s) => acc + s.totalChapters, 0);
    const totalCompleted = subjectsList.reduce((acc, s) => acc + s.completedChapters, 0);
    const pct = totalChaps > 0 ? Math.round((totalCompleted / totalChaps) * 100) : 0;
    return {
      percentage: pct,
      level: calculateLevel(pct),
      totalCompleted,
      totalChaps,
    };
  }, [subjectsList]);

  // Subject icon helper matching the reference image theme
  const getSubjectIcon = (subName: string) => {
    const s = subName.toLowerCase();
    if (s.includes('sci')) {
      return (
        <div className="w-8 h-8 rounded-xl bg-[#0088FF]/20 border border-[#0088FF]/40 flex items-center justify-center text-[#00A2FF] flex-shrink-0">
          <FlaskConical className="w-4 h-4" />
        </div>
      );
    }
    if (s.includes('social') || s.includes('sst')) {
      return (
        <div className="w-8 h-8 rounded-xl bg-[#BF00FF]/20 border border-[#BF00FF]/40 flex items-center justify-center text-[#D946EF] flex-shrink-0">
          <Globe className="w-4 h-4" />
        </div>
      );
    }
    if (s.includes('math')) {
      return (
        <div className="w-8 h-8 rounded-xl bg-[#00FF88]/20 border border-[#00FF88]/40 flex items-center justify-center text-[#00FF88] flex-shrink-0">
          <Calculator className="w-4 h-4" />
        </div>
      );
    }
    if (s.includes('hin') || s.includes('san') || s.includes('eng')) {
      return (
        <div className="w-8 h-8 rounded-xl bg-[#FFB800]/20 border border-[#FFB800]/40 flex items-center justify-center text-[#FFB800] flex-shrink-0">
          <Languages className="w-4 h-4" />
        </div>
      );
    }
    return (
      <div className="w-8 h-8 rounded-xl bg-cyan-500/20 border border-cyan-500/40 flex items-center justify-center text-cyan-400 flex-shrink-0">
        <BookOpen className="w-4 h-4" />
      </div>
    );
  };

  return (
    <div className="w-full bg-[#08101E] border border-[#00F0FF]/20 rounded-2xl p-4 md:p-5 shadow-[0_8px_32px_rgba(0,0,0,0.6)] space-y-3.5 relative overflow-hidden">
      {/* Top ambient glow */}
      <div className="absolute top-0 right-0 w-48 h-48 bg-[#00F0FF]/5 rounded-full blur-2xl pointer-events-none" />

      {/* Header: LEARNING PROGRESS + Level Badge */}
      <div className="flex items-center justify-between pb-1 relative z-10">
        <div className="flex items-center gap-2">
          <BarChart2 className="w-5 h-5 text-[#00F0FF]" />
          <h2 className="text-xs md:text-sm font-extrabold text-white tracking-wider uppercase font-mono">
            LEARNING PROGRESS
          </h2>
        </div>

        {/* Level badge with Crown icon */}
        <div className="flex items-center gap-1.5 px-3 py-1 rounded-full bg-[#121C2F] border border-white/10 text-white/90 shadow-inner">
          <Crown className="w-3.5 h-3.5 text-[#FFB800]" />
          <span className="text-[10px] font-mono font-bold">
            {overallStats.level.name}
          </span>
        </div>
      </div>

      {/* Main Overall Progress Bar */}
      <div className="space-y-1.5 relative z-10">
        <div className="flex items-center justify-between text-xs font-mono">
          <span className="text-white/60">Overall Syllabus Done</span>
          <span className="font-bold text-white text-xs">
            <span className="text-[#00FF88]">{overallStats.percentage}%</span>
            <span className="text-white/50 ml-1">({overallStats.totalCompleted}/{overallStats.totalChaps} Chapters)</span>
          </span>
        </div>
        <div className="w-full h-2 bg-[#050912] rounded-full overflow-hidden p-[1px] border border-white/10">
          <div
            className="h-full rounded-full bg-gradient-to-r from-[#00F0FF] via-[#00FF88] to-[#00FF88] transition-all duration-700"
            style={{ width: `${Math.max(2, overallStats.percentage)}%` }}
          />
        </div>
      </div>

      {/* Scrollable Subject-Wise Cards Container (WITH SMOOTH SCROLL as requested!) */}
      <div className="pt-1">
        <div className="max-h-56 overflow-y-auto pr-1 space-y-2.5 custom-scrollbar">
          {isLoading && subjectsList.length === 0 ? (
            <div className="py-6 text-center text-xs font-mono text-white/40">
              Loading syllabus matrix...
            </div>
          ) : (
            subjectsList.map((sub) => (
              <div
                key={sub.subject}
                onClick={() => onNavigateToSubject('mcq', sub.subject)}
                className="group p-2.5 md:p-3 rounded-xl bg-[#0A1324] hover:bg-[#0F1B33] border border-white/10 hover:border-[#00F0FF]/40 transition-all cursor-pointer relative"
              >
                <div className="flex items-center justify-between mb-1.5">
                  <div className="flex items-center gap-2.5">
                    {getSubjectIcon(sub.subject)}
                    <div>
                      <div className="flex items-center gap-2">
                        <span className="text-xs md:text-sm font-bold text-white group-hover:text-[#00F0FF] transition-colors">
                          {sub.subject}
                        </span>
                        <span className="text-[9px] font-mono px-2 py-0.5 rounded-full bg-white/5 border border-white/10 text-white/70">
                          {sub.level.name}
                        </span>
                      </div>
                    </div>
                  </div>

                  <div className="flex items-center gap-1.5">
                    <span className="text-xs font-mono font-bold text-white">
                      {sub.percentage}%
                    </span>
                    <span className="text-[10px] font-mono text-white/40">
                      ({sub.completedChapters}/{sub.totalChapters})
                    </span>
                    <ChevronRight className="w-3.5 h-3.5 text-white/30 group-hover:text-[#00F0FF] transition-colors" />
                  </div>
                </div>

                {/* Linear Meter */}
                <div className="w-full h-1.5 bg-[#050912] rounded-full overflow-hidden mt-1">
                  <div
                    className={`h-full rounded-full transition-all duration-500 ${
                      sub.percentage >= 80
                        ? 'bg-[#00FF88]'
                        : sub.percentage >= 50
                        ? 'bg-[#00F0FF]'
                        : sub.percentage >= 20
                        ? 'bg-[#FFD700]'
                        : 'bg-white/25'
                    }`}
                    style={{ width: `${Math.max(2, sub.percentage)}%` }}
                  />
                </div>
              </div>
            ))
          )}
        </div>
      </div>

      {/* Motivational Banner at bottom of Learning Progress Card (Matching Reference Image) */}
      <div className="rounded-xl bg-[#0A1324] border border-white/10 p-3 flex items-center justify-between relative z-10 hover:border-white/20 transition-all">
        <div className="flex items-center gap-2.5">
          <div className="w-8 h-8 rounded-xl bg-[#FFB800]/15 border border-[#FFB800]/40 flex items-center justify-center text-[#FFB800] flex-shrink-0">
            <Target className="w-4 h-4" />
          </div>
          <div>
            <div className="text-xs font-bold text-white">
              Small steps everyday lead to big results.
            </div>
            <div className="text-[10px] font-mono text-white/50">
              You're doing great! Keep it up!
            </div>
          </div>
        </div>
        <ChevronRight className="w-4 h-4 text-white/40 flex-shrink-0" />
      </div>
    </div>
  );
};
