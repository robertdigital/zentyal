# Copyright (C) 2013 Zentyal S.L.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2, as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA

use strict;
use warnings;

package EBox::Samba::SmbClient;

use Filesys::SmbClient;
use EBox;
use EBox::Gettext;
use EBox::Exceptions::Internal;
use EBox::Samba::AuthKrbHelper;

use base 'Filesys::SmbClient';

sub new
{
    my ($class, %params) = @_;

    my $krbHelper = new EBox::Samba::AuthKrbHelper(%params);
    my $flags = $class->SUPER::SMB_CTX_FLAG_USE_KERBEROS;
    my $self = $class->SUPER::new(username => $krbHelper->principal(),
                                  flags => $flags);
    $self->{krbHelper} = $krbHelper;
    bless ($self, $class);
    return $self;
}

sub smb_copy
{
    my ($self, $srcURL, $dstURL) = @_;

    my @srcStat = $self->stat($srcURL);
    unless (scalar @srcStat) {
        throw EBox::Exceptions::Internal("Can not stat $srcURL");
    }

    my $srcSize = $srcStat[7];
    my $pendingBytes = $srcSize;
    my $writtenBytes = 0;

    my $dstFD = $self->open(">$dstURL");
    if ($dstFD == 0) {
        throw EBox::Exceptions::Internal("Can not open $dstURL: $!");
    }
    my $srcFD = $self->open("<$srcURL");
    if ($srcFD == 0) {
        throw EBox::Exceptions::Internal("Can not open $srcURL: $!");
    }

    my $buffer = undef;
    my $chunkSize = 4096;
    while ($pendingBytes > 0) {
        $chunkSize = ($pendingBytes < $chunkSize) ? $pendingBytes : $chunkSize;
        my $buffer = $self->read($srcFD, $chunkSize);
        unless (defined $buffer) {
            throw EBox::Exceptions::Internal("Can not read $srcURL: EOF");
        }
        if ($buffer eq '-1') {
            throw EBox::Exceptions::Internal("Can not read $srcURL: $!");
        }
        $pendingBytes -= $chunkSize;

        my $wrote = $self->write($dstFD, $buffer);
        if ($wrote == -1) {
            throw EBox::Exceptions::Internal("Can not write $dstURL: $!");
        }
        $writtenBytes += $wrote;
    }
    $self->close($dstFD);
    $self->close($srcFD);

    unless ($writtenBytes == $srcSize and $pendingBytes == 0) {
        throw EBox::Exceptions::Internal(
                "Error copying $srcURL to $dstURL. Sizes does not match");
    }
    return 1;
}

1;
