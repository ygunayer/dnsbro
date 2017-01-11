###############################################
# Initialize Globals and Defaults             #
###############################################

param(
    [string]$action = "show"
)

$argv = $args

$defaultConfig = @"
{{CONFIG_FILE_CONTENTS}}
"@

$configPath = $env:APPDATA + "\dnsbro\config.json"

###############################################
# Network and Configuration Functions         #
###############################################

# Load configuration
Function Lib_LoadConfig {
    if (Test-Path $configPath) {
        Try {
            Return Get-Content $configPath | ConvertFrom-Json
        } Catch {
            Throw "Failed to load the configuration file at " + $configPath
        }
    }
    
    Write-Host "No configuration found, writing defaults to" $configPath

    Lib_WriteDefaults

    return ConvertFrom-Json $defaultConfig
}

# Write configuration
Function Lib_WriteConfig($cfg) {
    $cfg | Out-File $configPath
}

# Write default configuration
Function Lib_WriteDefaults {
    Lib_WriteConfig($defaultConfig)
}

# Get the default network adapter
Function Lib_GetAdapter {
    $adapters = Get-NetAdapter -Physical
    $count = ($adapters | Measure-Object).count

    if ($count -eq 0) {
        Throw "No network adapter found"
    }

    if ($count -eq 1) {
        Return $adapters[0]
    }

    $adapterNames = $adapters | % { $i = 1 } { "`r`n" + $i + ". " + $_.Name + " (" + ($_ | Get-NetIPAddress -AddressFamily IPv4).IPv4Address + ")"; $i++ }
    Write-Host "Please select a network adapter:" $adapterNames
    $idx = Read-Host

    if (($idx -lt 1) -or ($idx -gt $count)) {
        Throw "Invalid index", $idx
    }

    Return $adapters[$idx - 1]
}

# Reset the DNS servers for the given network adapter, setting them to DHCP configuration
Function Lib_ResetDnsServers($adapter) {
    Set-DnsClientServerAddress -InterfaceAlias $adapter.Name -ResetServerAddresses
    Write-Host "Adapter" $adapter.Name "is now set to use the default DNS servers from its DHCP configuration"
}

# Set the DNS servers for the given network adapter
Function Lib_SetDnsServers($adapter, $addresses) {
    Set-DnsClientServerAddress -InterfaceAlias $adapter.Name -ServerAddresses $addresses
    Action_FlushCache
    Write-Host "Adapter" $adapter.Name "is now using the following DNS servers:" $addresses
}

# Set the DNS server addresses for the given configuration name
Function Lib_SetConfiguration($name, $addresses) {
    $config | Add-Member -MemberType NoteProperty -Name $name -Value $addresses
    Lib_WriteConfig ($config | ConvertTo-Json)
    Write-Host "Configured" $name "to refer to the following IP addresses:" ([string]::Join(", ", $config.$name))
}


###############################################
# Utility/Helper Functions                    #
###############################################

# Format the configured servers as a readable text
Function Util_FormatConfig {
    Return ($config.psobject.properties.name | % { $i = 1 } { [string]($i) + ". " + $_ + ": " + [string]::Join(", ", $config.$_); $i++ })
}

# Check if the given string is a valid IP address
Function Util_IsValidIPAddress($str) {
    Try {
        [ipaddress]$str
        Return $true
    } Catch {
        Return $false
    }
}

# Common function to get a server name and a list of IP addresses
Function Util_ReadServerConfigInput($checkOverwrite, $skipAddressCountCheck) {
    $name = $argv[0]
    if (!$name) {
        Throw "No server name provided"
    }

    if (!$skipAddressCountCheck -and $argv.Length -lt 2) {
        Throw "No IP address provided"
    }

    $addresses = ($argv | select -skip 1) | % {
        if (!(Util_IsValidIPAddress $_)) {
            Throw "Invalid IP address: " + $_
        }
        $_
    }

    if ($name -eq "default") {
        Throw "Cannot overwrite the DHCP configuration"
    }

    if ((Util_IsValidIPAddress $name) -or ($name -notmatch "[A-Za-z_\-.\d]+")) {
        Throw "Invalid name: " + $name
    }

    if ($checkOverwrite -and $config.$name) {
        $prompt = Util_Prompt ("Another configuration with the name " + $name + " already exists, would you like to overwrite it? (y/N)")
        if (!$prompt) {
            Throw "Operation cancelled"
        }
    } elseif (!$checkOverwrite -and ($config.$name -eq $null)) {
        Throw "No server configuration with the name " + $name + " exists"
    }

    Return $name, (@() + $addresses)
}

# Prompt the user with a message
Function Util_Prompt($msg) {
    $confirm = Read-Host $msg
    Return ($confirm -match "^[Yy]")
}

###############################################
# Command Handlers                            #
###############################################

# Show the list of DNS server configurations
Function Action_Show {
    Write-Host "The following servers are configured" | Util_FormatConfig
}

# Set the DNS server addresses for the given server name
Function Action_Set {
    ($name, $addresses) = (Util_ReadServerConfigInput $true)
    Lib_SetConfiguration $name $addresses
}

# Add the DNS server address(es) to the server with the given name
Function Action_Add {
    ($name, $addresses) = Util_ReadServerConfigInput
    $newAddresses = ($config.$name + $addresses) | select -uniq
    Lib_SetConfiguration $name $newAddresses
}

# Remove the DNS server address(es) from the server with the given name
Function Action_Remove {
    ($name, $addresses) = Util_ReadServerConfigInput
    $newAddresses = @() + ($config.$name | ? {$addresses -notcontains $_})
    Lib_SetConfiguration $name $newAddresses
}

# Delete the given configuration
Function Action_Delete {
    ($name, $addresses) = (Util_ReadServerConfigInput $false $true)
    $newConfig = $config | Select-Object -Property * -ExcludeProperty $name
    Lib_WriteConfig ($newConfig | ConvertTo-Json)
    Write-Host "Deleted configuration" $name
}

# Reset to factory configuration
Function Action_FactoryReset {
    $prompt = Util_Prompt "Resetting to factory defaults will result in the loss of all your custom configurations. Are you sure you'd like continue? (y/N)"
    if ($prompt) {
        Lib_WriteDefaults
        Write-Host "Successfully reset to factory settings"
    }
}

# Use the given DNS server configuration, or the list of server addresses
Function Action_Use {
    $adapter = Lib_GetAdapter
    Write-Host "Using adapter:" $adapter.Name

    $addresses = $null

    if ($argv.Length -gt 1) {
        Write-Host "Switching to plain IP address mode"
        $addresses = $argv | % {
            if (!(Util_IsValidIPAddress $_)) {
                Throw "Invalid IP address: " + $_
            }
            $_
        }
    } else {
        $name = $argv[0]

        if (Util_IsValidIPAddress $name) {
            Write-Host "Switching to plain IP address mode"
            $addresses = @($name)
        } else {
            $serverNames = $config.psobject.properties.name

            if (!$name) {
                Write-Host "Select a configuration to use" | Util_FormatConfig
                $name = Read-Host

                if ($name -match "^[\d+$]") {
                    $idx = [int]::Parse($name) - 1
                    $name = $serverNames[$idx]
                }
            }

            if (!$name) {
                Write-Host "No server selected, exiting"
                Return
            }

            if (!$serverNames.Contains($name)) {
                Throw "Invalid server: " + $name
            }

            if ($name -eq "default") {
                Return (Lib_ResetDnsServers $adapter)
            }

            $addresses = $config.$name
        }
    }

    Lib_SetDnsServers $adapter $addresses
}

# Flush the DNS resolver cache
Function Action_FlushCache {
    Write-Host "Flushing DNS cache"
    Clear-DnsClientCache
}

# Display help
Function Action_Help {
    Write-Host ""
    Write-Host "Usage: "
    Write-Host "  dnsbro <command> [<args>]"
    Write-Host ""
    Write-Host "Commands:"
    Write-Host "  show                                  # Show the list of configurations"
    Write-Host "  use <name>                            # Use the DNS servers from a configuration"
    Write-Host "  use <addr1> [<addr2>...]              # Use the given DNS servers"
    Write-Host "  set <name> <addr1> [<addr2>...]       # Create or update a configuration to use the given addresses"
    Write-Host "  add <name> <addr1> [<addr2>...]       # Add the given server(s) to a configuration"
    Write-Host "  remove <name> <addr1> [<addr2>...]    # Remove the given addresses from a configuration"
    Write-Host "  delete <name>                         # Delete the given configuration"
    Write-Host "  factory-reset                         # Reset configurations to factory settings"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  dnsbro use google                 # Use Google's DNS servers"
    Write-Host "  dnsbro set local 192.168.1.42     # Save a config called local with the address 192.178.1.42"
    Write-Host "  dnsbro use default                # Use the default DHCP settings"
}

###############################################
# Run the Program                             #
###############################################

$config = Lib_LoadConfig

Write-Host "dnsbro v{{VERSION}} ({{BUILD_DATE}})"

switch ($action) {
    "-h" { Action_Help }
    "--help" { Action_Help }
    "help" { Action_Help }
    "show" { Action_Show }
    "use" { Action_Use }
    "add" { Action_Add }
    "set" { Action_Set }
    "delete" { Action_Delete }
    "remove" { Action_Remove }
    "flush" { Action_FlushCache }
    "factory-reset" { Action_FactoryReset }
    default { Throw "Unknown command " + $action }
}
