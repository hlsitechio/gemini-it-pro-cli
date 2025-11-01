
import React, { useState, useCallback } from 'react';

export const useCommandHistory = () => {
  const [commandHistory, setCommandHistory] = useState<string[]>([]);
  const [historyIndex, setHistoryIndex] = useState<number>(-1);
  const [currentCommand, setCurrentCommand] = useState('');

  const addCommandToHistory = useCallback((command: string) => {
    if(command.trim() !== '') {
        setCommandHistory(prev => [command, ...prev]);
        setHistoryIndex(-1);
    }
  }, []);

  const handleKeyDown = useCallback((e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'ArrowUp') {
      e.preventDefault();
      if (historyIndex < commandHistory.length - 1) {
        const newIndex = historyIndex + 1;
        setHistoryIndex(newIndex);
        setCurrentCommand(commandHistory[newIndex]);
      }
    } else if (e.key === 'ArrowDown') {
      e.preventDefault();
      if (historyIndex > 0) {
        const newIndex = historyIndex - 1;
        setHistoryIndex(newIndex);
        setCurrentCommand(commandHistory[newIndex]);
      } else {
        setHistoryIndex(-1);
        setCurrentCommand('');
      }
    }
  }, [commandHistory, historyIndex]);

  return {
    commandHistory,
    currentCommand,
    setCurrentCommand,
    handleKeyDown,
    addCommandToHistory,
  };
};
