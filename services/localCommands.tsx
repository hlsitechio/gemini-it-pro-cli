
import React, { useState, useEffect } from 'react';
import { InteractivePrompt } from '../components/InteractivePrompt';
import type { FunctionCall } from '@google/genai';

type SubmitHandler = (command: string | { functionCall: FunctionCall }) => Promise<void>;

interface CommandResult {
    display: React.ReactNode;
    rawData?: string;
}

// A helper component to render output with a delay, simulating a streaming response.
const StreamedOutput: React.FC<{ lines: string[], interval?: number, onComplete?: () => void }> = ({ lines, interval = 100, onComplete }) => {
    const [visibleLines, setVisibleLines] = useState<string[]>(['']);

    useEffect(() => {
        const timer = setInterval(() => {
            setVisibleLines(prev => {
                if (prev.length < lines.length) {
                    return lines.slice(0, prev.length + 1);
                }
                clearInterval(timer);
                onComplete?.();
                return prev;
            });
        }, interval);
        return () => clearInterval(timer);
    }, [lines, interval, onComplete]);

    return (
        <pre className="whitespace-pre-wrap text-sm">
            {visibleLines.join('\n')}
        </pre>
    );
};


const scanVirus = async (): Promise<CommandResult> => {
    const lines = [
        'Starting Windows Defender scan...',
        'Scan engine version: 1.1.24040.1',
        'Scanning C:\\Windows\\System32...',
        '[||||......] 25% complete. Files scanned: 15,342',
        'Scanning C:\\Users\\ITPro\\Documents...',
        '[||||||||||] 50% complete. Files scanned: 32,110',
        'No threats found in C:\\Users\\ITPro\\Documents.',
        'Scanning Program Files...',
        '[||||||||||||||] 75% complete. Files scanned: 89,567',
        'Scanning registry...',
        '[||||||||||||||||||||] 100% complete. Files scanned: 124,890',
        'Scan finished. No threats detected.',
        'Total scan time: 00:02:45'
    ];
    return {
        display: <StreamedOutput lines={lines} interval={300} />,
        rawData: 'Windows Defender scan completed successfully. No threats were detected.'
    };
};

const getNetworkConfig = async (): Promise<CommandResult> => {
    const output = `
Windows IP Configuration

   Host Name . . . . . . . . . . . . : DESKTOP-ITPRO
   Primary Dns Suffix  . . . . . . . :
   Node Type . . . . . . . . . . . . : Hybrid
   IP Routing Enabled. . . . . . . . : No
   WINS Proxy Enabled. . . . . . . . : No

Ethernet adapter Ethernet0:

   Connection-specific DNS Suffix  . : hsd1.ca.comcast.net.
   Description . . . . . . . . . . . : Intel(R) 82574L Gigabit Network Connection
   Physical Address. . . . . . . . . : 00-0C-29-1C-7F-1E
   DHCP Enabled. . . . . . . . . . . : Yes
   Autoconfiguration Enabled . . . . : Yes
   IPv4 Address. . . . . . . . . . . : 192.168.1.102(Preferred)
   Subnet Mask . . . . . . . . . . . : 255.255.255.0
   Lease Obtained. . . . . . . . . . : Sunday, July 21, 2024 8:00:00 AM
   Lease Expires . . . . . . . . . . : Monday, July 22, 2024 8:00:00 AM
   Default Gateway . . . . . . . . . : 192.168.1.1
   DHCP Server . . . . . . . . . . . : 192.168.1.1
   DNS Servers . . . . . . . . . . . : 8.8.8.8
                                       8.8.4.4
   NetBIOS over Tcpip. . . . . . . . : Enabled
    `;
    return {
        display: <pre className="whitespace-pre-wrap text-sm">{output}</pre>,
        rawData: output,
    };
};

const getSystemInfo = async (): Promise<CommandResult> => {
    const output = `
Host Name:                 DESKTOP-ITPRO
OS Name:                   Microsoft Windows 11 Pro
OS Version:                10.0.22631 N/A Build 22631
System Manufacturer:       VMware, Inc.
System Model:              VMware Virtual Platform
System Type:               x64-based PC
Processor(s):              1 Processor(s) Installed.
                           [01]: Intel64 Family 6 Model 158 Stepping 10 GenuineIntel ~2494 Mhz
BIOS Version:              VMware, Inc. VMW71.00V.19652011.B64.2204130541, 4/13/2022
Total Physical Memory:     16,384 MB
Available Physical Memory: 9,871 MB
Virtual Memory: Max Size:  20,480 MB
Virtual Memory: Available: 12,123 MB
Virtual Memory: In Use:    8,357 MB
Domain:                    WORKGROUP
    `;
     return {
        display: <pre className="whitespace-pre-wrap text-sm">{output}</pre>,
        rawData: output,
     }
};

const checkDiskHealth = async (): Promise<CommandResult> => {
     const lines = [
        'Checking C: drive for errors...',
        'The type of the file system is NTFS.',
        'CHKDSK is verifying files (stage 1 of 3)...',
        '  135168 file records processed.',
        'File verification completed.',
        'CHKDSK is verifying indexes (stage 2 of 3)...',
        '  164234 index entries processed.',
        'Index verification completed.',
        'CHKDSK is verifying security descriptors (stage 3 of 3)...',
        '  135168 security descriptors processed.',
        'Security descriptor verification completed.',
        'Windows has scanned the file system and found no problems.',
        'No further action is required.',
        '',
        '  488281249 KB total disk space.',
        '  123456789 KB in use.',
        '  364824460 KB available.',
    ];
    return {
        display: <StreamedOutput lines={lines} interval={250} />,
        rawData: 'CHKDSK completed. Windows has scanned the file system and found no problems.'
    };
};

const getRunningProcesses = async (): Promise<CommandResult> => {
    const output = `
Handles  NPM(K)    PM(K)      WS(K)     CPU(s)     Id  SI ProcessName
-------  ------    -----      -----     ------     --  -- -----------
    880      34    45820      51236       2.41   4028   1 ApplicationFrameHost
    450      21    23876      29840       0.78   8192   1 CcmExec
   1230      45   102345      98765      12.34   1234   1 chrome
    670      29    34567      41234       1.98   5678   1 explorer
   2345     110   256789     310987      45.67   9101   1 Code
    150      10     8765      12345       0.23   1121   0 csrss
`;
    return {
        display: <pre className="whitespace-pre-wrap text-sm">{output.trim()}</pre>,
        rawData: output,
    }
};

const getSystemServices = async (): Promise<CommandResult> => {
    const output = `
Status   Name               DisplayName
------   ----               -----------
Running  AppIDSvc           Application Identity
Stopped  Appinfo            Application Information
Running  AppXSvc            AppX Deployment Service (AppXSVC)
Stopped  AudioEndpointBu... Windows Audio Endpoint Builder
Running  Audiosrv           Windows Audio
Running  BITS               Background Intelligent Transfer Ser...
Stopped  Browser            Computer Browser
Running  CoreMessaging...   CoreMessaging
`;
    return {
        display: <pre className="whitespace-pre-wrap text-sm">{output.trim()}</pre>,
        rawData: output,
    };
};

const testNetworkConnection = async (args: { computerName: string; port?: number }): Promise<CommandResult> => {
    const { computerName, port = 80 } = args;
    const tcpSuccess = port === 443 || port === 80;
    const lines = [
        `Testing connection to ${computerName} on port ${port}...`,
        `ComputerName           : ${computerName}`,
        'RemoteAddress          : 172.217.1.174',
        'InterfaceAlias         : Ethernet0',
        'SourceAddress          : 192.168.1.102',
        'PingSucceeded          : True',
        'PingReplyDetails (RTT) : 12 ms',
        `TcpTestSucceeded       : ${tcpSuccess}`,
        '',
        'Connection test complete.'
    ];
    return {
        display: <StreamedOutput lines={lines} interval={200} />,
        rawData: `Connection test to ${computerName} on port ${port} completed. Ping succeeded. TCP test succeeded: ${tcpSuccess}.`
    }
};

const installPsModule = async (args: { moduleName: string, confirmNuget?: boolean }, onSubmit: SubmitHandler): Promise<CommandResult> => {
    const { moduleName, confirmNuget } = args;
    
    if(!confirmNuget) {
        return {
            display: (
                <InteractivePrompt 
                    message="PowerShellGet requires the NuGet provider to continue. Do you want to install it?"
                    choices={[
                        { label: 'Yes', action: { functionCall: { name: 'install_ps_module', args: { moduleName, confirmNuget: true }}}},
                        { label: 'No', action: 'Cancelled by user.' }
                    ]}
                    onSubmit={onSubmit}
                />
            ),
            rawData: 'User was prompted to install the NuGet provider.'
        }
    }

     const lines = [
        `NuGet provider accepted. Installing module '${moduleName}' from PSGallery...`,
        `Fetching module metadata for '${moduleName}'...`,
        `Downloading ${moduleName}.1.2.3.nupkg...`,
        '[...                ] 10%',
        '[.........          ] 45%',
        '[...............    ] 78%',
        '[...................] 100%',
        `Installing module '${moduleName}' to C:\\Program Files\\PowerShell\\Modules`,
        'Installation complete.',
    ];
    return {
        display: <StreamedOutput lines={lines} interval={250} />,
        rawData: `Module '${moduleName}' was successfully installed after user confirmed NuGet provider installation.`
    };
};

const commandExecutor: { [key: string]: (args: any, onSubmit: SubmitHandler) => Promise<CommandResult> } = {
  scan_virus: scanVirus,
  get_network_config: getNetworkConfig,
  get_system_info: getSystemInfo,
  check_disk_health: checkDiskHealth,
  get_running_processes: getRunningProcesses,
  test_network_connection: testNetworkConnection,
  get_system_services: getSystemServices,
  install_ps_module: installPsModule,
};

export const executeCommand = (name: string, args: any, onSubmit: SubmitHandler): Promise<CommandResult> | null => {
  if (commandExecutor[name]) {
    return commandExecutor[name](args, onSubmit);
  }
  return null;
};
