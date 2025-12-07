import React from 'react';

interface PrioProps {
  priority?: {
    enabled: boolean;
    name: string;
  } | null;
}

export const Prio: React.FC<PrioProps> = ({ priority }) => {
  const name = priority ? priority.name : 'Normal';
  const isActive = priority?.enabled;
  return (
    <div
      className='px-4 py-3 flex items-center gap-3 hover:bg-white/5 transition-all duration-200 border-b border-white/10 last:border-b-0'
    >
      <div className={`flex items-center justify-center w-7 h-7 rounded-lg ${isActive ? 'bg-red-500/20' : 'bg-gray-500/20'}`}>
        <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" className={`lucide lucide-siren-icon lucide-siren ${isActive ? 'text-red-400 drop-shadow-[0_0_8px_rgba(248,113,113,0.5)] animate-pulse' : 'text-gray-400'}`}><path d="M7 18v-6a5 5 0 1 1 10 0v6" /><path d="M5 21a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-1a2 2 0 0 0-2-2H7a2 2 0 0 0-2 2z" /><path d="M21 12h1" /><path d="M18.5 4.5 18 5" /><path d="M2 12h1" /><path d="M12 2v1" /><path d="m4.929 4.929.707.707" /><path d="M12 12v6" /></svg>
      </div>
      <div className="flex flex-col">
        <span className='text-gray-400 text-xs font-medium uppercase tracking-wider'>Priority</span>
        <span className={`font-semibold text-base ${isActive ? 'text-red-400' : 'text-gray-300'}`}>{name}</span>
      </div>
    </div>
  );
};
