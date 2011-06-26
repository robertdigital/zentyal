# Copyright (C) 2011 eBox Technologies S.L.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2, as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

package EBox::Virt::VBox;

use base 'EBox::Virt::AbstractBackend';

use strict;
use warnings;

use EBox::Exceptions::MissingArgument;

my $VBOXCMD = 'vboxmanage -nologo';
my $IDE_CTL = 'idectl';
my $SATA_CTL = 'satactl';
my $ROOT_PATH = '/var/lib/zentyal/.VirtualBox';
my $VM_PATH = "$ROOT_PATH/Machines";
my $HD_PATH = "$ROOT_PATH/HardDisks";

# Class: EBox::Virt::VBox
#
#   Backend implementation for VirtualBox
#

sub new
{
    my $class = shift;
    my $self = {};
    bless ($self, $class);
    return $self;
}

# Method: createDisk
#
#   Creates a VDI file.
#
# Parameters:
#
#   disk    - name of the disk image
#   size    - size of the disk in megabytes
#
sub createDisk
{
    my ($self, %params) = @_;

    exists $params{disk} or
        throw EBox::Exceptions::MissingArgument('disk');
    exists $params{size} or
        throw EBox::Exceptions::MissingArgument('size');

    my $disk = $params{disk};
    my $size = $params{size};

    _run("$VBOXCMD createhd --filename $disk --size $size");
}

# Method: resizeDisk
#
#   Resizes a VDI file.
#
# Parameters:
#
#   file    - filename of the disk image
#   size    - size of the disk in megabytes
#
sub resizeDisk
{
    my ($self, %params) = @_;

    exists $params{file} or
        throw EBox::Exceptions::MissingArgument('file');
    exists $params{size} or
        throw EBox::Exceptions::MissingArgument('size');

    my $file = $params{file};
    my $size = $params{size};

    _run("$VBOXCMD modifyhd $file --resize $size");
}

# Method: vmExists
#
#   Checks if a VM with the given name already exists
#
# Parameters:
#
#   name    - virtual machine name
#
# Returns:
#
#   boolean - true if exists, false if not
#
sub vmExists
{
    my ($self, $name) = @_;

    $self->_vmCheck($name, 'vms');
}

# Method: vmRunning
#
#   Checks if a VM with the given name is running
#
# Parameters:
#
#   name    - virtual machine name
#
# Returns:
#
#   boolean - true if running, false if not
#
sub vmRunning
{
    my ($self, $name) = @_;

    $self->_vmCheck($name, 'runningvms');
}

# FIXME: doc
sub listVMs
{
    my $list =  `$VBOXCMD list vms | cut -d'"' -f2`;
    my @vms = split ("\n", $list);
    return \@vms;
}

sub _vmCheck
{
    my ($self, $name, $list) = @_;

    _run("$VBOXCMD list $list | grep -q '\"$name\"'");
    return ($? == 0);
}

# Method: createVM
#
#   Creates a new virtual machine
#
# Parameters:
#
#   name    - virtual machine name
#   os      - operating system identifier
#
sub createVM
{
    my ($self, %params) = @_;

    exists $params{name} or
        throw EBox::Exceptions::MissingArgument('name');
    exists $params{os} or
        throw EBox::Exceptions::MissingArgument('os');

    my $name = $params{name};
    my $os = $params{os};

    return if $self->vmExists($name);

    # TODO: --settingsfile <path> ?
    _run("$VBOXCMD createvm --name $name --ostype $os --register");

    # Add IDE and SATA controllers
    _run("$VBOXCMD storagectl $name --name $IDE_CTL --add ide");
    _run("$VBOXCMD storagectl $name --name $SATA_CTL --add sata");
}

# Method: startVMCommand
#
#   Command to start a VM with a VNC server on the specified port.
#
# Parameters:
#
#   name    - virtual machine name
#   port    - VNC port
#
# Returns:
#
#   string with the command
#
sub startVMCommand
{
    my ($self, %params) = @_;

    exists $params{name} or
        throw EBox::Exceptions::MissingArgument('name');
    exists $params{port} or
        throw EBox::Exceptions::MissingArgument('port');

    my $name = $params{name};
    my $port = $params{port};

    return ("vboxheadless --vnc --vncport $port --startvm $name");
}

# Method: shutdownVM
#
#   Shuts down a virtual machine.
#
# Parameters:
#
#   name    - virtual machine name
#
sub shutdownVM
{
    my ($self, $name) = @_;

    $self->_controlVM($name, 'poweroff');
}

# Method: shutdownVMCommand
#
#   Command to shut down a virtual machine.
#
# Parameters:
#
#   name    - virtual machine name
#
# Returns:
#
#   string with the command
#
sub shutdownVMCommand
{
    my ($self, $name) = @_;

    return $self->_controlVMCommand($name, 'poweroff');
}

# Method: pauseVM
#
#   Pauses a virtual machine.
#
# Parameters:
#
#   name    - virtual machine name
#
sub pauseVM
{
    my ($self, $name) = @_;

    $self->_controlVM($name, 'pause');
}

# Method: resumeVM
#
#   Shuts down a virtual machine.
#
# Parameters:
#
#   name    - virtual machine name
#
sub resumeVM
{
    my ($self, $name) = @_;

    $self->_controlVM($name, 'resume');
}

sub _controlVMCommand
{
    my ($self, $name, $command) = @_;

    return ("$VBOXCMD controlvm $name $command");
}

sub _controlVM
{
    my ($self, $name, $command) = @_;

    _run($self->_controlVMCommand($name, $command));
}

# Method: deleteVM
#
#   Deletes a virtual machine.
#
# Parameters:
#
#   name    - virtual machine name
#
sub deleteVM
{
    my ($self, $name) = @_;

    _run("$VBOXCMD unregistervm $name --delete");
}

# Method: setMemory
#
#   Set memory amount for the given VM.
#
# Parameters:
#
#   name    - virtual machine name
#   size    - memory size (in megabytes)
#
sub setMemory
{
    my ($self, $name, $size) = @_;

    $self->_modifyVM($name, 'memory', $size);
}

# Method: setOS
#
#   Set the OS type for the given VM.
#
# Parameters:
#
#   name    - virtual machine name
#   os      - operating system identifier
#
sub setOS
{
    my ($self, $name, $os) = @_;

    $self->_modifyVM($name, 'ostype', $os);
}

# Method: setIface
#
#   Set a network interface for the given VM.
#
# Parameters:
#
#   name    - virtual machine name
#   iface   - iface number
#   type    - iface type (none, nat, bridged, internal)
#   arg     - iface arg (bridged => devicename, internal => networkname)
#
sub setIface
{
    my ($self, %params) = @_;

    exists $params{name} or
        throw EBox::Exceptions::MissingArgument('name');
    exists $params{iface} or
        throw EBox::Exceptions::MissingArgument('iface');
    exists $params{type} or
        throw EBox::Exceptions::MissingArgument('type');

    my $name = $params{name};
    my $iface = $params{iface};
    my $type = $params{type};
    my $arg = '';
    if (($type eq 'bridged') or ($type eq 'internal')) {
        exists $params{arg} or
            throw EBox::Exceptions::MissingArgument('arg');
        $arg = $params{arg};
    }

    if ($type eq 'internal') {
        $type = 'intnet';
    }

    $self->_modifyVM($name, "nic$iface", $type);

    if ($type eq 'none') {
        return;
    } elsif ($type eq 'nat') {
        $type = 'natnet';
        $arg = 'default';
    } elsif ($type eq 'bridged') {
        $type = 'bridgeadapter';
    }

    unless ($type eq 'none') {
        my $setting = $type . $iface;
        $self->_modifyVM($name, $setting, $arg);
    }
}

sub _modifyVM
{
    my ($self, $name, $setting, $value) = @_;

    _run("$VBOXCMD modifyvm $name --$setting $value");
}

sub initDeviceNumbers
{
    my ($self) = @_;

    $self->{sataDeviceNumber} = 0;
    $self->{ideDeviceNumber} = 0;
}

# Method: attachDevice
#
#   Attach a device to a VM.
#
# Parameters:
#
#   name   - virtual machine name
#   type   - hd | cd | none
#   file   - path of the ISO or VDI file
#
sub attachDevice
{
    my ($self, %params) = @_;

    exists $params{name} or
        throw EBox::Exceptions::MissingArgument('name');
    exists $params{type} or
        throw EBox::Exceptions::MissingArgument('type');
    exists $params{file} or
        throw EBox::Exceptions::MissingArgument('file');

    my $name = $params{name};
    my $type = $params{type};
    my $file = $params{file};

    my ($port, $device, $ctl);
    if ($type eq 'hd') {
        $type = 'hdd';
        $ctl = $SATA_CTL;
        $port = $self->{sataDeviceNumber}++;
        $device = 0;
    } elsif ($type eq 'cd') {
        $type = 'dvddrive';
        $ctl = $IDE_CTL;
        $port = int ($self->{ideDeviceNumber} / 2);
        $device = $self->{ideDeviceNumber} % 2;
        $self->{ideDeviceNumber}++;
    }

    _run("$VBOXCMD storageattach $name --storagectl $ctl --port $port --device $device --type $type --medium $file");
}

sub systemTypes
{
    my $output = `$VBOXCMD list ostypes`;
    my @lines = split ("\n", $output);

    my @values;
    for (my $i = 0; $i < @lines; $i++) {
        my $line = $lines[$i];
        my ($id) = $line =~ /^ID:\s+(.*)/;
        if ($id) {
            $line = $lines[++$i];
            my ($desc) = $line =~ /^Description:\s+(.*)/;
            if ($desc) {
                push (@values, { value => $id, printableValue => $desc });
                $i++; # Skip blank line
            }
        }
    }
    return \@values;
}

# FIXME
sub listHDs
{
    my $list =  `$VBOXCMD list hdds | grep ^Location | cut -c14-`;
    my @hds = split ("\n", $list);
    return \@hds;
}

sub diskFile
{
    my ($self, $disk) = @_;

    return "$HD_PATH/$disk.vdi";
}

# Method: attachedDevices
#
#   Returns the number of attached devices for a VM.
#
# Parameters:
#
#   name    - virtual machine name
#   type    - type of devices (values: hd | cd)
#
sub attachedDevices
{
    my ($self, $name, $type) = @_;

    my $machineFile = "$VM_PATH/$name/$name.xml";
    if ($type eq 'cd') {
        $type = 'DVD';
    } else {
        $type = 'HardDisk';
    }
    # FIXME: use read_file + perl regex?
    my @devices = `grep '<AttachedDevice' $machineFile | grep 'type=\"$type\"'`;
    return scalar (@devices);
}

sub _run
{
    my ($cmd) = @_;

    EBox::debug("Running: $cmd");
    system ($cmd);
}

1;
