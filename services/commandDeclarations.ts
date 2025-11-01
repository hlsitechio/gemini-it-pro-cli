
import { FunctionDeclaration, Type } from '@google/genai';

export const commandDeclarations: FunctionDeclaration[] = [
  {
    name: 'scan_virus',
    description: 'Triggers a system virus scan using the default antivirus software (Windows Defender).',
    parameters: {
      type: Type.OBJECT,
      properties: {},
      required: [],
    },
  },
  {
    name: 'get_network_config',
    description: 'Retrieves and displays detailed IP configuration for all network adapters, similar to ipconfig /all.',
    parameters: {
      type: Type.OBJECT,
      properties: {},
      required: [],
    },
  },
  {
    name: 'get_system_info',
    description: 'Displays detailed hardware and software information about the computer, similar to systeminfo.',
    parameters: {
      type: Type.OBJECT,
      properties: {},
      required: [],
    },
  },
  {
    name: 'check_disk_health',
    description: 'Checks the C: drive for errors and displays a status report, similar to chkdsk.',
    parameters: {
      type: Type.OBJECT,
      properties: {},
      required: [],
    },
  },
  {
    name: 'get_running_processes',
    description: 'Lists all currently running processes on the local machine, similar to the PowerShell cmdlet Get-Process.',
    parameters: {
      type: Type.OBJECT,
      properties: {},
      required: [],
    },
  },
  {
    name: 'test_network_connection',
    description: 'Performs a network connection test to a specified host and port, similar to Test-NetConnection.',
    parameters: {
        type: Type.OBJECT,
        properties: {
            computerName: {
                type: Type.STRING,
                description: 'The hostname or IP address to test the connection to. (e.g., "google.com", "8.8.8.8")',
            },
            port: {
                type: Type.INTEGER,
                description: 'The TCP port to test the connection on. Defaults to 80 if not specified.',
            },
        },
        required: ['computerName'],
    },
  },
  {
      name: 'get_system_services',
      description: 'Lists all system services and their current status (Running, Stopped), similar to Get-Service.',
      parameters: {
          type: Type.OBJECT,
          properties: {},
          required: [],
      },
  },
  {
      name: 'install_ps_module',
      description: 'Finds and installs a PowerShell module from the PowerShell Gallery.',
      parameters: {
          type: Type.OBJECT,
          properties: {
              moduleName: {
                  type: Type.STRING,
                  description: 'The name of the PowerShell module to install (e.g., "Posh-Git", "dbatools").',
              },
          },
          required: ['moduleName'],
      },
  },
];
