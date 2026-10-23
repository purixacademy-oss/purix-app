import React, { useState } from 'react';
import { ArrowLeft, ExternalLink, Loader2, Maximize2 } from 'lucide-react';

interface PdfViewerScreenProps {
  pdfUrl: string;
  title: string;
  onBack: () => void;
}

export const PdfViewerScreen: React.FC<PdfViewerScreenProps> = ({
  pdfUrl,
  title,
  onBack,
}) => {
  const [isLoading, setIsLoading] = useState(true);

  // Format Google Drive links into preview embed format
  let finalUrl = pdfUrl.trim();
  if (finalUrl.includes('drive.google.com')) {
    finalUrl = finalUrl
      .replace('/view?usp=sharing', '/preview')
      .replace('/view', '/preview');
  }

  const handleOpenExternal = () => {
    window.open(finalUrl, '_blank', 'noopener,noreferrer');
  };

  return (
    <div className="min-h-screen bg-[#070B14] text-white flex flex-col fixed inset-0 z-50">
      {/* Viewer Header */}
      <header className="bg-[#0A0F1D] border-b border-white/10 px-4 py-3 flex items-center justify-between z-10">
        <div className="flex items-center gap-3 truncate">
          <button
            onClick={onBack}
            className="p-1.5 rounded-lg bg-white/5 hover:bg-white/10 text-[#00F0FF] transition-colors cursor-pointer"
            title="Go Back"
          >
            <ArrowLeft className="w-5 h-5" />
          </button>
          <h1 className="text-xs md:text-sm font-bold tracking-wider uppercase text-white font-mono truncate">
            {title}
          </h1>
        </div>

        <button
          onClick={handleOpenExternal}
          className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-white/10 hover:bg-white/20 text-[#00F0FF] text-xs font-mono font-bold transition-all cursor-pointer"
          title="Open in new window"
        >
          <span>DIRECT LINK</span>
          <ExternalLink className="w-3.5 h-3.5" />
        </button>
      </header>

      {/* Embedded Iframe View */}
      <div className="flex-1 w-full relative bg-[#070B14] overflow-hidden">
        {isLoading && (
          <div className="absolute inset-0 flex flex-col items-center justify-center space-y-3 z-10 bg-[#070B14]">
            <Loader2 className="w-8 h-8 text-[#00F0FF] animate-spin" />
            <div className="text-xs font-mono text-[#00F0FF] tracking-widest">
              INITIALIZING SECURE PDF VIEWER...
            </div>
          </div>
        )}

        <iframe
          src={finalUrl}
          title={title}
          onLoad={() => setIsLoading(false)}
          className="w-full h-full border-0"
          allow="autoplay"
        />
      </div>
    </div>
  );
};
