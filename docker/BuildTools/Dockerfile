# escape=`
ARG DOTNET_SDK_VERSION=5.0.100
ARG VCTOOLS_VERSION=14.28.29333

FROM mcr.microsoft.com/windows/servercore:2004-KB4586781-amd64 as installer

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]
ARG CHANNEL_URL=https://aka.ms/vs/16/release/channel
ARG DOTNET_SDK_VERSION

COPY Install.cmd C:\TEMP\

ADD https://aka.ms/vscollect.exe C:\TEMP\collect.exe
ADD ${CHANNEL_URL} C:\TEMP\VisualStudio.chman
ADD https://aka.ms/vs/16/release/vs_buildtools.exe C:\TEMP\vs_buildtools.exe
RUN C:\TEMP\Install.cmd C:\TEMP\vs_buildtools.exe --quiet --wait --norestart --nocache `
    --installPath C:\BuildTools `
    --channelUri C:\TEMP\VisualStudio.chman `
    --installChannelUri C:\TEMP\VisualStudio.chman `
    --add Microsoft.VisualStudio.Workload.VCTools `
    --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
    --add Microsoft.VisualStudio.Component.Windows10SDK.18362

# Install the .NET SDK 
RUN `
    Invoke-WebRequest -OutFile dotnet.zip https://dotnetcli.azureedge.net/dotnet/Sdk/$Env:DOTNET_SDK_VERSION/dotnet-sdk-$Env:DOTNET_SDK_VERSION-win-x64.zip; `
    $dotnet_sha512 = '6836916bc6f3f9f7c183eb49fa1f6130640bcf623f310785466cb36c98f0554d656ec69ce3524f22d1e0d21528796182c7b4f0ed7c66e37cbc0ecbcd9f59bcd5'; `
    if ((Get-FileHash dotnet.zip -Algorithm sha512).Hash -ne $dotnet_sha512) { `
        Write-Host 'CHECKSUM VERIFICATION FAILED!'; `
        exit 1; `
    }; `
    mkdir dotnet; `
    tar -C dotnet -oxzf dotnet.zip; `
    Remove-Item -Force dotnet.zip;

# Copy the file tracker from Visual Studio
RUN `
    ls -Include *Tracker* "C:/BuildTools/MSBuild/Current/Bin/amd64/*" `
    | cp -Destination "/dotnet/sdk/$env:DOTNET_SDK_VERSION/"; `
    cp -recurse C:/BuildTools/MSBuild/Current/Bin/amd64/1033 "/dotnet/sdk/$env:DOTNET_SDK_VERSION/";

# Install git
RUN `
    iwr -OutFile mingit.zip https://github.com/git-for-windows/git/releases/download/v2.29.2.windows.2/MinGit-2.29.2.2-64-bit.zip; `
    mkdir git; `
    tar -C git -oxzf mingit.zip; `
    rm -force mingit.zip;

# Clone and build the patched msbuild repo
RUN `
    C:/git/cmd/git.exe clone https://github.com/cagyirey/msbuild.git -b feature-managed-getknownfolder; `
    C:/dotnet/dotnet.exe build -c Release -f netstandard2.0 /p:DefineConstants=FEATURE_FILE_TRACKER C:/msbuild/src/Utilities/Microsoft.Build.Utilities.csproj; 

# Copy the fixed framework and 
# TODO: it's not clear if copying the Build.Framework assembly is necessary
RUN `
    cp "/msbuild/artifacts/bin/Microsoft.Build.Utilities/Release/netstandard2.0/*.dll" "/dotnet/sdk/$env:DOTNET_SDK_VERSION/" -force;


FROM mcr.microsoft.com/windows/nanoserver:2004-KB4586781-amd64 as runtime 
ARG DOTNET_SDK_VERSION
ARG VCTOOLS_VERSION

COPY --from=installer ["/BuildTools", "/BuildTools"]
COPY --from=installer ["/Program Files (x86)/Windows Kits/", "/Program Files (x86)/Windows Kits/"]
COPY --from=installer ["/dotnet", "/Program Files/dotnet"]

COPY ["MSBuild.rsp", "/Program Files/dotnet/sdk/${DOTNET_SDK_VERSION}/"]
COPY ["MSBuild.NetCore.Environment.Cpp.props", "/BuildTools/MSBuild/Current/"]

ENV `
    # Unset ASPNETCORE_URLS from aspnet base image
    ASPNETCORE_URLS= `
    DOTNET_SDK_VERSION=$DOTNET_SDK_VERSION `
    # Enable correct mode for dotnet watch (only mode supported in a container)
    DOTNET_USE_POLLING_FILE_WATCHER=true `
    # Skip extraction of XML docs - generally not useful within an image/container - helps performance
    NUGET_XMLDOC_MODE=skip `
    DOTNET_CLI_TELEMETRY_OPTOUT=yes `
    INCLUDE="C:/BuildTools/VC/Tools/MSVC/${VCTOOLS_VERSION}/Include/Manifest;${INCLUDE}" `
    VCTARGETSPATH="C:/BuildTools/MSBuild/Microsoft/VC/v160/"

USER ContainerAdministrator

RUN setx /M PATH "%PATH%;C:\Program Files\dotnet"
RUN reg add "HKLM\SOFTWARE\Microsoft\Microsoft SDKs\Windows\v10.0" /v "InstallationFolder" /d "C:/Program Files (x86)/Windows Kits/10/"
RUN reg add "HKLM\SOFTWARE\Microsoft\Windows Kits\Installed Roots" /v "KitsRoot10" /d "C:/Program Files (x86)/Windows Kits/10/"

USER ContainerUser
ENTRYPOINT ["C:\\BuildTools\\VC\\Auxiliary\\Build\\vcvarsall.bat", "x64", "&&"]