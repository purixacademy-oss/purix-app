import React, { useState } from 'react';
import { 
  Building2, 
  GraduationCap, 
  BookOpen, 
  ChevronRight, 
  CheckCircle2, 
  ArrowLeft,
  Sparkles,
  Layers
} from 'lucide-react';

interface BoardScreenProps {
  userName: string;
  currentBoard?: string;
  isSwitching?: boolean;
  onSelectBoard: (boardName: string) => void;
  onBack?: () => void;
}

export const BoardScreen: React.FC<BoardScreenProps> = ({
  userName,
  currentBoard = 'Bihar Board (BSEB)',
  isSwitching = false,
  onSelectBoard,
  onBack,
}) => {
  const [selectedBoard, setSelectedBoard] = useState<string>(currentBoard);

  const boards = [
    {
      name: 'Bihar Board (BSEB)',
      code: 'BSEB',
      icon: Building2,
      color: '#00F0FF',
      borderColor: 'border-[#00F0FF]',
      bgColor: 'bg-[#00F0FF]/10',
      badgeColor: 'bg-[#00F0FF]/15 text-[#00F0FF] border-[#00F0FF]/40',
      tag: 'Hindi & English Medium',
      desc: 'NCERT/SCERT Syllabus, High-Yield Model Sets & Formula Bank',
    },
    {
      name: 'CBSE Board',
      code: 'CBSE',
      icon: GraduationCap,
      color: '#FFB800',
      borderColor: 'border-[#FFB800]',
      bgColor: 'bg-[#FFB800]/10',
      badgeColor: 'bg-[#FFB800]/15 text-[#FFB800] border-[#FFB800]/40',
      tag: 'All India NCERT',
      desc: 'Competency Based Questions, Case Studies & Chapter Notes',
    },
    {
      name: 'Jharkhand Board (JAC)',
      code: 'JAC',
      icon: BookOpen,
      color: '#00FF88',
      borderColor: 'border-[#00FF88]',
      bgColor: 'bg-[#00FF88]/10',
      badgeColor: 'bg-[#00FF88]/15 text-[#00FF88] border-[#00FF88]/40',
      tag: 'JAC Board Target',
      desc: 'JAC Board NCERT Pattern, Model Question Papers & Practice',
    },
  ];

  const handleChoose = (boardName: string) => {
    setSelectedBoard(boardName);
    onSelectBoard(boardName);
  };

  return (
    <div className="min-h-screen bg-[#070B14] text-white px-4 py-8 flex flex-col justify-center items-center relative overflow-hidden">
      {/* Background ambient lighting */}
      <div className="absolute top-10 right-1/4 w-96 h-96 bg-[#D4AF37]/10 rounded-full blur-[100px] pointer-events-none" />
      <div className="absolute bottom-10 left-1/4 w-96 h-96 bg-[#00F0FF]/10 rounded-full blur-[100px] pointer-events-none" />

      <div className="w-full max-w-xl mx-auto z-10">
        {/* Navigation bar if switching */}
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
            <span>EXAM BOARD SELECTION</span>
          </div>
          <h1 className="text-2xl md:text-3xl font-black text-[#D4AF37] tracking-[0.15em] mb-2 uppercase">
            SELECT EDUCATION BOARD
          </h1>
          <p className="text-xs text-white/60 font-mono">
            Cadet {userName || 'Student'} • Choose your board to load dedicated questions & study sheets
          </p>
        </div>

        {/* Cadet Info Banner */}
        <div className="mb-6 p-3.5 rounded-xl bg-[#0D1424] border border-[#00F0FF]/25 flex items-center gap-3">
          <div className="p-2 rounded-lg bg-[#00F0FF]/10 text-[#00F0FF]">
            <Layers className="w-5 h-5" />
          </div>
          <div className="flex-1">
            <div className="text-xs font-bold text-white">Cadet {userName}</div>
            <div className="text-[11px] text-white/60 font-mono">
              Dedicated board-specific question sets and formulas will be activated.
            </div>
          </div>
        </div>

        <div className="text-[11px] font-mono font-bold tracking-widest text-white/40 uppercase mb-3">
          CHOOSE YOUR BOARD
        </div>

        {/* Board Options */}
        <div className="space-y-3.5">
          {boards.map((b) => {
            const isCurrent = selectedBoard === b.name;
            const Icon = b.icon;

            return (
              <div
                key={b.name}
                onClick={() => handleChoose(b.name)}
                className={`cursor-pointer rounded-2xl p-5 transition-all duration-200 border transform hover:-translate-y-0.5 active:scale-[0.99] bg-[#0D1424] ${
                  isCurrent
                    ? `${b.borderColor} border-2 shadow-[0_0_25px_rgba(0,240,255,0.15)]`
                    : 'border-white/10 hover:border-white/30'
                }`}
              >
                <div className="flex items-start gap-4">
                  <div
                    className={`w-12 h-12 rounded-xl flex items-center justify-center flex-shrink-0 ${b.bgColor} border ${
                      isCurrent ? b.borderColor : 'border-white/10'
                    }`}
                    style={{ color: b.color }}
                  >
                    <Icon className="w-6 h-6" />
                  </div>

                  <div className="flex-1">
                    <div className="flex items-center justify-between mb-1">
                      <h3 className="text-base font-bold text-white tracking-wide">
                        {b.name}
                      </h3>
                      <span className={`text-[10px] font-mono font-bold px-2 py-0.5 rounded border ${b.badgeColor}`}>
                        {b.code}
                      </span>
                    </div>

                    <div
                      className="text-xs font-semibold mb-1"
                      style={{ color: b.color }}
                    >
                      {b.tag}
                    </div>

                    <p className="text-[11px] text-white/55 leading-relaxed font-mono">
                      {b.desc}
                    </p>
                  </div>

                  <div className="pt-2 flex-shrink-0">
                    {isCurrent ? (
                      <CheckCircle2 className="w-5 h-5 text-[#00F0FF]" />
                    ) : (
                      <ChevronRight className="w-5 h-5 text-white/30" />
                    )}
                  </div>
                </div>
              </div>
            );
          })}
        </div>

        {/* Footer info */}
        <div className="mt-6 text-center text-[10px] font-mono text-white/35">
          ⚡ Dedicated Board Database • Cached till 12:00 AM Midnight
        </div>
      </div>
    </div>
  );
};
