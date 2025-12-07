import React from 'react';

interface AOPProps {
  aop?: string | null;
}

export const AOP: React.FC<AOPProps> = ({ aop }) => {
  return (
    <div
      className='px-4 py-3 flex items-center gap-3 hover:bg-white/5 transition-all duration-200 border-b border-white/10 last:border-b-0'
    >
      <div className="flex items-center justify-center w-7 h-7 bg-green-500/20 rounded-lg">
        <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" className="lucide lucide-map-pin-icon lucide-map-pin text-green-400 drop-shadow-[0_0_8px_rgba(74,222,128,0.5)]"><path d="M20 10c0 4.993-5.539 10.193-7.399 11.799a1 1 0 0 1-1.202 0C9.539 20.193 4 14.993 4 10a8 8 0 0 1 16 0" /><circle cx="12" cy="10" r="3" /></svg>
      </div>
      <div className="flex flex-col">
        <span className='text-gray-400 text-xs font-medium uppercase tracking-wider'>Area of Play</span>
        <span className='text-white font-semibold text-base'>{aop || 'Unknown'}</span>
      </div>
    </div>
  );
};
