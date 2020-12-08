# Packer Templates for Windows Server 2019

This repo contains Packer templates for building dockerized Windows Server 2019 virtual machine images. They are meant to demonstrate best practices with respect  to provisioning with Ansible and correctly deploying Docker through the MsftDocker package provider, as well as how to generate `docker-machine` contexts that your VM host can use to control the guest's Docker service.

Basically, I wanteded to be able to test and run Windows containers on a MacBook. If you also want to do that on non-Windows platforms, or you just want to build a custom Windows Server image, I hope you find this code useful.

## Installation Requirements
- Ansible
- Docker
- Packer
- Vagrant ~> 1.8

Using your favorite package manager, run:

```sh
# MacOS
brew install ansible docker packer vagrant

# Debian
apt-get install ansible docker packer vagrant
```

### Windows Server 2019 ISO

Download a Windows Server evaluation ISO from Microsoft.

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
`build.sh <path to iso> <extra args>` can be used to run `packer build` by passing in an ISO path from disk. This script *should* be used on MacOS, as it sets necessary environment variables for Ansible.

```sh
git clone https://github.com/cagyirey/packer-windows-server.git && cd packer-windows-server
./build.sh ~/path/to/windows.iso --only=<provider>
vagrant box add --name server2004 ./windows_server_<provider>.box
```

The manual `packer build` syntax can be used instead of `build.sh`:
```sh
packer build --var "iso_url=<path to your Windows Server ISO>" --only=<provider> windows_server_2004.json
```

Valid values for `provider` are, as of now: `parallels-iso` and `parallels-pvm`. Support for VMWare, VirtualBox, Hyper-V and others is in progress. Now create a folder to contain your Vagrant VMs.

```
# Create a /projects subfolder for sharing project files with the build container
mkdir -p vagrant_vms/projects && cd vagrant_vms
vagrant init server2004
vagrant up
```

That's it! Your VM will start and automatically create a new docker-machine context and share it with your host (in `~/docker/`). To use your new context, run `docker context use windows-server-vagrant`. You're now ready to manage the Docker instance on your VM. Try `docker run buildtools dotnet msbuild -Ver` to see the installed version of MSBuild. The `buildtools` image provided in the default configuration is a  the .NET 5.0 SDK and a patched version of MSBuild (use `dotnet msbuild`) that supports the Microsoft C++ Build Tools, making it a tiny but powerful Nano Server-based build container.

## Concepts Demonstrated

- Automatic provisioning of docker-machine contexts
- Correctly configuring WinRM to use HTTPS.
- Building and deploying Docker images on Server 2019
- Deploying Visual Studio, .NET Core SDK and VC++ Build Tools on Windows Server Nano containers
- Much more

## Other Resourcees

- https://jfreeman.dev/blog/2019/07/09/what-i-learned-making-a-docker-container-for-building-c++-on-windows/
