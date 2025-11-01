import React, { useState, useRef, useEffect, useCallback } from 'react';
import { HistoryItem } from './types';
import { startChatSession } from './services/geminiService';
import { WelcomeMessage } from './components/WelcomeMessage';
import { CommandInput } from './components/CommandInput';
import { History } from './components/History';
import { useCommandHistory } from './hooks/useCommandHistory';
import { executeCommand } from './services/localCommands';
import type { Chat, FunctionCall, FunctionResponse, Part } from '@google/genai';

const App: React.FC = () => {
  const [history, setHistory] = useState<HistoryItem[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [attachedImage, setAttachedImage] = useState<string | null>(null);
  const [initError, setInitError] = useState<string | null>(null);
  const terminalRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);
  const chat = useRef<Chat | null>(null);

  useEffect(() => {
    try {
      chat.current = startChatSession();
      setHistory([{ id: Date.now(), command: '', output: <WelcomeMessage /> }]);
    } catch (error) {
      console.error("Failed to initialize chat session:", error);
      const errorMessage = error instanceof Error ? error.message : "An unknown error occurred.";
      if (errorMessage === 'API_KEY_NOT_FOUND') {
         setInitError('Gemini API Key was not found.');
      } else {
         setInitError(`Failed to initialize AI service: ${errorMessage}`);
      }
    }
  }, []);

  const {
    commandHistory,
    currentCommand,
    setCurrentCommand,
    handleKeyDown,
    addCommandToHistory,
  } = useCommandHistory();

  const scrollToBottom = () => {
    terminalRef.current?.scrollTo(0, terminalRef.current.scrollHeight);
  };

  useEffect(() => {
    scrollToBottom();
  }, [history]);
  
  useEffect(() => {
    if (!isLoading) {
      inputRef.current?.focus();
    }
  }, [isLoading]);


  const processStream = async (
    stream: AsyncGenerator<any>,
    historyItemId: number,
    isAnalysis: boolean = false
  ): Promise<FunctionCall | null> => {
    let fullText = '';
    let functionCall: FunctionCall | null = null;
    
    for await (const chunk of stream) {
        const text = chunk.text;
        if (text) {
            fullText += text;
            setHistory(prev =>
                prev.map(item =>
                    item.id === historyItemId
                        ? { ...item, output: fullText, isAnalysis }
                        : item
                )
            );
        }
        const funcCalls = chunk.functionCalls;
        if (funcCalls && funcCalls.length > 0) {
            functionCall = funcCalls[0];
        }
    }
    return functionCall;
  }

  const handleSubmit = useCallback(async (command: string | { functionCall: FunctionCall }) => {
    if (isLoading) return;
    setIsLoading(true);

    let userMessage = '';
    let isInternalCall = false;
    if (typeof command === 'string') {
        userMessage = command;
        if (!userMessage && !attachedImage) {
            setIsLoading(false);
            return;
        }
        setCurrentCommand('');
        addCommandToHistory(userMessage);
    } else {
        isInternalCall = true;
    }

    if (typeof command === 'string' && command.toLowerCase() === 'clear') {
        setHistory([
            { id: Date.now() + 1, command: '', output: <WelcomeMessage /> },
        ]);
        setAttachedImage(null);
        setIsLoading(false);
        return;
    }
    
    try {
        if (typeof command === 'string') {
            const userHistoryItemId = Date.now();
            setHistory(prev => [...prev, { id: userHistoryItemId, command, output: '', image: attachedImage }]);
            
            const messageParts: Part[] = [{ text: command }];
            if (attachedImage) {
                const mimeType = attachedImage.match(/data:(.*);base64,/)?.[1] || 'image/png';
                const base64Data = attachedImage.split(',')[1];
                messageParts.unshift({
                    inlineData: {
                        mimeType,
                        data: base64Data,
                    }
                });
            }
            setAttachedImage(null); // Clear image after sending

            const stream = await chat.current!.sendMessageStream({ message: messageParts });
            const functionCall = await processStream(stream, userHistoryItemId);

            if (functionCall) {
                await handleFunctionCall(functionCall, userHistoryItemId);
            }
        } else { // Handle internal function calls
            const internalHistoryItemId = Date.now();
            const commandName = command.functionCall.name;
            const commandText = `Internal Call: ${commandName}`;
            setHistory(prev => [...prev, { id: internalHistoryItemId, command: commandText, output: '' }]);
            await handleFunctionCall(command.functionCall, internalHistoryItemId);
        }

    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : "An unknown error occurred.";
      const output = `An error occurred: ${errorMessage}`;
      const commandText = typeof command === 'string' ? command : `Internal Call: ${command.functionCall.name}`;
      setHistory(prev => [...prev, {id: Date.now(), command: commandText, output}]);
    } finally {
      setIsLoading(false);
    }
  }, [addCommandToHistory, setCurrentCommand, isLoading, attachedImage]);

  const handleFunctionCall = async (funcCall: FunctionCall, historyId: number) => {
    const result = await executeCommand(funcCall.name, funcCall.args, handleSubmit);
            
    setHistory(prev => prev.map(item => item.id === historyId ? {...item, output: result?.display ?? 'Command executed.'} : item));

    if (!result || !result.rawData) return; 

    const analysisHistoryItemId = Date.now() + 1;
    setHistory(prev => [...prev, { id: analysisHistoryItemId, command: '', output: '', isAnalysis: true }]);

    const functionResponse: FunctionResponse = {
        name: funcCall.name,
        response: { content: result.rawData },
    };
    
    const analysisStream = await chat.current!.sendMessageStream({
        message: [
            { functionResponse }
        ]
    });
    
    await processStream(analysisStream, analysisHistoryItemId, true);
  }

  if (initError) {
      return (
          <div className="terminal-window p-8 flex flex-col text-gray-300 overflow-y-auto">
              <h1 className="text-2xl text-red-500 font-bold mb-4">Configuration Error</h1>
              <p className="mb-4">{initError}</p>
              <p>Please create a <code className="bg-gray-700 px-1 rounded">.env</code> file in the project root and add your API key:</p>
              <pre className="bg-gray-800 p-4 rounded-md mt-4 text-yellow-300">
                  <code>
                      # .env file
                      API_KEY="YOUR_GEMINI_API_KEY_HERE"
                  </code>
              </pre>
              <p className="mt-4">After adding the key, you may need to restart your development server.</p>
          </div>
      )
  }

  if (!chat.current) {
     return (
        <div className="terminal-window p-4 flex flex-col items-center justify-center text-gray-400">
            <p>Initializing AI service...</p>
        </div>
    );
  }

  return (
    <div className="terminal-window p-4 flex flex-col">
      <div
        ref={terminalRef}
        className="flex-grow overflow-y-auto pr-2 scrollbar-thin"
        onClick={() => inputRef.current?.focus()}
      >
        <History history={history} isLoading={isLoading} />
      </div>
      <CommandInput
        ref={inputRef}
        command={currentCommand}
        setCommand={setCurrentCommand}
        isLoading={isLoading}
        onKeyDown={handleKeyDown}
        onSubmit={handleSubmit}
        attachedImage={attachedImage}
        setAttachedImage={setAttachedImage}
      />
    </div>
  );
};

export default App;