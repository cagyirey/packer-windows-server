param ([String] $HostHome, [String] $MachineName = "windows-machine", [String] $Hostname, [Switch] $Experimental, [Switch] $Clean)

$ErrorActionPreference = 'Stop';

function ensureDirs($dirs) {
  foreach ($dir in $dirs) {
    if (!(Test-Path $dir)) {
      mkdir $dir
    }
  }
}

function clean([String[]]$dirs) {
  foreach ($dir in $dirs) {
    if (Test-Path $dir) {
      Write-Output "===Cleaning directory [ $dir ]"
      rm -recurse $dir
    }
  }
}

function writeCertificate($Path, $Value, [Switch]$PrivateKey) {
  $base64 = [System.Convert]::ToBase64String($Value, [System.Base64FormattingOptions]::InsertLineBreaks)
  $contents = if ($PrivateKey -eq $true) {
    "-----BEGIN PRIVATE KEY-----`n$base64`n-----END PRIVATE KEY----- " 
  }
  else {
    "-----BEGIN CERTIFICATE-----`n$base64`n-----END CERTIFICATE-----" 
  }

  Set-Content -Path $Path -Value $contents -Encoding "ASCII"
}

# https://docs.docker.com/engine/security/https/
function createCerts($serverCertsPath, $clientCertsPath) {

  $caCertParams = @{
    type              = "Custom" ;
    KeyExportPolicy   = "Exportable";
    Subject           = "CN=Docker TLS Root";
    CertStoreLocation = "Cert:\CurrentUser\My";
    HashAlgorithm     = "sha256";
    KeyLength         = 4096;
    KeyUsage          = @("CertSign", "CRLSign");
    TextExtension     = @("2.5.29.19 ={critical} {text}ca=1")
  }
  $rootCert = New-SelfSignedCertificate @caCertParams

  $addresses = (Get-NetIPAddress -AddressFamily IPv4).IPAddress -Join '&IPAddress='
  $serverCertParams = @{
    CertStoreLocation = "Cert:\CurrentUser\My";
    Signer            = $rootCert;
    Subject           = "CN=serverCert";
    KeyExportPolicy   = "Exportable";
    Provider          = "Microsoft Enhanced Cryptographic Provider v1.0";
    Type              = "SSLServerAuthentication";
    HashAlgorithm     = "sha256";
    TextExtension     = @("2.5.29.37= {text}1.3.6.1.5.5.7.3.1", "2.5.29.17={text}DNS=$Hostname&DNS=localhost&IPAddress=$addresses");
    KeyLength         = 4096;
  }
  
  $clientCertParams = @{
    CertStoreLocation = "Cert:\CurrentUser\My";
    Subject           = "CN=clientCert";
    Signer            = $rootCert ;
    KeyExportPolicy   = "Exportable";
    Provider          = "Microsoft Enhanced Cryptographic Provider v1.0";
    TextExtension     = @("2.5.29.37= {text}1.3.6.1.5.5.7.3.2") ;
    HashAlgorithm     = "sha256";
    KeyLength         = 4096;
  }

  writeCertificate "$serverCertsPath\ca.pem" $rootCert.RawData

  $serverCert = New-SelfSignedCertificate @serverCertParams
  $privateKeyFromCert = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($serverCert)
  writeCertificate "$serverCertsPath\server-cert.pem" $serverCert.RawData
  writeCertificate "$serverCertsPath\server-key.pem" $privateKeyFromCert.Key.Export([System.Security.Cryptography.CngKeyBlobFormat]::Pkcs8PrivateBlob) -PrivateKey

  $clientCert = New-SelfSignedCertificate @clientCertParams
  $clientprivateKeyFromCert = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($clientCert)
  writeCertificate "$clientCertsPath\cert.pem" $clientCert.RawData
  writeCertificate "$clientCertsPath\key.pem" $clientprivateKeyFromCert.Key.Export([System.Security.Cryptography.CngKeyBlobFormat]::Pkcs8PrivateBlob) -PrivateKey
  
  #copy $serverCertsPath\ca.pem $clientCertsPath\ca.pem
}

function updateConfig($daemonJson, $serverCertsPath, $experimental) {
  $config = @{}
  if (Test-Path $daemonJson) {
    $config = (Get-Content $daemonJson) -join "`n" | ConvertFrom-Json
  }
  if (!$experimental) {
    $experimental = $false
  }
  $config = $config | Add-Member(@{ `
        hosts        = @("tcp://0.0.0.0:2376", "npipe://"); `
        tlsverify    = $true; `
        tlscacert    = "$serverCertsPath\ca.pem"; `
        tlscert      = "$serverCertsPath\server-cert.pem"; `
        tlskey       = "$serverCertsPath\server-key.pem"; `
        experimental = $experimental `
    
    }) -Force -PassThru

  Write-Host "`n=== Creating / Updating $daemonJson"
  $config | ConvertTo-Json | Set-Content $daemonJson -Encoding Ascii
}

function createContext ($machineName, $contextSha, $machineAddress, $serverCertsPath, $clientCertsPath) {
  $contextMetaPath = "$env:USERPROFILE\.docker\contexts\meta\$contextSha"
  $contextCertPath = "$env:USERPROFILE\.docker\contexts\tls\$contextSha\docker"
  $contextMetaJson = "$contextMetaPath\meta.json"
  
  ensureDirs @($contextMetaPath, $contextCertPath)
  $config = @"
{
  "Name": "$machineName",
  "Metadata": {
    "Description": "$machineName windows-docker-machine"
  },
  "Endpoints": {
    "docker": {
      "Host": "tcp://${machineAddress}:2376",
      "SkipTLSVerify": false
    }
  }
}
"@

  Write-Host "`n=== Creating / Updating $contextMetaJson"
  $config | Set-Content $contextMetaJson -Encoding Ascii

  Write-Host "`n=== Copying Client certificates to $contextCertPath"
  Copy-Item $serverCertsPath\ca.pem $contextCertPath\ca.pem
  Copy-Item $clientCertsPath\cert.pem $contextCertPath\cert.pem
  Copy-Item $clientCertsPath\key.pem $contextCertPath\key.pem
}

function createMachineConfig ($machineName, $HostHome, $machinePath, $machineAddress, $serverCertsPath, $clientCertsPath) {
  $machineConfigJson = "$machinePath\config.json"

  $machineConfig = @"
{
    "ConfigVersion": 3,
    "Driver": {
        "IPAddress": "$machineAddress",
        "MachineName": "$machineName",
        "SSHUser": "none",
        "SSHPort": 3389,
        "SSHKeyPath": "",
        "StorePath": "$HostHome/.docker/machine",
        "SwarmMaster": false,
        "SwarmHost": "",
        "SwarmDiscovery": "",
        "EnginePort": 2376,
        "SSHKey": ""
    },
    "DriverName": "generic",
    "HostOptions": {
        "Driver": "",
        "Memory": 0,
        "Disk": 0,
        "EngineOptions": {
            "ArbitraryFlags": [],
            "Dns": null,
            "GraphDir": "",
            "Env": [],
            "Ipv6": false,
            "InsecureRegistry": [],
            "Labels": [],
            "LogLevel": "",
            "StorageDriver": "",
            "SelinuxEnabled": false,
            "TlsVerify": true,
            "RegistryMirror": [],
            "InstallURL": "https://get.docker.com"
        },
        "SwarmOptions": {
            "IsSwarm": false,
            "Address": "",
            "Discovery": "",
            "Agent": false,
            "Master": false,
            "Host": "tcp://0.0.0.0:3376",
            "Image": "swarm:latest",
            "Strategy": "spread",
            "Heartbeat": 0,
            "Overcommit": 0,
            "ArbitraryFlags": [],
            "ArbitraryJoinFlags": [],
            "Env": null,
            "IsExperimental": false
        },
        "AuthOptions": {
            "CertDir": "$HostHome/.docker/machine/machines/$machineName",
            "CaCertPath": "$HostHome/.docker/machine/machines/$machineName/ca.pem",
            "CaPrivateKeyPath": "$HostHome/.docker/machine/machines/$machineName/ca-key.pem",
            "ServerCertPath": "$HostHome/.docker/machine/machines/$machineName/server.pem",
            "ServerKeyPath": "$HostHome/.docker/machine/machines/$machineName/server-key.pem",
            "ClientCertPath": "$HostHome/.docker/machine/machines/$machineName/cert.pem",
            "ClientKeyPath": "$HostHome/.docker/machine/machines/$machineName/key.pem",
            "ServerCertRemotePath": "",
            "ServerKeyRemotePath": "",
            "CaCertRemotePath": "",
            "ServerCertSANs": [],
            "StorePath": "$HostHome/.docker/machine/machines/$machineName"
        }
    },
    "Name": "$machineName"
}
"@

  Write-Host "`n=== Creating / Updating $machineConfigJson"
  $machineConfig | Set-Content $machineConfigJson -Encoding Ascii

  Write-Host "`n=== Copying Client certificates to $machinePath"
  Copy-Item $serverCertsPath\ca.pem $machinePath\ca.pem
  Copy-Item $clientCertsPath\cert.pem $machinePath\cert.pem
  Copy-Item $clientCertsPath\key.pem $machinePath\key.pem
}

function configureDockerFirewallRules($port = 2376) {
  Get-NetFirewallPortFilter | ? { $_.Protocol -eq "TCP" -and $_.LocalPort -eq $port } | Get-NetFirewallRule | Remove-NetFirewallRule
  Write-Host "Opening Docker TLS port"
  New-NetFirewallRule -DisplayName 'Docker TLS' -Name 'Docker TLS' -Profile Any -LocalPort 2376 -Protocol TCP
}

$contextSha = ((new-object System.Security.Cryptography.SHA256Managed).ComputeHash([System.Text.Encoding]::UTF8.GetBytes($machineName)) | ForEach-Object ToString X2) -join ''

$homeDir = If ($HostHome.StartsWith('/')) { "C:$HostHome" } Else { $HostHome }

if ($Clean -eq $false) {
  $dockerConfig = "$env:ProgramData\docker\config"
  $serverCertsPath = "$env:ProgramData\docker\certs.d"
  $clientCertsPath = "$env:USERPROFILE\.docker"
  $machinePath = "$env:USERPROFILE\.docker\machine\machines\$machineName"

  # Create TLS certificates
  ensureDirs @($serverCertsPath, $clientCertsPath, $dockerConfig, $machinePath)
  createCerts $serverCertsPath $clientCertsPath

  # Update Docker client config
  updateConfig "$dockerConfig\daemon.json" $serverCertsPath $experimental

  # Create a Docker Machine configuration
  createMachineConfig $machineName $hostHome $machinePath $Hostname $serverCertsPath $clientCertsPath
  clean @("$homeDir\.docker\machine\machines\$machineName")
  Copy-Item -Recurse $machinePath "$homeDir\.docker\machine\machines\$machineName"

  # Create a Docker context
  createContext $machineName $contextSha $Hostname $serverCertsPath $clientCertsPath
  clean @("$homeDir\.docker\contexts\meta\$contextSha", "$homeDir\.docker\contexts\tls\$contextSha")
  Copy-Item -Recurse "$env:USERPROFILE\.docker\contexts\meta\$contextSha" "$homeDir\.docker\contexts\meta\$contextSha"
  Copy-Item -Recurse "$env:USERPROFILE\.docker\contexts\tls\$contextSha" "$homeDir\.docker\contexts\tls\$contextSha"

  # Restart the Docker service
  Write-Host "Restarting Docker"
  Restart-Service Docker

  configureDockerFirewallRules
  
} else {
  clean @("$homeDir\.docker\machine\machines\$machineName", "$homeDir\.docker\contexts\meta\$contextSha", "$homeDir\.docker\contexts\tls\$contextSha")
}