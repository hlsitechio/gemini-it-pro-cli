
import React, { useState } from 'react';

// Using a basic SVG icon to avoid extra dependencies.
const CopyIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect>
    <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path>
  </svg>
);

interface CodeBlockProps {
  language: string;
  value: string;
}

export const CodeBlock: React.FC<CodeBlockProps> = ({ language, value }) => {
  const [copyText, setCopyText] = useState('Copy');

  const handleCopy = () => {
    navigator.clipboard.writeText(value).then(() => {
      setCopyText('Copied!');
      setTimeout(() => setCopyText('Copy'), 2000);
    });
  };

  return (
    <div className="bg-gray-800 rounded-md my-2 relative text-white">
      <div className="flex justify-between items-center px-4 py-1 bg-gray-700 rounded-t-md">
        <span className="text-xs text-gray-400">{language}</span>
        <button
          onClick={handleCopy}
          className="flex items-center gap-2 text-xs text-gray-400 hover:text-white transition-colors"
        >
          <CopyIcon />
          {copyText}
        </button>
      </div>
      <pre className="p-4 overflow-x-auto text-sm">
        <code>{value}</code>
      </pre>
    </div>
  );
};
