import React from 'react';
import { 
  Building2, 
  ChevronRight, 
  Sparkles, 
  Flame, 
  ArrowLeft,
  BookOpen,
  GraduationCap,
  Lightbulb,
  Star
} from 'lucide-react';

interface ClassScreenProps {
  userName: string;
  selectedBoard?: string;
  currentClass?: string;
  isSwitching?: boolean;
  onSelectClass: (selectedClass: string) => void;
  onChangeBoard?: () => void;
  onBack?: () => void;
}

export const ClassScreen: React.FC<ClassScreenProps> = ({ 
  userName, 
  selectedBoard = 'Bihar Board (BSEB)',
  currentClass,
  isSwitching = false,
  onSelectClass,
  onChangeBoard,
  onBack
}) => {
  const classes = [
    { title: 'Class 8', desc: 'Foundations & Concepts', icon: Lightbulb },
    { title: 'Class 9', desc: 'Core Syllabus & Concepts', icon: BookOpen },
    { title: 'Class 10th', desc: 'Board Target & Mock Drills', icon: GraduationCap },
    { title: 'Board Special', desc: 'Crash Course & High-Yield', icon: Star, hot: true },
  ];

  return (
    <div className="min-h-screen bg-[#070B14] text-white px-4 py-8 flex flex-col justify-center items-center relative overflow-hidden">
      {/* Background glow effects */}
      <div className="absolute top-10 right-1/4 w-96 h-96 bg-[#D4AF37]/10 rounded-full blur-[100px] pointer-events-none" />
      <div className="absolute bottom-10 left-1/4 w-96 h-96 bg-[#00F0FF]/10 rounded-full blur-[100px] pointer-events-none" />

      <div className="w-full max-w-xl mx-auto z-10">
        {/* Back navigation button if switching */}
        {isSwitching && onBack && (
          <div className="mb-4">
            <button
              onClick={onBack}
              className="inline-flex items-center gap-2 text-xs font-mono text-white/70 hover:text-white transition-colors bg-[#0E1626] border border-white/10 px-3 py-1.5 rounded-lg"
            >
              <ArrowLeft className="w-3.5 h-3.5" />
              <span>BACK TO DASHBOARD</span>
            </button>
          </div>
        )}

        {/* Header */}
        <div className="text-center mb-6">
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-[#D4AF37]/10 border border-[#D4AF37]/30 text-[#D4AF37] font-mono text-[11px] tracking-widest uppercase mb-3">
            <Sparkles className="w-3.5 h-3.5" />
            <span>SYLLABUS SELECTION</span>
          </div>
          <h1 className="text-2xl md:text-3xl font-black text-[#D4AF37] tracking-[0.15em] mb-2 uppercase">
            SELECT CADET CLASS
          </h1>
          <h2 className="text-sm font-bold text-white mb-1">
            Welcome, {userName || 'Cadet'} 👋
          </h2>
          <p className="text-xs text-white/60 font-mono">
            Select your standard to personalize your learning dashboard.
          </p>
        </div>

        {/* Active Board Bar */}
        <div className="mb-6 p-3.5 rounded-xl bg-[#0E1626] border border-[#00F0FF]/30 flex items-center justify-between shadow-lg">
          <div className="flex items-center gap-3">
            <div className="p-2 rounded-lg bg-[#00F0FF]/15 text-[#00F0FF]">
              <Building2 className="w-5 h-5" />
            </div>
            <div>
              <div className="text-[10px] font-mono font-bold tracking-widest text-white/40 uppercase">
                ACTIVE BOARD
              </div>
              <div className="text-sm font-bold text-white">
                {selectedBoard}
              </div>
            </div>
          </div>

          {onChangeBoard && (
            <button
              onClick={onChangeBoard}
              className="text-xs font-mono font-bold text-[#00F0FF] hover:text-[#00F0FF]/80 px-3 py-1.5 rounded-lg border border-[#00F0FF]/30 hover:border-[#00F0FF] bg-[#00F0FF]/10 transition-colors cursor-pointer"
            >
              CHANGE
            </button>
          )}
        </div>

        <div className="text-[11px] font-mono font-bold tracking-widest text-white/40 uppercase mb-3">
          TARGET CLASS
        </div>

        <div className="space-y-3.5">
          {classes.map((item) => {
            const isSpecial = item.hot;
            const isSelected = currentClass === item.title;
            const Icon = item.icon;

            return (
              <div
                key={item.title}
                onClick={() => onSelectClass(item.title)}
                className={`group cursor-pointer rounded-2xl p-4 md:p-5 transition-all duration-200 border transform hover:-translate-y-0.5 active:scale-[0.99] ${
                  isSelected
                    ? 'bg-[#0E1626] border-[#00F0FF] border-2 shadow-[0_0_20px_rgba(0,240,255,0.2)]'
                    : isSpecial
                    ? 'bg-[#D4AF37]/12 border-[#D4AF37] shadow-[0_4px_20px_rgba(212,175,55,0.18)] hover:bg-[#D4AF37]/20 hover:border-[#FFD700]'
                    : 'bg-[#0E1626] border-white/10 hover:border-[#D4AF37]/60 hover:bg-[#121c33]'
                }`}
              >
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-3.5">
                    <div className={`p-2.5 rounded-xl ${isSelected ? 'bg-[#00F0FF]/15 text-[#00F0FF]' : isSpecial ? 'bg-[#D4AF37]/20 text-[#D4AF37]' : 'bg-white/5 text-[#D4AF37]'}`}>
                      <Icon className="w-5 h-5" />
                    </div>
                    <div>
                      <div className="flex items-center gap-2.5 mb-0.5">
                        <span className={`text-base md:text-lg font-bold tracking-wide ${isSelected ? 'text-[#00F0FF]' : isSpecial ? 'text-[#D4AF37]' : 'text-white'}`}>
                          {item.title}
                        </span>
                        {isSpecial && (
                          <span className="flex items-center gap-1 bg-[#D4AF37] text-black text-[10px] font-black tracking-wider px-2 py-0.5 rounded-md">
                            <Flame className="w-3 h-3 fill-black text-black" />
                            HOT
                          </span>
                        )}
                      </div>
                      <p className="text-xs text-white/60 font-mono leading-relaxed">
                        {item.desc}
                      </p>
                    </div>
                  </div>

                  <div className="pl-4">
                    <div className="w-8 h-8 rounded-full bg-[#070B14]/60 border border-[#D4AF37]/40 flex items-center justify-center text-[#D4AF37] group-hover:bg-[#D4AF37] group-hover:text-black transition-all">
                      <ChevronRight className="w-4 h-4" />
                    </div>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
};
