import React, { useState, useEffect } from 'react';
import { SheetService } from '../services/sheetService';
import { SheetRow } from '../types';
import { 
  ArrowLeft, 
  Globe2, 
  CheckCircle2, 
  XCircle, 
  Lightbulb, 
  Award, 
  RotateCcw, 
  ArrowRight,
  Loader2,
  AlertTriangle
} from 'lucide-react';

interface QuizScreenProps {
  selectedClass: string;
  subject: string;
  chapter: string;
  quizSetNumber: number;
  onExit: () => void;
}

export const QuizScreen: React.FC<QuizScreenProps> = ({
  selectedClass,
  subject,
  chapter,
  quizSetNumber,
  onExit,
}) => {
  const [isLoading, setIsLoading] = useState(true);
  const [isHindi, setIsHindi] = useState(true);
  const [questions, setQuestions] = useState<SheetRow[]>([]);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [selectedOptionLetter, setSelectedOptionLetter] = useState<string | null>(null);
  const [answered, setAnswered] = useState(false);
  const [score, setScore] = useState(0);
  const [showResultModal, setShowResultModal] = useState(false);

  const getTargetSheetName = () => {
    let prefix = "8th";
    if (selectedClass.includes("9")) {
      prefix = "9th";
    } else if (selectedClass.includes("10") || selectedClass.toLowerCase().includes("board")) {
      prefix = "10th";
    }
    return `${prefix} MCQ`;
  };

  useEffect(() => {
    const fetchQuestions = async () => {
      setIsLoading(true);
      const sheetName = getTargetSheetName();

      try {
        const data = await SheetService.fetchSheetData(sheetName);

        // Filter by subject and chapter
        const targetSub = subject.trim().toLowerCase();
        const targetChap = chapter.trim().toLowerCase();

        const filtered = data.filter((row) => {
          const rSub = String(row['Subject'] || row['subject'] || '').trim().toLowerCase();
          const rChap = String(row['Chapter'] || row['chapter'] || '').trim().toLowerCase();

          return (rSub === targetSub || !targetSub) && (rChap === targetChap || !targetChap);
        });

        const finalPool = filtered.length > 0 ? filtered : data;

        // Slice 20 questions per set
        const questionsPerSet = 20;
        const startIndex = (quizSetNumber - 1) * questionsPerSet;
        const endIndex = startIndex + questionsPerSet;

        let paginated: SheetRow[] = [];
        if (startIndex < finalPool.length) {
          paginated = finalPool.slice(startIndex, Math.min(endIndex, finalPool.length));
        } else {
          paginated = finalPool.slice(0, Math.min(20, finalPool.length));
        }

        setQuestions(paginated);
      } catch (err) {
        console.error("Error fetching quiz questions:", err);
      } finally {
        setIsLoading(false);
      }
    };

    fetchQuestions();
  }, [selectedClass, subject, chapter, quizSetNumber]);

  if (isLoading) {
    return (
      <div className="min-h-screen bg-[#070B14] text-white flex flex-col items-center justify-center p-4 space-y-3">
        <Loader2 className="w-8 h-8 text-[#00F0FF] animate-spin" />
        <div className="text-xs font-mono text-[#00F0FF] tracking-widest text-center">
          LOADING QUESTIONS FROM NODE...
        </div>
      </div>
    );
  }

  if (questions.length === 0) {
    return (
      <div className="min-h-screen bg-[#070B14] text-white flex flex-col">
        <header className="bg-[#0A0F1D] border-b border-white/10 px-4 py-3 flex items-center">
          <button onClick={onExit} className="p-1.5 rounded-lg bg-white/5 hover:bg-white/10">
            <ArrowLeft className="w-5 h-5 text-white" />
          </button>
        </header>
        <div className="flex-1 flex flex-col items-center justify-center p-6 text-center">
          <AlertTriangle className="w-12 h-12 text-[#FFD700] mb-3" />
          <h2 className="text-base font-bold text-white font-mono uppercase mb-1">
            NO QUESTIONS FOUND
          </h2>
          <p className="text-xs text-white/50 font-mono max-w-sm mb-6">
            Please check {getTargetSheetName()} in Google Sheets for chapter: {chapter}
          </p>
          <button
            onClick={onExit}
            className="px-5 py-2.5 rounded-xl bg-white/10 hover:bg-white/20 text-xs font-mono text-white"
          >
            RETURN TO CHAPTERS
          </button>
        </div>
      </div>
    );
  }

  const currentQ = questions[currentIndex];
  const progressPercent = ((currentIndex + 1) / questions.length) * 100;

  // Question text in chosen language
  const questionText = isHindi
    ? String(currentQ['MCQ hin'] || currentQ['MCQ_hin'] || currentQ['MCQ eng'] || '')
    : String(currentQ['MCQ eng'] || currentQ['MCQ_eng'] || currentQ['MCQ hin'] || '');

  // Options
  const options: Array<{ letter: 'A' | 'B' | 'C' | 'D'; text: string }> = [
    {
      letter: 'A',
      text: isHindi
        ? String(currentQ['Option A hin'] || currentQ['Option_A_hin'] || currentQ['Option A eng'] || '')
        : String(currentQ['Option A eng'] || currentQ['Option_A_eng'] || currentQ['Option A hin'] || ''),
    },
    {
      letter: 'B',
      text: isHindi
        ? String(currentQ['Option B hin'] || currentQ['Option_B_hin'] || currentQ['Option B eng'] || '')
        : String(currentQ['Option B eng'] || currentQ['Option_B_eng'] || currentQ['Option B hin'] || ''),
    },
    {
      letter: 'C',
      text: isHindi
        ? String(currentQ['Option C hin'] || currentQ['Option_C_hin'] || currentQ['Option C eng'] || '')
        : String(currentQ['Option C eng'] || currentQ['Option_C_eng'] || currentQ['Option C hin'] || ''),
    },
    {
      letter: 'D',
      text: isHindi
        ? String(currentQ['Option D hin'] || currentQ['Option_D_hin'] || currentQ['Option D eng'] || '')
        : String(currentQ['Option D eng'] || currentQ['Option_D_eng'] || currentQ['Option D hin'] || ''),
    },
  ];

  const correctLetter = String(currentQ['Answer'] || currentQ['answer'] || 'A').trim().toUpperCase();

  const explanation = isHindi
    ? String(currentQ['Explanation hin'] || currentQ['Explanation_hin'] || '')
    : String(currentQ['Explanation eng'] || currentQ['Explanation_eng'] || '');

  const handleSelectOption = (letter: 'A' | 'B' | 'C' | 'D') => {
    if (answered) return;

    setSelectedOptionLetter(letter);
    setAnswered(true);

    if (letter.toUpperCase() === correctLetter) {
      setScore((prev) => prev + 1);
    }
  };

  const handleNextQuestion = () => {
    if (currentIndex < questions.length - 1) {
      setCurrentIndex((prev) => prev + 1);
      setSelectedOptionLetter(null);
      setAnswered(false);
    } else {
      // Completed full quiz! Save state
      try {
        const key = `quiz_${selectedClass}_${subject}_${chapter}_set_${quizSetNumber}_completed`;
        localStorage.setItem(key, 'true');
        localStorage.setItem(`chapter_completed_${selectedClass}_${subject}_${chapter}`, 'true');
        window.dispatchEvent(new Event('purix_progress_updated'));
      } catch (e) {
        console.warn("Could not save quiz completion:", e);
      }
      setShowResultModal(true);
    }
  };

  const handleRestartQuiz = () => {
    setShowResultModal(false);
    setCurrentIndex(0);
    setSelectedOptionLetter(null);
    setAnswered(false);
    setScore(0);
  };

  return (
    <div className="min-h-screen bg-[#070B14] text-white flex flex-col relative select-none">
      {/* Quiz Header */}
      <header className="sticky top-0 z-30 bg-[#0A0F1D] border-b border-white/10 px-4 py-3 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <button
            onClick={onExit}
            className="p-1.5 rounded-lg bg-white/5 hover:bg-white/10 text-[#00F0FF] transition-colors cursor-pointer"
            title="Exit Simulation"
          >
            <ArrowLeft className="w-5 h-5" />
          </button>
          <div className="truncate">
            <div className="flex items-center gap-2">
              <span className="text-[11px] font-mono text-[#00F0FF] font-bold tracking-wider">
                // {subject.toUpperCase()}
              </span>
              <span className="text-[9px] font-mono font-bold text-[#00FF66] bg-[#00FF66]/15 border border-[#00FF66]/40 px-1.5 rounded">
                SET 0{quizSetNumber}
              </span>
            </div>
            <h2 className="text-xs md:text-sm font-bold text-white truncate max-w-xs md:max-w-md">
              {chapter}
            </h2>
          </div>
        </div>

        {/* Language Toggle Chip */}
        <button
          onClick={() => setIsHindi(!isHindi)}
          className="flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-[#101726] border border-[#00F0FF] text-[#00F0FF] text-xs font-mono font-bold tracking-wider hover:bg-[#00F0FF]/20 transition-all cursor-pointer"
        >
          <Globe2 className="w-3.5 h-3.5" />
          <span>{isHindi ? "HIN 🇮🇳" : "ENG 🌐"}</span>
        </button>
      </header>

      {/* Main Quiz Body */}
      <main className="max-w-2xl w-full mx-auto px-4 py-5 flex-1 flex flex-col justify-between">
        <div className="space-y-4">
          {/* Progress HUD */}
          <div className="space-y-2">
            <div className="flex items-center justify-between text-[11px] font-mono font-bold tracking-wider">
              <span className="text-[#00F0FF]">
                PHASE 0{currentIndex + 1} / 0{questions.length}
              </span>
              <span className="text-[#00FF66]">
                SCORE: {score}
              </span>
            </div>

            <div className="w-full h-1.5 bg-white/10 rounded-full overflow-hidden">
              <div
                className="h-full bg-[#00F0FF] transition-all duration-300"
                style={{ width: `${progressPercent}%` }}
              />
            </div>
          </div>

          {/* Question Box */}
          <div className="bg-[#0D1524] border border-[#00F0FF]/35 rounded-2xl p-5 shadow-[0_4px_20px_rgba(0,240,255,0.08)]">
            <div className="text-[10px] font-mono font-bold text-[#00F0FF]/70 tracking-widest mb-2">
              // QUERY MATRIX
            </div>
            <p className="text-sm md:text-base font-bold text-white leading-relaxed">
              {questionText || "Question text not available in selected language."}
            </p>
          </div>

          {/* Options List */}
          <div className="space-y-2.5">
            {options.map((opt) => {
              const letter = opt.letter;
              const text = opt.text;

              let cardBg = 'bg-[#0B111E]';
              let borderColor = 'border-white/12';
              let badgeColor = 'text-[#00F0FF] bg-[#00F0FF]/15 border-[#00F0FF]/40';
              let isCorrect = false;
              let isWrong = false;

              if (answered) {
                if (letter === correctLetter) {
                  cardBg = 'bg-[#00FF66]/12';
                  borderColor = 'border-[#00FF66] shadow-[0_0_12px_rgba(0,255,102,0.25)]';
                  badgeColor = 'text-[#00FF66] bg-[#00FF66]/20 border-[#00FF66]';
                  isCorrect = true;
                } else if (letter === selectedOptionLetter) {
                  cardBg = 'bg-[#FF0055]/12';
                  borderColor = 'border-[#FF0055] shadow-[0_0_12px_rgba(255,0,85,0.25)]';
                  badgeColor = 'text-[#FF0055] bg-[#FF0055]/20 border-[#FF0055]';
                  isWrong = true;
                }
              }

              return (
                <div
                  key={letter}
                  onClick={() => handleSelectOption(letter)}
                  className={`border rounded-xl p-3.5 flex items-center justify-between cursor-pointer transition-all duration-150 ${cardBg} ${borderColor} ${
                    !answered ? 'hover:border-[#00F0FF]/50 hover:bg-[#0f1729]' : ''
                  }`}
                >
                  <div className="flex items-center gap-3.5 flex-1 pr-2">
                    <span className={`w-7 h-7 rounded-md border flex items-center justify-center font-mono font-bold text-xs flex-shrink-0 ${badgeColor}`}>
                      {letter}
                    </span>
                    <span className="text-xs md:text-sm font-semibold text-white leading-relaxed">
                      {text}
                    </span>
                  </div>

                  {isCorrect && (
                    <CheckCircle2 className="w-5 h-5 text-[#00FF66] flex-shrink-0" />
                  )}
                  {isWrong && (
                    <XCircle className="w-5 h-5 text-[#FF0055] flex-shrink-0" />
                  )}
                </div>
              );
            })}
          </div>

          {/* Explanation Box */}
          {answered && explanation && (
            <div className="bg-[#101726] border border-[#FFD700]/40 rounded-xl p-3.5 mt-2">
              <div className="flex items-center gap-2 text-[#FFD700] text-[11px] font-mono font-bold mb-1">
                <Lightbulb className="w-4 h-4" />
                <span>EXPLANATION / समाधान</span>
              </div>
              <p className="text-xs text-white/80 leading-relaxed">
                {explanation}
              </p>
            </div>
          )}
        </div>

        {/* Bottom Proceed Action Button */}
        <div className="pt-5 pb-3">
          {answered ? (
            <button
              onClick={handleNextQuestion}
              className="w-full py-3 bg-[#00F0FF]/20 hover:bg-[#00F0FF]/30 border border-[#00F0FF] text-[#00F0FF] font-mono font-bold text-xs tracking-widest rounded-xl transition-all shadow-[0_0_15px_rgba(0,240,255,0.2)] flex items-center justify-center gap-2 cursor-pointer active:scale-98"
            >
              <span>
                {currentIndex === questions.length - 1 ? 'TERMINATE SIMULATION' : 'PROCEED TO NEXT QUERY'}
              </span>
              <ArrowRight className="w-4 h-4" />
            </button>
          ) : (
            <div className="text-center font-mono text-[10px] text-white/40 tracking-wider">
              SELECT AN OPTION TO REGISTER ANSWER MATRIX
            </div>
          )}
        </div>
      </main>

      {/* Simulation Complete Result Modal */}
      {showResultModal && (
        <div className="fixed inset-0 z-50 bg-black/85 backdrop-blur-md flex items-center justify-center p-4">
          <div className="w-full max-w-sm bg-[#0B111E] border border-[#00F0FF] rounded-2xl p-6 shadow-[0_0_40px_rgba(0,240,255,0.25)] text-center">
            <Award className="w-12 h-12 text-[#00FF66] mx-auto mb-2 animate-bounce" />
            <div className="text-[11px] font-mono font-bold text-[#00F0FF] tracking-[0.2em] uppercase mb-1">
              // SIMULATION COMPLETE
            </div>
            <div className="text-xs font-mono text-white/70 mb-4">
              SET 0{quizSetNumber} EVALUATION
            </div>

            <div className="bg-[#00FF66]/10 border border-[#00FF66]/40 rounded-xl py-3 px-6 inline-block mb-3">
              <span className="text-3xl font-black font-mono text-[#00FF66] tracking-wider">
                {score} / {questions.length}
              </span>
            </div>

            <p className="text-xs text-white/70 font-mono mb-6">
              {score === questions.length
                ? 'PERFECT MATRIX OVERRIDE! 🎯'
                : 'GOOD EFFORT • RE-SIMULATE FOR 100%'}
            </p>

            <div className="flex items-center gap-3">
              <button
                onClick={onExit}
                className="flex-1 py-2.5 rounded-xl border border-white/20 hover:bg-white/10 text-white/80 font-mono text-xs font-bold transition-colors cursor-pointer"
              >
                EXIT
              </button>
              <button
                onClick={handleRestartQuiz}
                className="flex-1 py-2.5 bg-[#00F0FF]/20 hover:bg-[#00F0FF]/30 border border-[#00F0FF] text-[#00F0FF] font-mono text-xs font-bold rounded-xl transition-all flex items-center justify-center gap-1.5 cursor-pointer"
              >
                <RotateCcw className="w-3.5 h-3.5" />
                <span>RE-ENGAGE</span>
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
