# Gemini IT Pro CLI

This is an AI-powered command-line interface for Windows 11, designed for IT professionals.

## Developer Configuration (Required)

Before running or packaging this application, you must configure your Google Gemini API key.

1.  **Get an API Key:** You can get a key from [Google AI Studio](https://aistudio.google.com/app/apikey).

2.  **Create an Environment File:**
    *   In the root directory of the project, create a new file named `.env`.
    *   Add the following line to the file, replacing the placeholder with your actual API key:

    ```
    API_KEY="YOUR_GEMINI_API_KEY_HERE"
    ```

Your build process must be configured to make this environment variable available to the application as `process.env.API_KEY`. The application code now reads the key from this standard location.

> **Security Warning:** Do not commit your `.env` file to public version control as it contains sensitive credentials.

## Installation Guide

This application is designed to be run in a web browser. To install it on your local machine for easy access, use the provided PowerShell 7 script.

### Prerequisites

1.  **PowerShell 7:** You must have PowerShell 7 or a later version installed. You can download it from the [official GitHub repository](https://github.com/PowerShell/PowerShell/releases).

2.  **Execution Policy:** You may need to set your PowerShell execution policy to allow scripts to run. You can do this by running PowerShell 7 as an administrator and executing the following command:
    ```powershell
    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
    ```

### Installation Steps

1.  **Prepare the Application Package:**
    *   **Important:** First, complete the "Developer Configuration" steps above to ensure the API key is available during your build process.
    *   Create a `.zip` file containing all the built application files and folders (`index.html`, etc.).
    *   Upload this `.zip` file to a stable hosting location (like a GitHub release, a personal server, or a cloud storage provider) and get a direct download link.

2.  **Configure the Installer Script:**
    *   Open the `install.ps1` script in a text editor.
    *   Find the `$ZipUrl` variable and replace the placeholder URL with the direct download link you created in the previous step.

3.  **Run the Script:**
    *   Download the configured `install.ps1` script to your target machine.
    *   Right-click the `install.ps1` file and select "Run with PowerShell 7".
    *   The script will handle the download, extraction, and shortcut creation automatically.

4.  **Launch the Application:**
    *   After the script finishes, you will find a new "Gemini IT Pro CLI" shortcut on your Desktop.
    *   Double-click the shortcut to open the application in your default web browser.