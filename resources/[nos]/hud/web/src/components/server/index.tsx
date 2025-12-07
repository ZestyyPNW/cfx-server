import React from 'react';
import { AOP } from './AOP';
import { Peacetime } from './Peacetime';
import { Prio } from './Prio';
import Compass from '../Vehicle/Compass';

export { AOP, Peacetime, Prio };

export const ServerStatus: React.FC<{ inVehicle: boolean; postal?: { code: string; dist: number }; data: { aop: string; peacetime: boolean; priority: any }; visible: boolean }> = ({ inVehicle, postal, data, visible }) => {
  return (
    <section className='absolute top-44 right-8 flex flex-col items-end space-y-2'>
      <div className={`text-sm text-white transition-all duration-500 ${visible ? "slide-up" : "slide-down"}`}>
        <div className="bg-gradient-to-br w-fit from-gray-900/90 to-gray-800/85 rounded-xl border border-white/20 shadow-2xl overflow-hidden space-y-1">
          <Prio priority={data.priority} />
          <AOP aop={data.aop} />
          <Peacetime peacetime={data.peacetime} />
        </div>
      </div>
      <Compass inVehicle={inVehicle} postal={postal} />
    </section>
  );
};
