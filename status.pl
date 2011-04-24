#!/usr/bin/perl

use strict;
use warnings;
use Sys::Statistics::Linux;
use Sys::Statistics::Linux::DiskUsage;
use Config::IniFiles;

sub _my_home {
    if ( exists $ENV{HOME} && defined $ENV{HOME} ) {
        return $ENV{HOME};
    }

    if ( $ENV{LOGDIR} ) {
        return $ENV{LOGDIR};
    }

    return undef;
}

sub free {
    my $lxs = Sys::Statistics::Linux->new(
        memstats  => 1,
    );

    my $stat = $lxs->get;
    my $home = _my_home();
    my $cfg  = Config::IniFiles->new(
        -file => "$home/.config/wmfs/mahewin-wmfs-statusrc"
    );

    my $format = $cfg->val('memory', 'format') || 'string';
    my $free   = 'Mem: ' . int($stat->memstats->{memfree} / 1024) . '/' . int($stat->memstats->{memused} / 1024);

    if ( $format eq 'percent' ) {
        my $free_usage = sprintf("%0.2f", int($stat->memstats->{memused} / 1024) / int($stat->memstats->{memtotal} / 1024 ) * 100);
        $free = 'Mem: ' . $free_usage . '%';
    }

    return $free;
}

sub disk_space {
    my $disk_usage = Sys::Statistics::Linux::DiskUsage->new(
        cmd => {
            # This is the default
            df   => 'df -hP 2>/dev/null',
        }
    );

    my $stat = $disk_usage->get;
    my $home = _my_home();
    my $cfg  = Config::IniFiles->new(
        -file => "$home/.config/wmfs/mahewin-wmfs-statusrc"
    );

    my $format = $cfg->val('disk', 'format') || 'string';
    my $disk   = 'Disk: ' . $stat->{'/dev/sda6'}->{usage} . '/' . $stat->{'/dev/sda6'}->{free};

    if ( $format eq 'percent' ) {
        my @usage = split(/G/, $stat->{'/dev/sda6'}->{usage});
        my @total = split(/G/, $stat->{'/dev/sda6'}->{total});
        $usage[0] =~ s/,/./;

        my $disk_usage = sprintf("%0.2f", $usage[0] / $total[0] * 100);
        $disk = 'Disk: ' . $disk_usage . '%';
    }

    return $disk;
}

sub time_date {
    my $lxs  = Sys::Statistics::Linux->new();
    my $home = _my_home();
    my $cfg  = Config::IniFiles->new(
        -file => "$home/.config/wmfs/mahewin-wmfs-statusrc"
    );
    my $format = $cfg->val('date', 'format') || '%Y/%m/%d %H:%M:%S';

    $lxs->settime($format);
    my $date_time = 'Date: ' . $lxs->gettime;

    return $date_time;
}

my $free      = free();
my $disk      = disk_space();
my $time_date = time_date();

`wmfs -s "$free $disk $time_date"`;
