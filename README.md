# dnsbro (WIP)
DNSbro is a command line utility that lets you change your DNS server addresses easily. It currently supports Windows but Linux and OSX versions are to come.

![dnsbro](http://i.imgur.com/ac1iLgg.png)

The following servers ship with the app:

- Google: `8.8.8.8`, `8.8.4.4`
- Level3: `4.2.2.3`, `4.2.2.5`
- OpenDNS: `208.67.222.222`, `208.67.220.220`
- Comodo Secure DNS: `8.26.56.26`, `8.20.247.20`

## Installation

### Building from Source

#### Windows
Launch up a PowerShell session, navigate into the `build` directory and run the following command:

```
./win.ps1
```

The output files will be written under `build/bin`.

By default, the build script uses the string found in [the VERSION file](VERSION) but you can specify `-version <some string>` to use a different version number.

Example:
```
./win.ps1 -version 0.0.2-foo
```

Pre-built releases coming soon.

## Usage
```
Usage:
  dnsbro <command> [<args>]

Commands:
  show                                  # Show the list of configurations
  use <name>                            # Use the DNS servers from a configuration
  use <addr1> [<addr2>...]              # Use the given DNS servers
  set <name> <addr1> [<addr2>...]       # Create or update a configuration to use the given addresses
  add <name> <addr1> [<addr2>...]       # Add the given server(s) to a configuration
  remove <name> <addr1> [<addr2>...]    # Remove the given addresses from a configuration
  delete <name>                         # Delete the given configuration
  factory-reset                         # Reset configurations to factory settings

Examples:
  dnsbro use google                 # Use Google's DNS servers
  dnsbro set local 192.168.1.42     # Save a config called local with the address 192.178.1.42
  dnsbro use default                # Use the default DHCP settings
```

## To Do
- Build executables rather than a script
- Add Linux and OSX support 
- Add version detection and configuration upgrades
- Add proper usage info
- Add proper screenshot
