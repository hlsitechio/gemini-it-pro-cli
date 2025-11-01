
import React from 'react';

export interface HistoryItem {
  id: number;
  command: string;
  output: React.ReactNode;
  isAnalysis?: boolean;
  image?: string | null;
}
