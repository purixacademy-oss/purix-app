import React from 'react';
import { ChevronRight, Sparkles, Flame } from 'lucide-react';

interface ClassScreenProps {
  userName: string;
  onSelectClass: (selectedClass: string) => void;
}

export const ClassScreen: React.FC<ClassScreenProps> = ({ userName, onSelectClass }) => {
  const classes = [
    { title: 'Class 8', desc: 'Foundation, Concepts & Practice' },
    { title: 'Class 9', desc: 'Pre-Board Core Concepts & Notes' },
    { title: 'Class 10th', desc: 'Board Exam Mastery, High-Yield Qs' },
    { title: 'Board Special', desc: 'Target Crash Course, Formulas & Mock Tests', hot: true },
  ];

  return (
    <div className="min-h-screen bg-[#070B14] text-white px-4 py-8 flex flex-col justify-center items-center relative overflow-hidden">
      {/* Background glow effects */}
      <div className="absolute top-10 right-1/4 w-96 h-96 bg-[#D4AF37]/10 rounded-full blur-[100px] pointer-events-none" />
      <div className="absolute bottom-10 left-1/4 w-96 h-96 bg-[#00F0FF]/10 rounded-full blur-[100px] pointer-events-none" />

      <div className="w-full max-w-xl mx-auto z-10">
        <div className="text-center mb-8">
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-[#D4AF37]/10 border border-[#D4AF37]/30 text-[#D4AF37] font-mono text-[11px] tracking-widest uppercase mb-3">
            <Sparkles className="w-3.5 h-3.5" />
            <span>SYLLABUS SELECTION</span>
          </div>
          <h1 className="text-2xl md:text-3xl font-black text-[#D4AF37] tracking-[0.15em] mb-2 uppercase">
            SELECT YOUR CLASS
          </h1>
          <h2 className="text-lg font-bold text-white mb-1">
            Welcome, {userName || 'Cadet'} 👋
          </h2>
          <p className="text-xs text-white/60 font-mono">
            Select your standard to personalize your learning dashboard.
          </p>
        </div>

        <div className="space-y-4">
          {classes.map((item) => {
            const isSpecial = item.hot;

            return (
              <div
                key={item.title}
                onClick={() => onSelectClass(item.title)}
                className={`group cursor-pointer rounded-2xl p-5 transition-all duration-200 border transform hover:-translate-y-0.5 active:scale-[0.99] ${
                  isSpecial
                    ? 'bg-[#D4AF37]/12 border-[#D4AF37] shadow-[0_4px_20px_rgba(212,175,55,0.18)] hover:bg-[#D4AF37]/20 hover:border-[#FFD700]'
                    : 'bg-[#0F172A] border-[#D4AF37]/25 hover:border-[#D4AF37]/60 hover:bg-[#121c33]'
                }`}
              >
                <div className="flex items-center justify-between">
                  <div>
                    <div className="flex items-center gap-2.5 mb-1.5">
                      <span className={`text-lg md:text-xl font-bold tracking-wide ${isSpecial ? 'text-[#D4AF37]' : 'text-white'}`}>
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

                  <div className="pl-4">
                    <div className="w-9 h-9 rounded-full bg-[#070B14]/60 border border-[#D4AF37]/40 flex items-center justify-center text-[#D4AF37] group-hover:bg-[#D4AF37] group-hover:text-black transition-all">
                      <ChevronRight className="w-5 h-5" />
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
