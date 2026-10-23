import React, { useState, useEffect } from 'react';
import { SheetService } from '../services/sheetService';
import { StudyMode } from '../types';
import { ArrowLeft, ChevronRight, Loader2, GitBranch } from 'lucide-react';

interface SubSubjectScreenProps {
  className: string;
  subjectName: string;
  mode: StudyMode;
  onSelectSubSubject: (subSubjectName: string) => void;
  onBack: () => void;
}

export const SubSubjectScreen: React.FC<SubSubjectScreenProps> = ({
  className,
  subjectName,
  mode,
  onSelectSubSubject,
  onBack,
}) => {
  const [isLoading, setIsLoading] = useState(true);
  const [uniqueSubSubjects, setUniqueSubSubjects] = useState<string[]>([]);

  useEffect(() => {
    const loadSubSubjects = async () => {
      setIsLoading(true);
      let prefix = className.includes("9") ? "9th" : (className.includes("10") || className.toLowerCase().includes("board")) ? "10th" : "8th";
      let sheetName = mode === 'mcq' ? `${prefix} MCQ` : mode === 'notes' ? `${prefix} Notes` : `${prefix} practice pdf`;

      try {
        const data = await SheetService.fetchSheetData(sheetName);
        const subSubs = new Set<string>();

        for (const row of data) {
          const sub = String(row['Subject'] || row['subject'] || '').trim();
          if (sub.toLowerCase() === subjectName.toLowerCase()) {
            const subSubject = String(row['Sub-subject'] || row['sub-subject'] || row['Sub_subject'] || '').trim();
            if (subSubject) {
              subSubs.add(subSubject);
            }
          }
        }

        // If no explicit sub-subjects found, fall back to default branch name
        if (subSubs.size === 0) {
          subSubs.add(subjectName);
        }

        setUniqueSubSubjects(Array.from(subSubs));
      } catch (e) {
        console.error("Error loading sub-subjects:", e);
        setUniqueSubSubjects([subjectName]);
      } finally {
        setIsLoading(false);
      }
    };

    loadSubSubjects();
  }, [className, subjectName, mode]);

  return (
    <div className="min-h-screen bg-[#070B14] text-white flex flex-col relative">
      <header className="sticky top-0 z-30 bg-[#0A0F1D] border-b border-white/10 px-4 py-3 flex items-center gap-3">
        <button
          onClick={onBack}
          className="p-1.5 rounded-lg bg-white/5 hover:bg-white/10 text-white transition-colors cursor-pointer"
          title="Go Back"
        >
          <ArrowLeft className="w-5 h-5" />
        </button>
        <h1 className="text-xs md:text-sm font-bold tracking-wider uppercase text-white font-mono truncate">
          {subjectName} - BRANCHES
        </h1>
      </header>

      <main className="max-w-2xl w-full mx-auto px-4 py-6 flex-1">
        {isLoading ? (
          <div className="flex flex-col items-center justify-center py-20 space-y-3">
            <Loader2 className="w-8 h-8 text-[#00F0FF] animate-spin" />
            <div className="text-xs font-mono text-[#00F0FF] tracking-widest">
              PARSING BRANCH NODES...
            </div>
          </div>
        ) : uniqueSubSubjects.length === 0 ? (
          <div className="text-center py-16 text-white/50 text-xs font-mono">
            No branches found for this module.
          </div>
        ) : (
          <div className="space-y-3">
            {uniqueSubSubjects.map((subSub) => (
              <div
                key={subSub}
                onClick={() => onSelectSubSubject(subSub)}
                className="bg-[#0B111E] hover:bg-[#0f1729] border border-white/12 hover:border-[#00F0FF]/40 rounded-xl p-4 flex items-center justify-between cursor-pointer transition-all duration-200 transform hover:-translate-y-0.5"
              >
                <div className="flex items-center gap-3">
                  <div className="w-9 h-9 rounded-lg bg-[#00F0FF]/10 text-[#00F0FF] flex items-center justify-center">
                    <GitBranch className="w-4 h-4" />
                  </div>
                  <span className="text-sm font-bold text-white tracking-wider uppercase">
                    {subSub}
                  </span>
                </div>
                <ChevronRight className="w-4 h-4 text-white/40" />
              </div>
            ))}
          </div>
        )}
      </main>
    </div>
  );
};
