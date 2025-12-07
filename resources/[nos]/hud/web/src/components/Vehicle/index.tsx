import { useMemo, useState } from 'react';
import { useNuiEvent } from '@/hooks/useNuiEvent';
import { type Postal as PostalType } from '@/interfaces/postal';

interface VehicleData {
  fuel: number;
  speed: number;
  gear: number;
  engineHealth: number;
  headlights: boolean;
  engineLight: boolean;
  oilLight: boolean;
  batteryLight: boolean;
  seatbelt: boolean;
  cruise: boolean;
}

const warningIcons = [
  {
    key: 'seatbelt',
    icon: 'fas fa-user-slash',
    title: 'Seatbelt Warning',
  },
  {
    key: 'engineLight',
    icon: 'fas fa-exclamation-triangle',
    title: 'Engine Warning',
  },
  {
    key: 'oilLight',
    icon: 'fas fa-oil-can',
    title: 'Oil Pressure',
  },
  {
    key: 'batteryLight',
    icon: 'fas fa-car-battery',
    title: 'Battery',
  },
];

export const Vehicle = ({ inVehicle, postal }: { inVehicle: boolean, postal?: PostalType }) => {
  const [vehicleData, setVehicleData] = useState<VehicleData>({
    fuel: 50,
    speed: 123,
    gear: 1,
    engineHealth: 100,
    headlights: false,
    engineLight: false,
    oilLight: false,
    batteryLight: false,
    seatbelt: true,
    cruise: false,
  });

  useNuiEvent<Partial<VehicleData>>('updateVehicle', (data) =>
    setVehicleData((prev) => ({ ...prev, ...data }))
  );

  const roundedSpeed = Math.round(vehicleData.speed);

  const updateColors = (valueStr: string) => {
    return valueStr.split('').map((digit, index, arr) => {
      const isLeadingZero = arr.slice(0, index).every((d) => d === '0');
      return digit === '0' && isLeadingZero
        ? 'rgba(255, 255, 255, 0.5)'
        : 'rgba(255, 255, 255, 1)';
    });
  };

  const speedDisplay = useMemo(() => {
    const valueStr = roundedSpeed.toString().padStart(3, '0');
    const digits = [...valueStr];
    const colors = updateColors(valueStr);
    return { digits, colors };
  }, [roundedSpeed]);

  return (
    <div className='w-screen h-screen'>
      <div
        className={`absolute gap-3 bottom-6 right-0 w-screen grid place-items-center transition-all duration-500 ease-out ${inVehicle ? 'slide-up' : 'slide-down'}
        }`}
      >
        <section className="flex items-end space-x-4 h-fit">
          <div>
            <div className="font-sans text-xs font-semibold text-white/50 text-end drop-shadow-lg tracking-wider mb-1">
              MP/H
            </div>
            <div className="flex text-center text-white text-7xl font-bold drop-shadow-2xl">
              {speedDisplay.digits.map((digit, index) => (
                <span
                  key={index}
                  className={`inline-block text-center transition-all duration-300 ease-in-out w-[1ch] ${vehicleData.cruise ? 'text-blue-400 drop-shadow-[0_0_15px_rgba(96,165,250,0.8)]' : ''
                    }`}
                  style={{
                    color: !vehicleData.cruise ? speedDisplay.colors[index] : undefined,
                    textShadow: vehicleData.cruise ? '0 0 20px rgba(96, 165, 250, 0.6)' : undefined,
                  }}
                >
                  {digit}
                </span>
              ))}
            </div>
            {vehicleData.cruise && (
              <div className="text-center text-xs font-medium text-blue-400 mt-1 tracking-wide animate-pulse">
                CRUISE CONTROL
              </div>
            )}
          </div>

          <div className="flex items-center gap-5 font-sans pb-2">
            <div className="flex flex-col justify-between gap-3 text-xs text-white font-medium">
              <span
                className={
                  vehicleData.fuel >= 90 ? 'text-white/40' : 'text-white drop-shadow-lg'
                }
              >
                F
              </span>
              <span className="text-white drop-shadow-lg fas fa-gas-pump text-base" />
              <span
                className={
                  vehicleData.fuel >= 10 ? 'text-white/40' : 'text-red-400 drop-shadow-lg animate-pulse'
                }
              >
                E
              </span>
            </div>

            <div className="flex flex-col-reverse gap-1.5">
              {(() => {
                const TOTAL_BARS = 6;
                const activeBars = Math.min(
                  TOTAL_BARS,
                  Math.round((vehicleData.fuel / 100) * TOTAL_BARS)
                );

                let activeColor = 'bg-gradient-to-t from-emerald-400 to-green-300';
                let shadowColor = 'shadow-green-400/50';
                if (activeBars === 1) {
                  activeColor = 'bg-gradient-to-t from-red-600 to-red-400';
                  shadowColor = 'shadow-red-500/50';
                } else if (activeBars === 2) {
                  activeColor = 'bg-gradient-to-t from-orange-500 to-yellow-400';
                  shadowColor = 'shadow-orange-400/50';
                }

                return [...Array(TOTAL_BARS)].map((_, index) => {
                  const isActive = index < activeBars;
                  return (
                    <div
                      key={index}
                      className={`h-2 w-5 rounded-md border transition-all duration-300 ${isActive
                        ? `${activeColor} border-transparent ${shadowColor} shadow-lg`
                        : 'bg-white/5 border-white/10'
                        }`}
                    />
                  );
                });
              })()}
            </div>
          </div>
        </section>

        <section className="flex items-center gap-8 mt-2 bg-gradient-to-br from-gray-900/70 to-gray-800/60 rounded-xl px-6 py-3 shadow-xl border border-white/10">
          {warningIcons.map(({ key, icon, title }) => (
            <span
              key={key}
              className="flex items-center justify-center transition-transform duration-200 hover:scale-110"
              title={title}
            >
              <i
                className={`${icon} text-xl transition-all duration-300 ${vehicleData[key as keyof VehicleData]
                  ? 'text-white drop-shadow-[0_0_10px_rgba(255,255,255,0.5)]'
                  : key === "seatbelt"
                    ? 'text-orange-500 animate-pulse drop-shadow-[0_0_10px_rgba(249,115,22,0.6)]'
                    : 'text-white/20'
                  }`}
                style={{
                  filter: vehicleData[key as keyof VehicleData] && key !== 'seatbelt' ? 'drop-shadow(0 0 8px rgba(255, 255, 255, 0.4))' : undefined,
                }}
              />
            </span>
          ))}
        </section>
      </div>
    </div>
  );
};
