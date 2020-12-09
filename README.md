Packer Templates for Windows Server 2019
========================================

This repo contains Packer templates for building dockerized Windows Server 2019 virtual machines. It demonstrates a workflow that uses Ansible to provision a minimal Windows Server with Docker Engine. The virtual machine's Docker instance can be administered from the host with `docker context use windows-server-docker`. It was designed with the ability to build and test Windows Docker images from Unix-like systems in mind, but it can also be used with Hyper-V and provides a good baseline for automation on a properly configured Windows Server VM.

- [Packer Templates for Windows Server 2019](#packer-templates-for-windows-server-2019)
  - [Installation Requirements](#installation-requirements)
    - [Windows Server 2019 ISO](#windows-server-2019-iso)
    - [Parallels Pro or Business Edition](#parallels-pro-or-business-edition)
    - [VMWare Desktop](#vmware-desktop)
    - [Other Vagrant Providers](#other-vagrant-providers)
  - [Usage](#usage)
    - [Building the Vagrant VM](#building-the-vagrant-vm)
    - [Start the VM](#start-the-vm)
    - [Testing your Dockerfiles](#testing-your-dockerfiles)
  - [Concepts Demonstrated](#concepts-demonstrated)
  - [Other Resourcees](#other-resourcees)


-----

## Installation Requirements
- Ansible
- Docker
- Packer
- Vagrant >= 1.8

Using your favorite package manager, run:

```sh
# MacOS
brew install ansible docker packer vagrant

# Debian
apt-get install ansible docker packer vagrant
```

### Windows Server 2019 ISO

https://www.microsoft.com/en-us/evalcenter/evaluate-windows-server-2019

### Parallels Pro or Business Edition

Packer also requires the Parallels virtualization SDK. You can install it with Homebrew:

```sh
brew cask install parallels-virtualization-sdk
```

```sh
vagrant plugin install vagrant-parallels
```

### VMWare Desktop

```sh
vagrant plugin install vagrant-vmware-desktop
vagrant plugin license vagrant-vmware-desktop <license.lic>
```

### Other Vagrant Providers
todo

----

## Usage

### Building the Vagrant VM

```sh
git clone https://github.com/cagyirey/packer-windows-server.git && cd packer-windows-server
./build.sh ~/path/to/windows.iso --only=<provider>
vagrant box add --name server2004 ./windows_server_<provider>.box
```

`build.sh <path to iso> <extra args>` simplifies the `packer build` syntax slightly by setting the path to our Windows Server image and passing any extra arguments directly to Packer (such as your desired VM provider). This script *should* be used on MacOS, as it sets necessary environment variables for Ansible. You can also use manual `packer build` syntax can be used instead:
```sh
packer build --var "iso_url=~/path/to/windows.iso" --only=<provider> windows_server_2004.json
```

Valid values for `provider` are, as of now: `parallels-iso` and `parallels-pvm`. Support for VMWare, VirtualBox, Hyper-V and others is in progress. Now create a folder to contain your Vagrant VMs.

### Start the VM

```
# Projects are shared with the build container via the /projects folder
# Vagrant will require it in order to boot.
mkdir -p vagrant_vms/projects && cd vagrant_vms
vagrant init server2004
vagrant up
```

That's it! Your VM will start and automatically create a new docker-machine context and share it with your host (in `~/docker/`). To use your new context, run `docker context use windows-server-vagrant`. 

### Testing your Dockerfiles

You're now ready to manage the Docker instance on your VM. Try `docker run buildtools dotnet msbuild -Ver` to see the installed version of MSBuild. The `buildtools` image provided in the default configuration is a  the .NET 5.0 SDK and a patched version of MSBuild (use `dotnet msbuild`) that supports the Microsoft C++ Build Tools, making it a tiny but powerful and completely unique Nano Server-based build container.

## Concepts Demonstrated

- Deploying Visual Studio, .NET SDK and VC++ Build Tools on Windows Nano Server containers
- Generating `docker-machine` contexts and certs with PowerShell
- Configuring WinRM to use secure transport settings during unattended install
- Leveraging Vagrant provisioning to build and run containers at startup
- Much more

## Other Resourcees

- https://jfreeman.dev/blog/2019/07/09/what-i-learned-making-a-docker-container-for-building-c++-on-windows/
