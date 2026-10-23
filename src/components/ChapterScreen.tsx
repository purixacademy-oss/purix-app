import React, { useState, useEffect } from 'react';
import { SheetService } from '../services/sheetService';
import { StudyMode, SheetRow } from '../types';
import { 
  ArrowLeft, 
  CheckCircle, 
  Lock, 
  ChevronDown, 
  ChevronUp, 
  FileText, 
  BookOpen, 
  Loader2, 
  Zap, 
  Globe2,
  FolderX
} from 'lucide-react';

interface ChapterScreenProps {
  className: string;
  subjectName: string;
  subSubjectName: string;
  mode: StudyMode;
  onStartQuiz: (chapterName: string, setNumber: number) => void;
  onOpenPdf: (pdfUrl: string, title: string) => void;
  onBack: () => void;
  onUpgradePrompt: () => void;
}

export const ChapterScreen: React.FC<ChapterScreenProps> = ({
  className,
  subjectName,
  subSubjectName,
  mode,
  onStartQuiz,
  onOpenPdf,
  onBack,
  onUpgradePrompt,
}) => {
  const [isLoading, setIsLoading] = useState(true);
  const [isHindiLanguage, setIsHindiLanguage] = useState(false);
  const [userSubscription, setUserSubscription] = useState('FREE');
  const [expandedChapter, setExpandedChapter] = useState<string | null>(null);

  const [chapterNames, setChapterNames] = useState<string[]>([]);
  const [groupedChapters, setGroupedChapters] = useState<Record<string, SheetRow[]>>({});
  const [completedQuizSets, setCompletedQuizSets] = useState<Set<string>>(new Set());

  const loadChaptersAndUserStatus = async () => {
    setIsLoading(true);

    // 1. Check local status & completed quizzes
    const sub = localStorage.getItem('user_sub') || 'FREE';
    setUserSubscription(sub);

    const completed = new Set<string>();
    for (let i = 0; i < localStorage.length; i++) {
      const key = localStorage.key(i);
      if (key && key.startsWith(`quiz_${className}_${subjectName}_`) && localStorage.getItem(key) === 'true') {
        completed.add(key);
      }
    }
    setCompletedQuizSets(completed);

    // 2. Fetch sheet data
    let prefix = className.includes("9") ? "9th" : (className.includes("10") || className.toLowerCase().includes("board")) ? "10th" : "8th";
    let sheetName = mode === 'mcq' ? `${prefix} MCQ` : mode === 'notes' ? `${prefix} Notes` : `${prefix} practice pdf`;

    try {
      const data = await SheetService.fetchSheetData(sheetName);

      // 3. Filter by Subject & Sub-Subject
      const filtered = data.filter((item) => {
        const sub = (
          item['Subject'] || 
          item['subject'] || 
          item['SUBJECT'] || 
          item['Sub'] || 
          item['sub'] || 
          item['Subject Name'] || 
          item['विषय'] || 
          ''
        ).toString().trim().toLowerCase();
        const subSub = String(item['Sub-subject'] || item['sub-subject'] || item['Sub_subject'] || item['Branch'] || '').trim().toLowerCase();
        
        const targetSub = subjectName.trim().toLowerCase();
        const targetSubSub = subSubjectName.trim().toLowerCase();

        const matchSub = sub === targetSub;
        const matchSubSub = subSub === targetSubSub || targetSubSub === targetSub || !subSub;
        return matchSub && matchSubSub;
      });

      // 4. Group by chapter
      const tempGrouped: Record<string, SheetRow[]> = {};
      const tempNames: string[] = [];

      for (const item of filtered) {
        const chapterName = String(item['Chapter'] || item['chapter'] || 'General Chapter').trim();
        if (!tempGrouped[chapterName]) {
          tempGrouped[chapterName] = [];
          tempNames.push(chapterName);
        }
        tempGrouped[chapterName].push(item);
      }

      setGroupedChapters(tempGrouped);
      setChapterNames(tempNames);
      if (tempNames.length > 0 && !expandedChapter) {
        setExpandedChapter(tempNames[0]);
      }
    } catch (e) {
      console.error("Error loading chapter data:", e);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    loadChaptersAndUserStatus();
  }, [className, subjectName, subSubjectName, mode]);

  const toggleExpand = (name: string) => {
    setExpandedChapter(expandedChapter === name ? null : name);
  };

  const handlePdfClick = (url: string, title: string, hasAccess: boolean) => {
    if (!hasAccess) {
      onUpgradePrompt();
      return;
    }
    if (!url || url.trim() === 'N/A' || !url.includes('http')) {
      alert("Document link is currently being populated on node.");
      return;
    }
    onOpenPdf(url.trim(), title);
  };

  const handleQuizClick = (chapterName: string, setNumber: number, hasAccess: boolean) => {
    if (!hasAccess) {
      onUpgradePrompt();
      return;
    }
    onStartQuiz(chapterName, setNumber);
  };

  return (
    <div className="min-h-screen bg-[#070B14] text-white flex flex-col relative">
      {/* App Bar */}
      <header className="sticky top-0 z-30 bg-[#0A0F1D] border-b border-white/10 px-4 py-3 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <button
            onClick={onBack}
            className="p-1.5 rounded-lg bg-white/5 hover:bg-white/10 text-white transition-colors cursor-pointer"
            title="Go Back"
          >
            <ArrowLeft className="w-5 h-5" />
          </button>
          <div className="truncate">
            <h1 className="text-xs md:text-sm font-bold tracking-wider uppercase text-white font-mono truncate">
              {subSubjectName} - CHAPTERS
            </h1>
            <div className="text-[10px] font-mono text-[#00F0FF]/80 truncate">
              {subjectName} • {className}
            </div>
          </div>
        </div>

        {/* Language Toggle Chip */}
        <button
          onClick={() => setIsHindiLanguage(!isHindiLanguage)}
          className="flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-[#00F0FF]/15 border border-[#00F0FF]/40 text-[#00F0FF] text-xs font-mono font-bold tracking-wider hover:bg-[#00F0FF]/25 transition-all cursor-pointer"
        >
          <Globe2 className="w-3.5 h-3.5" />
          <span>{isHindiLanguage ? "HIN 🇮🇳" : "ENG 🌐"}</span>
        </button>
      </header>

      {/* Main Chapters View */}
      <main className="max-w-2xl w-full mx-auto px-4 py-6 flex-1">
        {isLoading ? (
          <div className="flex flex-col items-center justify-center py-20 space-y-3">
            <Loader2 className="w-8 h-8 text-[#00F0FF] animate-spin" />
            <div className="text-xs font-mono text-[#00F0FF] tracking-widest">
              COMPILING CHAPTER REGISTRY...
            </div>
          </div>
        ) : chapterNames.length === 0 ? (
          <div className="text-center py-16 px-4">
            <FolderX className="w-12 h-12 text-white/30 mx-auto mb-3" />
            <div className="text-sm font-bold text-white/70 font-mono">
              NO CHAPTER CONTENT FOUND
            </div>
            <div className="text-xs text-white/40 font-mono mt-1">
              Please verify sheet configuration for {subSubjectName}.
            </div>
          </div>
        ) : (
          <div className="space-y-3.5">
            {chapterNames.map((chapterName) => {
              const chapterItems = groupedChapters[chapterName] || [];
              const firstItem = chapterItems[0] || {};

              const accessType = String(
                firstItem['Access Type'] || firstItem['Is-free'] || firstItem['is_free'] || 'PAID'
              ).trim().toUpperCase();

              const isFreeContent = accessType === 'FREE';
              const hasAccess = isFreeContent || userSubscription.toUpperCase() === 'PRO' || userSubscription.toUpperCase() === 'ACTIVE';

              const totalQuestions = chapterItems.length;
              const totalSets = Math.max(1, Math.ceil(totalQuestions / 20));
              const isExpanded = expandedChapter === chapterName;

              return (
                <div
                  key={chapterName}
                  className={`bg-[#0B111E] rounded-2xl border transition-all overflow-hidden ${
                    hasAccess ? 'border-white/12' : 'border-red-500/30'
                  }`}
                >
                  {/* Chapter Accordion Header */}
                  <div
                    onClick={() => toggleExpand(chapterName)}
                    className="p-4 flex items-center justify-between cursor-pointer hover:bg-white/[0.02] transition-colors"
                  >
                    <div className="flex items-center gap-3">
                      <div className="p-1">
                        {hasAccess ? (
                          <CheckCircle className="w-5 h-5 text-[#00F0FF]" />
                        ) : (
                          <Lock className="w-5 h-5 text-red-400" />
                        )}
                      </div>
                      <div>
                        <h3 className={`text-sm font-bold tracking-wide ${hasAccess ? 'text-white' : 'text-white/70'}`}>
                          {chapterName}
                        </h3>
                        <p className="text-[11px] font-mono text-[#00F0FF]/70 mt-0.5">
                          {mode === 'mcq'
                            ? `${totalQuestions} Questions • ${totalSets} Sets`
                            : 'PDF Material & Notes'}
                        </p>
                      </div>
                    </div>

                    <div className="text-white/40 p-1">
                      {isExpanded ? <ChevronUp className="w-4 h-4" /> : <ChevronDown className="w-4 h-4" />}
                    </div>
                  </div>

                  {/* Chapter Expanded Items */}
                  {isExpanded && (
                    <div className="border-t border-white/10 bg-[#070B14]/40 px-4 py-3 divide-y divide-white/5 space-y-2">
                      {mode === 'mcq' ? (
                        // MCQ Mode: Sets of 20
                        Array.from({ length: totalSets }).map((_, setIdx) => {
                          const setNumber = setIdx + 1;
                          const qInThisSet =
                            setNumber === totalSets && totalQuestions % 20 !== 0
                              ? totalQuestions % 20
                              : Math.min(20, totalQuestions);

                          const setKey = `quiz_${className}_${subjectName}_${chapterName}_set_${setNumber}_completed`;
                          const isCompleted = completedQuizSets.has(setKey);

                          return (
                            <div
                              key={setNumber}
                              className="pt-2 first:pt-0 flex items-center justify-between py-2"
                            >
                              <div>
                                <div className="flex items-center gap-2">
                                  <span className="text-xs font-bold font-mono text-white">
                                    SET 0{setNumber}
                                  </span>
                                  {isCompleted && (
                                    <span className="flex items-center gap-1 font-mono text-[9px] font-bold text-[#00FF66] bg-[#00FF66]/10 border border-[#00FF66]/30 px-1.5 py-0.5 rounded">
                                      <CheckCircle className="w-3 h-3" />
                                      COMPLETED
                                    </span>
                                  )}
                                </div>
                                <div className="text-[10px] text-white/50 font-mono mt-0.5">
                                  {qInThisSet} Simulation Queries
                                </div>
                              </div>

                              <button
                                onClick={() => handleQuizClick(chapterName, setNumber, hasAccess)}
                                className={`px-4 py-1.5 rounded-lg text-xs font-mono font-bold tracking-wider transition-all cursor-pointer ${
                                  hasAccess
                                    ? 'bg-[#00FF66] hover:bg-[#00e65c] text-black shadow-[0_2px_8px_rgba(0,255,102,0.3)]'
                                    : 'bg-zinc-800 text-white/40 border border-white/10'
                                }`}
                              >
                                {hasAccess ? (isCompleted ? 'RETRY' : 'START') : 'LOCKED'}
                              </button>
                            </div>
                          );
                        })
                      ) : (
                        // Notes & Practice Sets: PDF Documents
                        chapterItems.map((item, itemIdx) => {
                          const pdfLinkHin = String(item['Drive-link-hin'] || item['Drive_link_hin'] || '');
                          const pdfLinkEng = String(item['Drive-link-eng'] || item['Drive_link_eng'] || '');
                          const selectedLink = isHindiLanguage
                            ? (pdfLinkHin || pdfLinkEng)
                            : (pdfLinkEng || pdfLinkHin);

                          const partName = chapterItems.length > 1 ? `Part ${itemIdx + 1}` : 'View Document';

                          return (
                            <div
                              key={itemIdx}
                              className="pt-2 first:pt-0 flex items-center justify-between py-2"
                            >
                              <div className="flex items-center gap-2.5">
                                {mode === 'notes' ? (
                                  <BookOpen className="w-4 h-4 text-[#BF00FF]" />
                                ) : (
                                  <FileText className="w-4 h-4 text-[#FF9900]" />
                                )}
                                <div>
                                  <div className="text-xs font-semibold text-white">
                                    {partName}
                                  </div>
                                  <div className="text-[10px] font-mono text-white/50">
                                    {isHindiLanguage ? 'Hindi Version' : 'English Version'}
                                  </div>
                                </div>
                              </div>

                              <button
                                onClick={() => handlePdfClick(selectedLink, `${chapterName} - ${partName}`, hasAccess)}
                                className={`p-2 rounded-lg transition-colors cursor-pointer ${
                                  hasAccess
                                    ? 'bg-[#00F0FF]/15 hover:bg-[#00F0FF]/30 text-[#00F0FF]'
                                    : 'bg-red-950/40 text-red-400 border border-red-500/30'
                                }`}
                                title={hasAccess ? 'Open PDF' : 'Locked PRO Content'}
                              >
                                {hasAccess ? (
                                  <FileText className="w-4 h-4" />
                                ) : (
                                  <Lock className="w-4 h-4" />
                                )}
                              </button>
                            </div>
                          );
                        })
                      )}
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        )}
      </main>
    </div>
  );
};
