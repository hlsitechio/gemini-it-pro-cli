import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'jsr:@supabase/supabase-js@2';

const GEMINI_API_URL = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent';

interface ConversationContent {
  role: 'user' | 'model';
  parts: Array<{
    text?: string;
    functionCall?: FunctionCall;
    functionResponse?: FunctionResponse;
  }>;
}

interface FunctionCall {
  name: string;
  args: Record<string, any>;
}

interface FunctionResponse {
  name: string;
  response: {
    content: string;
  };
}

interface ToolResult {
  display: string;
  raw: string;
}

// System instruction for the AI agent
const SYSTEM_INSTRUCTION = `You are an expert, conversational IT support agent for Windows 11 named 'Gemini IT Pro'.
Your audience is professional IT administrators.
Your goal is to help users solve problems through a step-by-step diagnostic process. Act as a "copilot".

**Memory System:**
You have persistent memory across sessions stored in Supabase. Use it to:
- Store user preferences, names, and important information (memory_store)
- Recall previously stored information (memory_retrieve)
- Check what you remember (memory_list)
- When you see a memory exists (from memory_list), IMMEDIATELY retrieve it with memory_retrieve
- When a user introduces themselves or shares personal info, ALWAYS store it in memory
- Before saying you don't know something about the user, check memory first
- NEVER just list memories - always retrieve and tell the user what's stored

**Your Workflow:**
1. The user will describe a problem or ask a question.
2. If asked about user information (name, preferences, etc.), check memory_list or memory_retrieve first.
3. If you have a tool that can gather relevant data, **call that function**.
4. The output of that tool will be sent back to you in the next turn.
5. **You MUST analyze the tool's output** in the context of the original problem.
6. Based on your analysis, provide a concise explanation and **ask a follow-up question** to suggest the next logical step.

**Crucially, do not just call another tool immediately after the first one. Always analyze, respond with your findings, and wait for the user's confirmation before proceeding.**

**Available tools:**
- search_web: Search the internet for tools, solutions, or information
- fetch_url_content: Retrieve content from a specific URL
- memory_store: Store information persistently across sessions
- memory_retrieve: Retrieve stored information
- memory_list: List all stored memories
- memory_delete: Delete a memory entry
- execute_sql: Execute SQL queries on the Supabase database
- list_tables: List available database tables

**Communication style:**
- Be direct, technical, and professional
- Use IT terminology appropriately
- Provide actionable insights
- Ask diagnostic questions when needed`;

// Function declarations for Gemini API
const FUNCTION_DECLARATIONS = [
  {
    name: 'search_web',
    description: 'Search the internet using DuckDuckGo for information, tools, or solutions.',
    parameters: {
      type: 'OBJECT',
      properties: {
        query: { type: 'STRING', description: 'Search query' },
        maxResults: { type: 'INTEGER', description: 'Max results (default 5)' }
      },
      required: ['query']
    }
  },
  {
    name: 'fetch_url_content',
    description: 'Fetch and parse content from a webpage URL.',
    parameters: {
      type: 'OBJECT',
      properties: {
        url: { type: 'STRING', description: 'URL to fetch' }
      },
      required: ['url']
    }
  },
  {
    name: 'memory_store',
    description: 'Store information in persistent memory for later retrieval.',
    parameters: {
      type: 'OBJECT',
      properties: {
        key: { type: 'STRING', description: 'Memory key/identifier' },
        value: { type: 'STRING', description: 'Information to store' }
      },
      required: ['key', 'value']
    }
  },
  {
    name: 'memory_retrieve',
    description: 'Retrieve previously stored information from memory.',
    parameters: {
      type: 'OBJECT',
      properties: {
        key: { type: 'STRING', description: 'Memory key to retrieve' }
      },
      required: ['key']
    }
  },
  {
    name: 'memory_list',
    description: 'List all stored memory keys.',
    parameters: {
      type: 'OBJECT',
      properties: {},
      required: []
    }
  },
  {
    name: 'memory_delete',
    description: 'Delete a memory entry.',
    parameters: {
      type: 'OBJECT',
      properties: {
        key: { type: 'STRING', description: 'Memory key to delete' }
      },
      required: ['key']
    }
  },
  {
    name: 'execute_sql',
    description: 'Execute SQL queries on the Supabase database.',
    parameters: {
      type: 'OBJECT',
      properties: {
        query: { type: 'STRING', description: 'SQL query to execute' }
      },
      required: ['query']
    }
  },
  {
    name: 'list_tables',
    description: 'List available database tables and their schemas.',
    parameters: {
      type: 'OBJECT',
      properties: {},
      required: []
    }
  }
];

// Tool implementations
async function searchWeb(query: string, maxResults: number = 5): Promise<ToolResult> {
  try {
    const encodedQuery = encodeURIComponent(query);
    const url = `https://html.duckduckgo.com/html/?q=${encodedQuery}`;
    const response = await fetch(url, {
      headers: { 'User-Agent': 'Mozilla/5.0' }
    });
    
    const html = await response.text();
    const results: string[] = [];
    
    // Parse results using regex (similar to PowerShell version)
    const regex = /<a[^>]+class="[^"]*result__a[^"]*"[^>]+href="([^"]+)"[^>]*>([^<]+)<\/a>/g;
    let match;
    let count = 0;
    
    while ((match = regex.exec(html)) && count < maxResults) {
      const rawUrl = match[1];
      const title = match[2];
      
      // Extract actual URL from DuckDuckGo redirect
      const urlMatch = rawUrl.match(/uddg=([^&]+)/);
      const cleanUrl = urlMatch ? decodeURIComponent(urlMatch[1]) : rawUrl;
      
      count++;
      results.push(`${count}. ${title}\n   ${cleanUrl}\n`);
    }
    
    if (results.length === 0) {
      const output = `No results found for: ${query}`;
      return { display: output, raw: output };
    }
    
    const output = `Search results for '${query}':\n\n${results.join('')}`;
    return { display: output, raw: output };
  } catch (error) {
    const errMsg = `Search failed: ${error.message}`;
    return { display: errMsg, raw: errMsg };
  }
}

async function fetchUrlContent(url: string): Promise<ToolResult> {
  try {
    const response = await fetch(url, {
      signal: AbortSignal.timeout(10000)
    });
    
    let content = await response.text();
    
    // Basic HTML stripping
    content = content.replace(/<script[^>]*>.*?<\/script>/gs, '');
    content = content.replace(/<style[^>]*>.*?<\/style>/gs, '');
    content = content.replace(/<[^>]+>/g, ' ');
    content = content.replace(/\s+/g, ' ').trim();
    
    // Limit to first 2000 chars
    if (content.length > 2000) {
      content = content.substring(0, 2000) + '...';
    }
    
    const output = `Content from ${url}:\n${content}`;
    return { display: output, raw: content };
  } catch (error) {
    const errMsg = `Failed to fetch URL: ${error.message}`;
    return { display: errMsg, raw: errMsg };
  }
}

async function memoryStore(supabase: any, userId: string, key: string, value: string): Promise<ToolResult> {
  try {
    const { error } = await supabase
      .from('memory_store')
      .upsert({
        user_id: userId,
        key: key,
        value: value,
        timestamp: new Date().toISOString()
      }, {
        onConflict: 'user_id,key'
      });
    
    if (error) throw error;
    
    const output = `Stored in memory: ${key}`;
    return { display: output, raw: output };
  } catch (error) {
    const errMsg = `Failed to store memory: ${error.message}`;
    return { display: errMsg, raw: errMsg };
  }
}

async function memoryRetrieve(supabase: any, userId: string, key: string): Promise<ToolResult> {
  try {
    const { data, error } = await supabase
      .from('memory_store')
      .select('value, timestamp')
      .eq('user_id', userId)
      .eq('key', key)
      .single();
    
    if (error) throw error;
    
    if (!data) {
      return { display: `No memory found for key: ${key}`, raw: 'Not found' };
    }
    
    const output = `Memory [${key}] (stored ${data.timestamp}):\n${data.value}`;
    return { display: output, raw: data.value };
  } catch (error) {
    const errMsg = `Failed to retrieve memory: ${error.message}`;
    return { display: errMsg, raw: errMsg };
  }
}

async function memoryList(supabase: any, userId: string): Promise<ToolResult> {
  try {
    const { data, error } = await supabase
      .from('memory_store')
      .select('key, timestamp')
      .eq('user_id', userId)
      .order('timestamp', { ascending: false });
    
    if (error) throw error;
    
    if (!data || data.length === 0) {
      return { display: 'Memory is empty.', raw: 'Empty' };
    }
    
    const list = data.map(entry => `• ${entry.key} (stored ${entry.timestamp})`).join('\n');
    const output = `Stored memories:\n${list}`;
    return { display: output, raw: output };
  } catch (error) {
    const errMsg = `Failed to list memory: ${error.message}`;
    return { display: errMsg, raw: errMsg };
  }
}

async function memoryDelete(supabase: any, userId: string, key: string): Promise<ToolResult> {
  try {
    const { error } = await supabase
      .from('memory_store')
      .delete()
      .eq('user_id', userId)
      .eq('key', key);
    
    if (error) throw error;
    
    const output = `Deleted from memory: ${key}`;
    return { display: output, raw: output };
  } catch (error) {
    const errMsg = `Failed to delete memory: ${error.message}`;
    return { display: errMsg, raw: errMsg };
  }
}

async function executeSql(supabase: any, query: string): Promise<ToolResult> {
  try {
    const { data, error } = await supabase.rpc('execute_raw_sql', { query_text: query });
    
    if (error) throw error;
    
    const output = JSON.stringify(data, null, 2);
    return { display: `SQL Result:\n${output}`, raw: output };
  } catch (error) {
    const errMsg = `SQL execution failed: ${error.message}`;
    return { display: errMsg, raw: errMsg };
  }
}

async function listTables(supabase: any): Promise<ToolResult> {
  try {
    const { data, error } = await supabase
      .from('information_schema.tables')
      .select('table_name, table_schema')
      .eq('table_schema', 'public');
    
    if (error) throw error;
    
    const output = JSON.stringify(data, null, 2);
    return { display: `Available Tables:\n${output}`, raw: output };
  } catch (error) {
    const errMsg = `Failed to list tables: ${error.message}`;
    return { display: errMsg, raw: errMsg };
  }
}

// Tool router
async function invokeTool(functionCall: FunctionCall, supabase: any, userId: string): Promise<ToolResult> {
  const { name, args } = functionCall;
  
  switch (name) {
    case 'search_web':
      return await searchWeb(args.query, args.maxResults || 5);
    case 'fetch_url_content':
      return await fetchUrlContent(args.url);
    case 'memory_store':
      return await memoryStore(supabase, userId, args.key, args.value);
    case 'memory_retrieve':
      return await memoryRetrieve(supabase, userId, args.key);
    case 'memory_list':
      return await memoryList(supabase, userId);
    case 'memory_delete':
      return await memoryDelete(supabase, userId, args.key);
    case 'execute_sql':
      return await executeSql(supabase, args.query);
    case 'list_tables':
      return await listTables(supabase);
    default:
      return { display: `Unknown tool '${name}'`, raw: `Unknown tool '${name}'` };
  }
}

// Gemini API caller
async function invokeGeminiAPI(contents: ConversationContent[], apiKey: string) {
  const body = {
    contents,
    systemInstruction: { parts: [{ text: SYSTEM_INSTRUCTION }] },
    tools: [{ functionDeclarations: FUNCTION_DECLARATIONS }],
    generationConfig: { temperature: 0.3, maxOutputTokens: 1024 }
  };
  
  const response = await fetch(`${GEMINI_API_URL}?key=${apiKey}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body)
  });
  
  if (!response.ok) {
    throw new Error(`Gemini API error: ${response.statusText}`);
  }
  
  return await response.json();
}

// Main Edge Function handler
Deno.serve(async (req: Request) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization'
      }
    });
  }
  
  try {
    const { message, history, userId } = await req.json();
    
    if (!message || !userId) {
      return new Response(JSON.stringify({ error: 'Missing message or userId' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      });
    }
    
    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const geminiApiKey = Deno.env.get('GEMINI_API_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseKey);
    
    // Build conversation history
    const conversationHistory: ConversationContent[] = history || [];
    conversationHistory.push({
      role: 'user',
      parts: [{ text: message }]
    });
    
    // First API call
    let response = await invokeGeminiAPI(conversationHistory, geminiApiKey);
    let parts = response.candidates[0].content.parts;
    
    const textParts = parts.filter((p: any) => p.text);
    const funcParts = parts.filter((p: any) => p.functionCall);
    
    let aiResponse = '';
    
    // If there's text, capture it
    if (textParts.length > 0) {
      aiResponse = textParts.map((p: any) => p.text).join('\n');
    }
    
    // If there's a function call, execute it
    if (funcParts.length > 0) {
      const functionCall = funcParts[0].functionCall;
      
      // Add function call to history
      conversationHistory.push({
        role: 'model',
        parts: [{ functionCall }]
      });
      
      // Execute tool
      const toolResult = await invokeTool(functionCall, supabase, userId);
      
      // Add function response to history
      conversationHistory.push({
        role: 'user',
        parts: [{
          functionResponse: {
            name: functionCall.name,
            response: { content: toolResult.raw }
          }
        }]
      });
      
      // Get AI analysis of tool result
      const analysisResponse = await invokeGeminiAPI(conversationHistory, geminiApiKey);
      const analysisParts = analysisResponse.candidates[0].content.parts;
      
      const analysisText = analysisParts
        .filter((p: any) => p.text)
        .map((p: any) => p.text)
        .join('\n');
      
      aiResponse = `${toolResult.display}\n\n${analysisText}`;
      
      // Add analysis to history
      conversationHistory.push(analysisResponse.candidates[0].content);
    } else {
      // No function call, just add model response
      conversationHistory.push(response.candidates[0].content);
    }
    
    // Trim history to last 30 entries
    if (conversationHistory.length > 30) {
      conversationHistory.splice(0, conversationHistory.length - 30);
    }
    
    return new Response(JSON.stringify({
      response: aiResponse,
      history: conversationHistory
    }), {
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    });
    
  } catch (error) {
    console.error('Error:', error);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    });
  }
});
