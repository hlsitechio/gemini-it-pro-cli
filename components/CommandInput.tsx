import React, { useRef, useCallback } from 'react';

const PaperclipIcon = () => (
    <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
        <path d="M21.44 11.05l-9.19 9.19a6 6 0 0 1-8.49-8.49l9.19-9.19a4 4 0 0 1 5.66 5.66l-9.2 9.19a2 2 0 0 1-2.83-2.83l8.49-8.48"></path>
    </svg>
);

const XCircleIcon = () => (
    <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="currentColor">
        <path d="M12 2C6.47 2 2 6.47 2 12s4.47 10 10 10 10-4.47 10-10S17.53 2 12 2zm5 13.59L15.59 17 12 13.41 8.41 17 7 15.59 10.59 12 7 8.41 8.41 7 12 10.59 15.59 7 17 8.41 13.41 12 17 15.59z"></path>
    </svg>
);


interface CommandInputProps {
  command: string;
  setCommand: (command: string) => void;
  isLoading: boolean;
  onKeyDown: (e: React.KeyboardEvent<HTMLInputElement>) => void;
  onSubmit: (command: string) => void;
  attachedImage: string | null;
  setAttachedImage: (image: string | null) => void;
}

const Prompt: React.FC = () => (
  <div className="flex-shrink-0">
    <span className="text-green-400">C:\Users\ITPro</span>
    <span className="text-gray-300 font-bold">&gt;</span>
  </div>
);

const BlinkingCursor: React.FC = () => (
    <span className="absolute left-0 top-1/2 -translate-y-1/2 bg-gray-300 w-2.5 h-5 inline-block animate-pulse"></span>
);

export const CommandInput = React.forwardRef<HTMLInputElement, CommandInputProps>(
  ({ command, setCommand, isLoading, onKeyDown, onSubmit, attachedImage, setAttachedImage }, ref) => {
    const fileInputRef = useRef<HTMLInputElement>(null);

    const processImageFile = useCallback((file: File | null) => {
        if (!file) return;

        const reader = new FileReader();
        reader.onload = (event) => {
            const img = new Image();
            img.onload = () => {
                const canvas = document.createElement('canvas');
                // Optional: Resize image to save on token usage for large images
                const MAX_WIDTH = 1024;
                const MAX_HEIGHT = 768;
                let width = img.width;
                let height = img.height;

                if (width > height) {
                    if (width > MAX_WIDTH) {
                        height *= MAX_WIDTH / width;
                        width = MAX_WIDTH;
                    }
                } else {
                    if (height > MAX_HEIGHT) {
                        width *= MAX_HEIGHT / height;
                        height = MAX_HEIGHT;
                    }
                }
                canvas.width = width;
                canvas.height = height;
                const ctx = canvas.getContext('2d');
                if (!ctx) return;
                
                ctx.drawImage(img, 0, 0, width, height);
                
                // Convert to a supported format (JPEG)
                const dataUrl = canvas.toDataURL('image/jpeg', 0.9); // 90% quality
                setAttachedImage(dataUrl);
            };
            img.src = event.target?.result as string;
        };
        reader.readAsDataURL(file);
    }, [setAttachedImage]);

    const handleFormSubmit = (e: React.FormEvent) => {
      e.preventDefault();
      if (!isLoading) {
        onSubmit(command);
      }
    };

    const handleImageAttach = () => {
        fileInputRef.current?.click();
    };

    const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
        const file = e.target.files?.[0];
        if (file) {
            processImageFile(file);
        }
        // Reset file input value to allow re-uploading the same file
        e.target.value = '';
    };

    const handlePaste = useCallback((e: React.ClipboardEvent<HTMLInputElement>) => {
        const items = e.clipboardData.items;
        for (let i = 0; i < items.length; i++) {
            if (items[i].type.indexOf('image') !== -1) {
                const file = items[i].getAsFile();
                if (file) {
                    processImageFile(file);
                    e.preventDefault(); // Prevent pasting text representation of the image
                    break; // Only handle the first image
                }
            }
        }
    }, [processImageFile]);


    const inputCaretClass = !isLoading && command.length === 0 && !attachedImage ? 'caret-transparent' : 'caret-gray-300';

    return (
      <form
        onSubmit={handleFormSubmit}
        className="flex items-center text-base mt-4 border-t border-gray-700/50 pt-3"
      >
        <button
            type="button"
            onClick={handleImageAttach}
            disabled={isLoading}
            className="p-2 text-gray-400 hover:text-white transition-colors rounded-full disabled:opacity-50"
            aria-label="Attach image"
        >
            <PaperclipIcon />
        </button>
        <input type="file" ref={fileInputRef} onChange={handleFileChange} accept="image/*" className="hidden" />

        <Prompt />
        <div className="relative flex-grow ml-2 flex items-center gap-2">
           {attachedImage && (
                <div className="relative group">
                    <img src={attachedImage} alt="Attached preview" className="h-8 w-auto rounded" />
                    <button
                        type="button"
                        onClick={() => setAttachedImage(null)}
                        className="absolute -top-1 -right-1 bg-gray-700 text-white rounded-full opacity-0 group-hover:opacity-100 transition-opacity"
                        aria-label="Remove image"
                    >
                        <XCircleIcon />
                    </button>
                </div>
            )}
          <input
            ref={ref}
            id="command-input"
            type="text"
            value={command}
            onChange={(e) => setCommand(e.target.value)}
            onKeyDown={onKeyDown}
            onPaste={handlePaste}
            className={`bg-transparent border-none text-gray-300 w-full focus:outline-none ${inputCaretClass}`}
            autoFocus
            disabled={isLoading}
            autoComplete="off"
            placeholder={attachedImage ? 'Describe the image...' : ''}
          />
          {!isLoading && command.length === 0 && !attachedImage && <BlinkingCursor />}
        </div>
        {isLoading && <span className="ml-4 text-yellow-400 animate-pulse">Thinking...</span>}
      </form>
    );
  }
);