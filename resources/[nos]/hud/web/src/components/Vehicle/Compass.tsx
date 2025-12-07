import { debugData } from "@/utils/debugData";
import { memo, useState } from "react";

import { useNuiEvent } from "@/hooks/useNuiEvent";

debugData([{ action: "setCompassVisible", data: true }], 1000)
debugData([{ action: "setStreet", data: { a: "Rockford Hills", b: "Palomino Ave", direction: 'North', crossStreet: 'Palomino Ave' } }], 1000)

const Compass = ({ inVehicle, postal }: { inVehicle: boolean; postal?: { code: string; dist: number } }) => {
  const [street, setStreet] = useState<{
    a: string;
    b: string;
    direction?: string;
    crossStreet?: string;
  }>({ a: 'Mission Row', b: 'Chilliad Mountain State Wilderness', direction: 'North', crossStreet: '' })

  useNuiEvent('setStreet', setStreet)

  return (
    <main
      className={`z-50 transition-all duration-500 ${inVehicle ? 'slide-up' : 'slide-down'}`}
    >
      <div className="relative w-fit">
        <div className="mt-2 bg-gradient-to-br from-gray-900/90 to-gray-800/85 rounded-xl border border-white/20 shadow-2xl overflow-hidden hover:border-white/30 transition-all duration-300">
          <div className="p-4 px-5 text-left flex flex-col items-start space-y-1">
            <div className="flex items-center gap-2">
              <span className="text-white font-semibold text-lg tracking-wide drop-shadow-lg">({street.direction}) {street.a}</span>
            </div>
            <span className="text-gray-300 text-sm font-medium">{street.b}</span>
            {postal && (
              <div className="flex items-center justify-between gap-2.5 pt-2 mt-2">
                <svg className="w-4 h-4 text-blue-400 drop-shadow-[0_0_6px_rgba(255,255,255,.5)]" fill="#fff" viewBox="0 0 20 20">
                  <path fillRule="evenodd" d="M5.05 4.05a7 7 0 119.9 9.9L10 18.9l-4.95-4.95a7 7 0 010-9.9zM10 11a2 2 0 100-4 2 2 0 000 4z" clipRule="evenodd" />
                </svg>
                <span className="text-white text-sm font-semibold">{postal.code}</span>
                <span className="text-gray-500 text-sm">•</span>
                <span className="text-gray-300 text-sm font-medium">{postal.dist}m</span>
              </div>
            )}
          </div>
        </div>
      </div>
    </main>
  );
};

export default memo(Compass);