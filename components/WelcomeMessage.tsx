
import React from 'react';

const ASCII_LOGO = `
   ______                           ___ ___
  / ____/___   ____   ____ ___     /   |   |
 / / __ / _ \\ / __ \\ / __ \`__ \\   / /| |   |
/ /_/ //  __// /_/ // / / / / /  / / | |   |
\\____/ \\___/ \\____//_/ /_/ /_/  /_/  |_|___|
`;

export const WelcomeMessage: React.FC = () => {
  return (
    <div className="text-sm">
      <pre className="text-cyan-400 font-bold text-xs md:text-sm leading-tight">{ASCII_LOGO}</pre>
      <p className="mt-2 mb-6 text-gray-400">
        (c) Gemini Corporation. All rights reserved. Welcome, IT Professional.
      </p>

      <div className="space-y-4 mb-6">
        <div>
          <h2 className="text-green-400 font-bold mb-1">▶ System Commands</h2>
          <p className="text-gray-400 pl-4">Check system health, network status, and run diagnostics.</p>
        </div>
        <div>
          <h2 className="text-yellow-400 font-bold mb-1">▶ PowerShell Tools</h2>
          <p className="text-gray-400 pl-4">Manage processes, services, and test network connections.</p>
        </div>
        <div>
          <h2 className="text-purple-400 font-bold mb-1">▶ AI Assistance</h2>
          <p className="text-gray-400 pl-4">Generate scripts, explain errors, and get technical answers.</p>
        </div>
      </div>

      <p>Type <span className="text-cyan-400 bg-gray-800 px-1 py-0.5 rounded">'help'</span> for a full list of example commands.</p>
      <p>Type <span className="text-cyan-400 bg-gray-800 px-1 py-0.5 rounded">'clear'</span> to clear the terminal history.</p>
    </div>
  );
};