
import React from 'react';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import { HistoryItem } from '../types';
import { CodeBlock } from './CodeBlock';

const PromptDisplay: React.FC<{ command: string; image?: string | null }> = ({ command, image }) => (
  <div className="flex items-center flex-wrap gap-2">
    <div className="flex items-center flex-shrink-0">
      <span className="text-green-400">C:\Users\ITPro</span>
      <span className="text-gray-300 font-bold">&gt;</span>
    </div>
    {image && <img src={image} alt="User attachment" className="h-10 w-auto rounded my-1" />}
    <span className="ml-2">{command}</span>
  </div>
);

const BlinkingCursor: React.FC = () => (
    <span className="bg-cyan-400 w-2 h-4 inline-block animate-blink ml-1"></span>
);

const AiResponseWrapper: React.FC<{ children: React.ReactNode }> = ({ children }) => (
    <div className="border-l-4 border-purple-400/50 pl-4 py-2 bg-black/20">
        <div className="flex items-center gap-2">
            <span className="font-bold text-purple-400 text-xs">[AI]</span>
            <div className="flex-grow">{children}</div>
        </div>
    </div>
);

export const History: React.FC<{ history: HistoryItem[], isLoading: boolean }> = ({ history, isLoading }) => {
  return (
    <div>
      {history.map((item, index) => {
        const isLastItem = index === history.length - 1;
        const isStreaming = isLastItem && isLoading && typeof item.output === 'string';

        const content = typeof item.output === 'string' ? (
            <div className="flex items-end">
            <ReactMarkdown
                remarkPlugins={[remarkGfm]}
                components={{
                code({ node, className, children, ...props }) {
                    const match = /language-(\w+)/.exec(className || '');
                    return match ? (
                    <CodeBlock language={match[1]} value={String(children).replace(/\n$/, '')} />
                    ) : (
                    <code className="bg-gray-700 text-yellow-300 px-1 rounded" {...props}>
                        {children}
                    </code>
                    );
                },
                pre({children}) {
                    return <>{children}</>;
                },
                table({children}) {
                    return <table className="table-auto border-collapse border border-slate-500">{children}</table>
                },
                th({children}) {
                    return <th className="border border-slate-600 bg-slate-700 p-2">{children}</th>
                },
                td({children}) {
                    return <td className="border border-slate-700 p-2">{children}</td>
                }
                }}
            >
                {item.output}
            </ReactMarkdown>
            {isStreaming && <BlinkingCursor />}
            </div>
        ) : (
            item.output
        );

        return (
            <div key={item.id} className="mb-4 text-sm animate-fadeIn">
                {(item.command || item.image) && <PromptDisplay command={item.command} image={item.image} />}
                <div className="mt-1 output">
                {item.isAnalysis ? <AiResponseWrapper>{content}</AiResponseWrapper> : content}
                </div>
            </div>
        );
      })}
    </div>
  );
};
