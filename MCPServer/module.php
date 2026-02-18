<?php

declare(strict_types=1);

/**
 * Symcon MCP Server Module (Docker Client)
 *
 * Connects to a Docker-based MCP server via HTTP.
 * No longer manages Node.js processes - the MCP server runs independently in Docker.
 * This module provides a UI for configuration and connection status monitoring.
 */

class MCPServer extends IPSModule
{
    private const DEFAULT_MCP_URL = 'http://localhost:4096';

    public function Create(): void
    {
        parent::Create();
        $this->RegisterPropertyString('MCPServerURL', self::DEFAULT_MCP_URL);
        $this->RegisterPropertyString('ApiKey', '');
        $this->RegisterPropertyBoolean('Active', true);
        
        // Status variable for connection state
        $this->RegisterVariableBoolean('ConnectionStatus', $this->Translate('MCP Server Connection'), '~Switch', 0);
        $this->SetValue('ConnectionStatus', false);
        IPS_SetIcon($this->GetIDForIdent('ConnectionStatus'), 'Network');
        
        // Timer for periodic connection checks (every 60 seconds)
        $this->RegisterTimer('ConnectionCheck', 60000, 'MCPServer_CheckConnection($id);');
    }

    public function Destroy(): void
    {
        parent::Destroy();
    }

    public function ApplyChanges(): void
    {
        parent::ApplyChanges();

        $mcpUrl = trim((string) $this->ReadPropertyString('MCPServerURL'));
        $apiKey = trim((string) $this->ReadPropertyString('ApiKey'));
        $active = (bool) $this->ReadPropertyBoolean('Active');

        if (!$active) {
            $this->mcpLog('MCP-Server-Modul deaktiviert („Aktiv" aus).');
            $this->SetValue('ConnectionStatus', false);
            $this->SetTimerInterval('ConnectionCheck', 0);
            return;
        }

        if ($mcpUrl === '') {
            $this->mcpLog('Fehler: MCP Server URL ist leer.');
            $this->SetValue('ConnectionStatus', false);
            $this->SetTimerInterval('ConnectionCheck', 0);
            return;
        }

        // Validate URL format
        if (!filter_var($mcpUrl, FILTER_VALIDATE_URL)) {
            $this->mcpLog('Fehler: Ungültige MCP Server URL: ' . $mcpUrl);
            $this->SetValue('ConnectionStatus', false);
            $this->SetTimerInterval('ConnectionCheck', 0);
            return;
        }

        // Enable periodic connection checks
        $this->SetTimerInterval('ConnectionCheck', 60000);
        
        // Perform initial connection check
        $this->CheckConnection();
    }

    /**
     * Public method to check connection to MCP server.
     * Can be called from WebFront or scripts.
     */
    public function CheckConnection(): bool
    {
        $mcpUrl = trim((string) $this->ReadPropertyString('MCPServerURL'));
        $apiKey = trim((string) $this->ReadPropertyString('ApiKey'));

        if ($mcpUrl === '') {
            $this->SetValue('ConnectionStatus', false);
            return false;
        }

        $healthUrl = rtrim($mcpUrl, '/') . '/health';
        
        try {
            $context = stream_context_create([
                'http' => [
                    'method' => 'GET',
                    'timeout' => 5,
                    'ignore_errors' => true,
                    'header' => $apiKey !== '' ? "X-MCP-API-Key: $apiKey\r\n" : ''
                ]
            ]);

            $response = @file_get_contents($healthUrl, false, $context);
            
            if ($response === false) {
                $this->mcpLog('MCP Server nicht erreichbar: ' . $healthUrl);
                $this->SetValue('ConnectionStatus', false);
                return false;
            }

            $data = json_decode($response, true);
            
            if (is_array($data) && isset($data['status']) && $data['status'] === 'ok') {
                $version = $data['version'] ?? 'unknown';
                $this->mcpLog('MCP Server verbunden (v' . $version . ') - ' . $healthUrl);
                $this->SetValue('ConnectionStatus', true);
                return true;
            } else {
                $this->mcpLog('MCP Server antwortet, aber Status ist nicht OK: ' . $response);
                $this->SetValue('ConnectionStatus', false);
                return false;
            }
        } catch (Exception $e) {
            $this->mcpLog('Fehler beim Verbindungstest: ' . $e->getMessage());
            $this->SetValue('ConnectionStatus', false);
            return false;
        }
    }

    /**
     * Copy API key to clipboard (for easy pasting into MCP clients).
     * Returns the API key for display in WebFront.
     */
    public function GetAPIKey(): string
    {
        $apiKey = trim((string) $this->ReadPropertyString('ApiKey'));
        if ($apiKey === '') {
            return 'Kein API-Key konfiguriert';
        }
        return $apiKey;
    }

    /**
     * Force a connection test and return the result as human-readable text.
     */
    public function TestConnection(): string
    {
        $result = $this->CheckConnection();
        if ($result) {
            $mcpUrl = trim((string) $this->ReadPropertyString('MCPServerURL'));
            return 'Verbindung erfolgreich: ' . $mcpUrl;
        } else {
            return 'Verbindung fehlgeschlagen. Prüfen Sie die MCP Server URL und ob der Docker-Container läuft.';
        }
    }

    public function GetConfigurationForm(): string
    {
        $formPath = __DIR__ . '/form.json';
        $form = is_file($formPath) ? json_decode((string) file_get_contents($formPath), true) : null;
        if (!is_array($form) || !isset($form['elements']) || !is_array($form['elements'])) {
            return json_encode(['elements' => [['type' => 'Label', 'caption' => 'Konfiguration (form.json) nicht geladen.']]]);
        }
        
        if ($this->InstanceID <= 0) {
            return json_encode($form);
        }

        $mcpUrl = trim((string) $this->ReadPropertyString('MCPServerURL'));
        $connected = $this->GetValue('ConnectionStatus');
        
        if ($connected) {
            $statusCaption = '✓ Verbunden mit MCP Server: ' . $mcpUrl;
            $statusColor = '#28a745'; // green
        } else {
            $statusCaption = '✗ Nicht verbunden. Docker-Container läuft? URL korrekt?';
            $statusColor = '#dc3545'; // red
        }

        // Add status label at the top
        array_unshift($form['elements'], [
            'type' => 'Label',
            'caption' => $statusCaption,
            'fontSize' => 14,
            'bold' => true
        ]);

        return json_encode($form);
    }

    /** Schreibt ins Log (Meldungen/Nachrichten, Absender MCPServer). */
    private function mcpLog(string $message): void
    {
        IPS_LogMessage('MCPServer', $message);
    }
}

/**
 * Global function for testing the connection from WebFront/form.json
 * Symcon convention: {ModuleClass}_{ActionName}
 */
function MCPServer_TestConnection(int $InstanceID): string
{
    try {
        // Get the module instance from Symcon's internal registry
        $instance = @IPS_GetInstance($InstanceID);
        if (!is_array($instance)) {
            return 'Fehler: Instanz nicht gefunden';
        }
        
        // Create a temporary instance to call the method
        // Note: This assumes the autoloader or include path is properly set
        $module = new MCPServer($InstanceID);
        return $module->TestConnection();
    } catch (Throwable $e) {
        return 'Fehler beim Verbindungstest: ' . $e->getMessage();
    }
}

/**
 * Global function for periodic connection checks via timer
 * Symcon convention: {ModuleClass}_{ActionName}
 */
function MCPServer_CheckConnection(int $InstanceID): void
{
    try {
        $instance = @IPS_GetInstance($InstanceID);
        if (!is_array($instance)) {
            return;
        }
        
        $module = new MCPServer($InstanceID);
        $module->CheckConnection();
    } catch (Throwable $e) {
        IPS_LogMessage('MCPServer', 'Fehler beim Timer-Check: ' . $e->getMessage());
    }
}
