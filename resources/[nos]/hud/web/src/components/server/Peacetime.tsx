import React from 'react';

interface PeacetimeProps {
  peacetime?: boolean | null;
}

export const Peacetime: React.FC<PeacetimeProps> = ({ peacetime }) => {
  return (
    <div
      className='px-4 py-3 flex items-center gap-3 hover:bg-white/5 transition-all duration-200 border-b border-white/10 last:border-b-0'
    >
      <div className={`flex items-center justify-center w-7 h-7 rounded-lg ${peacetime ? 'bg-blue-500/20' : 'bg-gray-500/20'}`}>
        <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" className={`lucide lucide-shield-icon lucide-shield ${peacetime ? 'text-blue-400 drop-shadow-[0_0_8px_rgba(96,165,250,0.5)]' : 'text-gray-400'}`}><path d="M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z" /></svg>
      </div>
      <div className="flex flex-col">
        <span className='text-gray-400 text-xs font-medium uppercase tracking-wider'>Peacetime</span>
        <span className={`font-semibold text-base ${peacetime ? 'text-blue-400' : 'text-gray-300'}`}>{peacetime ? 'Enabled' : 'Disabled'}</span>
      </div>
    </div>
  );
};
