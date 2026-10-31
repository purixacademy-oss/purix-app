import React, { useState, useEffect } from 'react';
import { SheetService } from '../services/sheetService';
import { SheetRow } from '../types';
import { ArrowLeft, FileText, Loader2, FolderX, ExternalLink } from 'lucide-react';

interface FreeContentScreenProps {
  selectedClass: string;
  onOpenPdf: (pdfUrl: string, title: string) => void;
  onBack: () => void;
}

export const FreeContentScreen: React.FC<FreeContentScreenProps> = ({
  selectedClass,
  onOpenPdf,
  onBack,
}) => {
  const [isLoading, setIsLoading] = useState(true);
  const [freeItems, setFreeItems] = useState<SheetRow[]>([]);

  useEffect(() => {
    const fetchFreeContent = async () => {
      setIsLoading(true);
      let prefix = selectedClass.includes("9") ? "9th" : (selectedClass.includes("10") || selectedClass.toLowerCase().includes("board")) ? "10th" : "8th";
      const sheetName = `${prefix} Notes`;

      try {
        const data = await SheetService.fetchSheetData(sheetName);
        const freeFiltered = data.filter((item) => {
          const access = String(item['Access Type'] || item['Is-free'] || item['is_free'] || '').trim().toUpperCase();
          return access === 'FREE';
        });

        setFreeItems(freeFiltered);
      } catch (e) {
        console.error("Error loading free matrix:", e);
      } finally {
        setIsLoading(false);
      }
    };

    fetchFreeContent();
  }, [selectedClass]);

  const handleOpenPdf = (item: SheetRow) => {
    const chapterName = String(item['Chapter'] || item['chapter'] || 'Free Resource');
    const pdfLinkHin = String(item['Drive-link-hin'] || item['Drive_link_hin'] || '');
    const pdfLinkEng = String(item['Drive-link-eng'] || item['Drive_link_eng'] || '');
    const url = (pdfLinkEng || pdfLinkHin).trim();

    if (!url || url.toUpperCase() === 'N/A' || !url.includes('http')) {
      alert('PDF link not available for this resource.');
      return;
    }

    onOpenPdf(url, chapterName);
  };

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
          {selectedClass} - FREE MATRIX
        </h1>
      </header>

      <main className="max-w-2xl w-full mx-auto px-4 py-6 flex-1">
        {isLoading ? (
          <div className="flex flex-col items-center justify-center py-20 space-y-3">
            <Loader2 className="w-8 h-8 text-[#00F0FF] animate-spin" />
            <div className="text-xs font-mono text-[#00F0FF] tracking-widest">
              QUERYING FREE ACCESS MATRIX...
            </div>
          </div>
        ) : freeItems.length === 0 ? (
          <div className="text-center py-16 px-4">
            <FolderX className="w-12 h-12 text-white/30 mx-auto mb-3" />
            <div className="text-sm font-bold text-white/70 font-mono uppercase mb-1">
              No Free Content Available Yet
            </div>
            <p className="text-xs text-white/40 font-mono">
              Ensure Google Sheet has "Access Type" = "FREE"
            </p>
          </div>
        ) : (
          <div className="space-y-3">
            {freeItems.map((item, idx) => {
              const chapterName = String(item['Chapter'] || item['chapter'] || 'Free Resource');
              const subjectName = String(item['Subject'] || item['subject'] || 'General');

              return (
                <div
                  key={idx}
                  className="bg-[#0B111E] border border-[#00F0FF]/30 rounded-xl p-4 flex items-center justify-between shadow-[0_2px_12px_rgba(0,240,255,0.06)]"
                >
                  <div className="flex items-center gap-3.5 pr-3">
                    <div className="w-10 h-10 rounded-xl bg-red-600/20 border border-red-500/40 text-red-400 flex items-center justify-center flex-shrink-0">
                      <FileText className="w-5 h-5" />
                    </div>
                    <div>
                      <h3 className="text-sm font-bold text-white tracking-wide">
                        {chapterName}
                      </h3>
                      <div className="text-[11px] font-mono text-[#00F0FF]/80 mt-0.5">
                        Subject: {subjectName} (DEMO)
                      </div>
                    </div>
                  </div>

                  <button
                    onClick={() => handleOpenPdf(item)}
                    className="px-3.5 py-2 bg-[#00F0FF] hover:bg-[#00d8e6] text-black font-bold font-mono text-xs rounded-lg transition-all flex items-center gap-1.5 flex-shrink-0 cursor-pointer active:scale-95 shadow-[0_2px_8px_rgba(0,240,255,0.3)]"
                  >
                    <span>View PDF</span>
                    <ExternalLink className="w-3 h-3" />
                  </button>
                </div>
              );
            })}
          </div>
        )}
      </main>
    </div>
  );
};
