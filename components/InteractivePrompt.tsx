
import React from 'react';
import type { FunctionCall } from '@google/genai';

type SubmitHandler = (command: string | { functionCall: FunctionCall }) => Promise<void>;

interface Choice {
    label: string;
    action: string | { functionCall: FunctionCall };
}

interface InteractivePromptProps {
    message: string;
    choices: Choice[];
    onSubmit: SubmitHandler;
}

export const InteractivePrompt: React.FC<InteractivePromptProps> = ({ message, choices, onSubmit }) => {
    return (
        <div className="bg-gray-800/50 border border-gray-700 rounded-md p-3">
            <p className="mb-3 text-gray-300">{message}</p>
            <div className="flex items-center gap-3">
                {choices.map((choice) => (
                    <button
                        key={choice.label}
                        onClick={() => onSubmit(choice.action)}
                        className="px-3 py-1 bg-cyan-600/50 text-cyan-200 rounded-md hover:bg-cyan-500/50 hover:text-white transition-colors focus:outline-none focus:ring-2 focus:ring-cyan-400"
                    >
                        [{choice.label.charAt(0).toUpperCase()}] {choice.label.substring(1)}
                    </button>
                ))}
            </div>
        </div>
    );
}
